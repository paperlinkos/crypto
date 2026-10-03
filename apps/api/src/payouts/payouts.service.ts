import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { KycService } from '../kyc/kyc.service';
import { PinService } from '../auth/pin.service';
import { SandboxPayoutProvider } from './adapters/sandbox-payout.provider';
import {
  AddBankAccountDto,
  InitiateWithdrawalDto,
  PayoutWebhookDto,
} from './dto/payouts.dto';
import { FiatCurrency, PayoutStatus } from '@prisma/client';

@Injectable()
export class PayoutsService {
  private readonly logger = new Logger(PayoutsService.name);

  constructor(
    private prisma: PrismaService,
    private ledgerService: LedgerService,
    private kycService: KycService,
    private pinService: PinService,
    private payoutProvider: SandboxPayoutProvider,
  ) {}

  /**
   * Retrieves list of supported commercial banks & mobile money providers.
   */
  async listBanks(currency: FiatCurrency = FiatCurrency.NGN) {
    return await this.payoutProvider.listBanks(currency);
  }

  /**
   * Resolves NUBAN account number against Nigerian/Ghanaian banking rails.
   */
  async resolveAccount(accountNumber: string, bankCode: string) {
    return await this.payoutProvider.resolveAccount(accountNumber, bankCode);
  }

  /**
   * Adds a verified bank account to user profile with NUBAN name enquiry.
   */
  async addBankAccount(userId: string, dto: AddBankAccountDto) {
    const resolution = await this.resolveAccount(dto.accountNumber, dto.bankCode);

    const existingAccounts = await this.prisma.bankAccount.findMany({
      where: { userId },
    });

    const isFirstAccount = existingAccounts.length === 0;
    const shouldBeDefault = dto.isDefault || isFirstAccount;

    if (shouldBeDefault) {
      // Clear existing default flags
      await this.prisma.bankAccount.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }

    const bankAccount = await this.prisma.bankAccount.upsert({
      where: {
        userId_bankCode_accountNumber: {
          userId,
          bankCode: dto.bankCode,
          accountNumber: dto.accountNumber,
        },
      },
      update: {
        bankName: resolution.bankName,
        verifiedName: resolution.accountName,
        isDefault: shouldBeDefault,
        currency: dto.currency || FiatCurrency.NGN,
        isVerified: true,
      },
      create: {
        userId,
        bankCode: dto.bankCode,
        bankName: resolution.bankName,
        accountNumber: dto.accountNumber,
        verifiedName: resolution.accountName,
        currency: dto.currency || FiatCurrency.NGN,
        isDefault: shouldBeDefault,
        isVerified: true,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: 'BANK_ACCOUNT_ADDED',
        entityType: 'USER',
        entityId: bankAccount.id,
        newState: {
          bankCode: dto.bankCode,
          accountNumber: dto.accountNumber,
          verifiedName: resolution.accountName,
          isDefault: shouldBeDefault,
        },
      },
    });

    return bankAccount;
  }

  /**
   * Lists user's saved bank accounts.
   */
  async getUserBankAccounts(userId: string) {
    return await this.prisma.bankAccount.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
  }

  /**
   * Deletes a bank account.
   */
  async deleteBankAccount(userId: string, bankAccountId: string) {
    const account = await this.prisma.bankAccount.findFirst({
      where: { id: bankAccountId, userId },
    });

    if (!account) {
      throw new NotFoundException('Bank account not found');
    }

    await this.prisma.bankAccount.delete({ where: { id: bankAccountId } });
    return { message: 'Bank account successfully removed' };
  }

