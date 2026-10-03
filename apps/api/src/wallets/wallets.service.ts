import {
  Injectable,
  NotFoundException,
  BadRequestException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { SandboxWalletProvider } from './adapters/sandbox-wallet.provider';
import { CryptoAsset, BlockchainNetwork, DepositStatus, FiatCurrency } from '@prisma/client';
import { WebhookDepositPayload } from './interfaces/wallet-provider.interface';
import * as QRCode from 'qrcode';

@Injectable()
export class WalletsService {
  private readonly logger = new Logger(WalletsService.name);

  constructor(
    private prisma: PrismaService,
    private ledgerService: LedgerService,
    private walletProvider: SandboxWalletProvider,
  ) {}

  /**
   * Retrieves all assigned deposit wallets for a user, complete with QR code data URLs.
   */
  async getUserWallets(userId: string) {
    const wallets = await this.prisma.wallet.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    return await Promise.all(
      wallets.map(async (w) => ({
        ...w,
        qrCodeDataUrl: await QRCode.toDataURL(w.address),
      })),
    );
  }

  /**
   * Assigns or retrieves a dedicated personal deposit address for a specific crypto asset & network.
   */
  async getOrCreateUserWallet(
    userId: string,
    asset: CryptoAsset,
    network: BlockchainNetwork,
  ) {
    let wallet = await this.prisma.wallet.findUnique({
      where: {
        userId_asset_network: {
          userId,
          asset,
          network,
        },
      },
    });

    if (!wallet) {
      const generated = await this.walletProvider.createAddress(userId, asset, network);

      wallet = await this.prisma.wallet.create({
        data: {
          userId,
          asset,
          network,
          address: generated.address,
          providerRef: generated.providerRef,
        },
      });

      await this.prisma.auditLog.create({
        data: {
          actorType: 'USER',
          actorId: userId,
          action: 'WALLET_CREATED',
          entityType: 'USER',
          entityId: wallet.id,
          newState: { asset, network, address: wallet.address },
        },
      });
    }

    const qrCodeDataUrl = await QRCode.toDataURL(wallet.address);

    return {
      ...wallet,
      qrCodeDataUrl,
    };
  }

  /**
   * Core Webhook Handler: Detects deposits, locks rate, tracks confirmations, and credits double-entry ledger upon finality.
   */
  async handleDepositWebhook(
    payload: WebhookDepositPayload,
    headers: Record<string, any> = {},
    rawPayload = '',
  ) {
    const cleanTxHash = payload.txHash.trim();
    const amountMinor = BigInt(payload.amountMinor);

    // 1. Verify Signature (if in production or test headers supplied)
    const isSignatureValid = this.walletProvider.verifyWebhookSignature(headers, rawPayload || JSON.stringify(payload));
    if (!isSignatureValid && headers['x-webhook-signature']) {
      throw new UnauthorizedException('Invalid deposit webhook signature');
    }

    // 2. Log Webhook for Idempotent Audit
    const webhookIdempotencyKey = `WH-DEP-${cleanTxHash}-${payload.confirmations}`;
    await this.prisma.webhookLog.upsert({
      where: { idempotencyKey: webhookIdempotencyKey },
      update: {},
      create: {
        provider: 'SANDBOX_WALLET',
        eventType: 'DEPOSIT_STATUS_UPDATE',
        idempotencyKey: webhookIdempotencyKey,
        signature: headers['x-webhook-signature'] || 'sandbox_test_sig',
        payload: payload as any,
        isProcessed: true,
        processedAt: new Date(),
      },
    });

    // 3. Find Target Wallet
    const wallet = await this.prisma.wallet.findUnique({
      where: { address: payload.address },
      include: { user: true },
    });

    if (!wallet) {
      this.logger.warn(`Deposit received for unrecognized wallet address [${payload.address}]. TxHash: ${cleanTxHash}`);
      throw new NotFoundException(`Wallet with address [${payload.address}] not found in system`);
    }

    // 4. Find or Create Deposit Record
    let deposit = await this.prisma.deposit.findUnique({
      where: { txHash: cleanTxHash },
    });

    const requiredConfirmations = 3;

    if (!deposit) {
      // First detection: fetch live spot rate and lock it for 15 minutes
      const latestRate = await this.prisma.rate.findFirst({
        where: {
          asset: payload.asset,
          fiat: FiatCurrency.NGN,
        },
        orderBy: { createdAt: 'desc' },
      });

      const effectiveRate = latestRate ? Number(latestRate.effectiveRate) : 1521.825;
      const lockedRateExpiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins lock

      deposit = await this.prisma.deposit.create({
        data: {
          txHash: cleanTxHash,
          walletId: wallet.id,
          userId: wallet.userId,
          asset: payload.asset,
          network: payload.network,
          amountMinor,
          confirmations: payload.confirmations,
          requiredConfirmations,
          status: payload.confirmations >= requiredConfirmations ? DepositStatus.CONFIRMED : DepositStatus.DETECTED,
          lockedRate: effectiveRate,
          lockedRateExpiresAt,
          detectedAt: new Date(),
          confirmedAt: payload.confirmations >= requiredConfirmations ? new Date() : null,
        },
      });

      // Audit Log for rate lock and detection
      await this.prisma.auditLog.create({
        data: {
          actorType: 'SYSTEM',
          action: 'DEPOSIT_DETECTED',
          entityType: 'DEPOSIT',
          entityId: deposit.id,
          newState: {
            txHash: cleanTxHash,
            asset: payload.asset,
            amountMinor: amountMinor.toString(),
            lockedRate: effectiveRate,
            confirmations: payload.confirmations,
          },
        },
      });
    } else {
      // Update confirmations
      const isNewlyConfirmed =
        payload.confirmations >= requiredConfirmations &&
        deposit.status !== DepositStatus.CONFIRMED &&
        deposit.status !== DepositStatus.PROCESSED;

      deposit = await this.prisma.deposit.update({
        where: { id: deposit.id },
        data: {
          confirmations: payload.confirmations,
          status: isNewlyConfirmed
            ? DepositStatus.CONFIRMED
            : deposit.status,
          confirmedAt: isNewlyConfirmed ? new Date() : deposit.confirmedAt,
        },
      });
    }

    // 5. If Confirmed and not yet processed in Ledger: Post Double-Entry Journal Credit!
    if (deposit.status === DepositStatus.CONFIRMED) {
      // Calculate NGN minor units (Kobo)
      // For USDT: 1 USDT = 1,000,000 micro-units. 1 NGN = 100 kobo.
      // Kobo = (microUnits * lockedRate * 100) / 1,000,000 = (microUnits * lockedRate) / 10,000
      let koboMinor: bigint;
      const rateNum = Number(deposit.lockedRate);

      if (deposit.asset === CryptoAsset.USDT || deposit.asset === CryptoAsset.USDC) {
        koboMinor = BigInt(Math.floor((Number(deposit.amountMinor) * rateNum) / 10000));
      } else {
        // BTC: 1 BTC = 100,000,000 satoshis.
        // Kobo = (satoshis * rateNum * 100) / 100,000,000 = (satoshis * rateNum) / 1,000,000
        koboMinor = BigInt(Math.floor((Number(deposit.amountMinor) * rateNum) / 1000000));
      }

      const ledgerRef = `DEP-SETTLE-${deposit.txHash}`;
      await this.ledgerService.credit(
        deposit.userId,
        koboMinor,
        'NGN',
        ledgerRef,
        `Off-ramp deposit settlement for ${deposit.asset} (${cleanTxHash.slice(0, 10)}...)`,
      );

      // Mark deposit as PROCESSED
      deposit = await this.prisma.deposit.update({
        where: { id: deposit.id },
        data: { status: DepositStatus.PROCESSED },
      });

      await this.prisma.auditLog.create({
        data: {
          actorType: 'SYSTEM',
          action: 'DEPOSIT_CONFIRMED',
          entityType: 'DEPOSIT',
          entityId: deposit.id,
          newState: {
            txHash: cleanTxHash,
            koboCredited: koboMinor.toString(),
            status: DepositStatus.PROCESSED,
          },
        },
      });
    }

    return deposit;
  }

  /**
   * Retrieves deposit history for a user.
   */
  async getUserDeposits(userId: string) {
    return await this.prisma.deposit.findMany({
      where: { userId },
      include: {
        wallet: { select: { address: true, network: true } },
      },
      orderBy: { detectedAt: 'desc' },
    });
  }

  /**
   * Retrieves single deposit status by transaction hash.
   */
  async getDepositByTxHash(txHash: string) {
    const deposit = await this.prisma.deposit.findUnique({
      where: { txHash },
      include: {
        wallet: true,
        user: { select: { id: true, email: true, phoneNumber: true } },
      },
    });

    if (!deposit) {
      throw new NotFoundException(`Deposit transaction [${txHash}] not found`);
    }

    return deposit;
  }
}