  /**
   * Core Off-Ramp Withdrawal Pipeline (Double-Entry Protected).
   * 1. PIN verification
   * 2. KYC limit enforcement
   * 3. Balance hold reservation in ledger
   * 4. Payout gateway dispatch
   * 5. Settle or Release on failure
   */
  async initiateWithdrawal(userId: string, dto: InitiateWithdrawalDto) {
    const amountMinor = BigInt(dto.amountMinor);
    const cleanIdempotencyKey = dto.idempotencyKey.trim();
    const currency = dto.currency || FiatCurrency.NGN;

    // 1. Verify Transaction PIN
    await this.pinService.verifyPin(userId, dto.pin);

    // 2. Enforce KYC Tier Limits (Rule #6)
    await this.kycService.enforcePayoutLimits(userId, amountMinor);

    // 3. Verify Target Bank Account
    const bankAccount = await this.prisma.bankAccount.findFirst({
      where: { id: dto.bankAccountId, userId },
    });
    if (!bankAccount || !bankAccount.isVerified) {
      throw new BadRequestException('Invalid or unverified destination bank account');
    }

    // 4. Check Idempotency: Return existing payout if key matches
    const existingPayout = await this.prisma.payout.findUnique({
      where: { idempotencyKey: cleanIdempotencyKey },
    });
    if (existingPayout) {
      this.logger.log(`[IDEMPOTENCY] Payout with key [${cleanIdempotencyKey}] already processed.`);
      return existingPayout;
    }

    // 5. Reserve Balance in Double-Entry Ledger (ACTIVE -> HOLD)
    await this.ledgerService.hold(
      userId,
      amountMinor,
      currency,
      `HOLD-${cleanIdempotencyKey}`,
      dto.narration || 'Payout withdrawal hold',
    );

    // 6. Record Payout in Database
    let payout = await this.prisma.payout.create({
      data: {
        userId,
        bankAccountId: bankAccount.id,
        idempotencyKey: cleanIdempotencyKey,
        amountMinor,
        currency,
        status: PayoutStatus.HOLD_RESERVED,
        attempts: 1,
        lastAttemptAt: new Date(),
      },
    });

    // 7. Dispatch Transfer to Payout Rail
    try {
      const transferRes = await this.payoutProvider.createTransfer({
        idempotencyKey: cleanIdempotencyKey,
        amountMinor,
        currency,
        bankCode: bankAccount.bankCode,
        accountNumber: bankAccount.accountNumber,
        recipientName: bankAccount.verifiedName,
        narration: dto.narration,
      });

      payout = await this.prisma.payout.update({
        where: { id: payout.id },
        data: {
          providerRef: transferRes.providerRef,
          status: transferRes.status,
          feeMinor: transferRes.feeMinor,
        },
      });

      // If transfer succeeded immediately
      if (transferRes.status === PayoutStatus.SUCCESS) {
        await this.ledgerService.settleHold(
          userId,
          amountMinor,
          currency,
          `SETTLE-${cleanIdempotencyKey}`,
          'Payout transfer settled',
        );
      }

      await this.prisma.auditLog.create({
        data: {
          actorType: 'USER',
          actorId: userId,
          action: 'PAYOUT_INITIATED',
          entityType: 'PAYOUT',
          entityId: payout.id,
          newState: {
            idempotencyKey: cleanIdempotencyKey,
            amountMinor: amountMinor.toString(),
            status: payout.status,
            bankCode: bankAccount.bankCode,
          },
        },
      });

      return payout;
    } catch (err) {
      // Immediate failure: release held balance back to user
      this.logger.error(`Payout dispatch failed for key [${cleanIdempotencyKey}]: ${err.message}`);

      await this.ledgerService.release(
        userId,
        amountMinor,
        currency,
        `REL-${cleanIdempotencyKey}`,
        'Release hold after payout dispatch failure',
      );

      payout = await this.prisma.payout.update({
        where: { id: payout.id },
        data: {
          status: PayoutStatus.FAILED,
          failureReason: err.message || 'Transfer failed at gateway',
        },
      });

      throw new BadRequestException(`Payout failed: ${err.message}`);
    }
  }

  /**
   * Payout Webhook Listener (Handles asynchronous transfer notifications).
   */
  async handlePayoutWebhook(payload: PayoutWebhookDto, headers: Record<string, any> = {}) {
    const isSignatureValid = this.payoutProvider.verifyWebhookSignature(headers, JSON.stringify(payload));
    if (!isSignatureValid) {
      throw new BadRequestException('Invalid payout webhook signature');
    }

    const providerRef = payload.data?.reference;
    if (!providerRef) {
      throw new BadRequestException('Missing transfer reference in webhook payload');
    }

    const payout = await this.prisma.payout.findFirst({
      where: { providerRef },
    });

    if (!payout) {
      this.logger.warn(`Webhook received for unknown payout reference: ${providerRef}`);
      return { message: 'Reference not found' };
    }

    if (payout.status === PayoutStatus.SUCCESS || payout.status === PayoutStatus.FAILED) {
      return { message: 'Payout already in terminal state' };
    }

    if (payload.data.status === 'SUCCESS') {
      // Settle hold in double-entry ledger!
      await this.ledgerService.settleHold(
        payout.userId,
        payout.amountMinor,
        payout.currency,
        `SETTLE-${payout.idempotencyKey}`,
        'Payout confirmed via gateway webhook',
      );

      await this.prisma.payout.update({
        where: { id: payout.id },
        data: { status: PayoutStatus.SUCCESS },
      });

      await this.prisma.auditLog.create({
        data: {
          actorType: 'SYSTEM',
          action: 'PAYOUT_COMPLETED',
          entityType: 'PAYOUT',
          entityId: payout.id,
          newState: { status: PayoutStatus.SUCCESS },
        },
      });
    } else if (payload.data.status === 'FAILED' || payload.data.status === 'REVERSED') {
      // Release held funds back to customer active balance!
      await this.ledgerService.release(
        payout.userId,
        payout.amountMinor,
        payout.currency,
        `REL-${payout.idempotencyKey}`,
        'Release hold after gateway transfer failure',
      );

      await this.prisma.payout.update({
        where: { id: payout.id },
        data: {
          status: PayoutStatus.FAILED,
          failureReason: payload.data.reason || 'Transfer failed at recipient bank',
        },
      });

      await this.prisma.auditLog.create({
        data: {
          actorType: 'SYSTEM',
          action: 'PAYOUT_FAILED',
          entityType: 'PAYOUT',
          entityId: payout.id,
          newState: { status: PayoutStatus.FAILED, reason: payload.data.reason },
        },
      });
    }

    return { message: 'Webhook processed successfully' };
  }

  /**
   * Auto-Settlement Toggle: controls whether crypto deposits trigger immediate bank payout.
   */
  async updateAutoPayoutToggle(userId: string, autoPayout: boolean) {
    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: { autoPayout },
      select: { id: true, autoPayout: true },
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: 'ADMIN_ACTION',
        entityType: 'USER',
        entityId: userId,
        newState: { autoPayout },
      },
    });

    return updatedUser;
  }

  /**
   * Automatic settlement trigger upon crypto deposit finality.
   */
  async triggerAutoPayoutForDeposit(userId: string, depositId: string, amountMinor: bigint) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        bankAccounts: { where: { isDefault: true, isVerified: true } },
      },
    });

    if (!user || !user.autoPayout || user.bankAccounts.length === 0) {
      return null; // Kept in fiat active ledger balance
    }

    const defaultBank = user.bankAccounts[0];
    const idempotencyKey = `AUTO-PAY-${depositId}`;

    // Place hold & dispatch payout
    await this.ledgerService.hold(
      userId,
      amountMinor,
      defaultBank.currency,
      `HOLD-${idempotencyKey}`,
      'Automated off-ramp bank payout',
    );

    const payout = await this.prisma.payout.create({
      data: {
        userId,
        bankAccountId: defaultBank.id,
        depositId,
        idempotencyKey,
        amountMinor,
        currency: defaultBank.currency,
        status: PayoutStatus.PROCESSING,
        providerRef: `TRF_AUTO_${depositId.slice(0, 8)}`,
      },
    });

    // In sandbox, settle immediately
    await this.ledgerService.settleHold(
      userId,
      amountMinor,
      defaultBank.currency,
      `SETTLE-${idempotencyKey}`,
      'Automated off-ramp bank payout settled',
    );

    await this.prisma.payout.update({
      where: { id: payout.id },
      data: { status: PayoutStatus.SUCCESS },
    });

    return payout;
  }

  /**
   * Reconciliation worker: checks pending transfers older than 2 minutes.
   */
  async reconcilePendingPayouts() {
    const threshold = new Date(Date.now() - 2 * 60 * 1000);
    const pending = await this.prisma.payout.findMany({
      where: {
        status: { in: [PayoutStatus.PROCESSING, PayoutStatus.HOLD_RESERVED] },
        createdAt: { lt: threshold },
      },
    });

    let reconciledCount = 0;

    for (const p of pending) {
      if (!p.providerRef) continue;

      const statusRes = await this.payoutProvider.getTransferStatus(p.providerRef);
      if (statusRes.status === PayoutStatus.SUCCESS) {
        await this.ledgerService.settleHold(
          p.userId,
          p.amountMinor,
          p.currency,
          `SETTLE-${p.idempotencyKey}`,
        );
        await this.prisma.payout.update({
          where: { id: p.id },
          data: { status: PayoutStatus.SUCCESS },
        });
        reconciledCount++;
      }
    }

    return { reconciledCount, totalPending: pending.length };
  }

  /**
   * Retrieves payout history for a user.
   */
  async getUserPayouts(userId: string) {
    return await this.prisma.payout.findMany({
      where: { userId },
      include: {
        bankAccount: {
          select: { bankName: true, accountNumber: true, verifiedName: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}
