import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';
import {
  IWalletProvider,
  GeneratedAddress,
  DepositStatusResult,
} from '../interfaces/wallet-provider.interface';
import { CryptoAsset, BlockchainNetwork, DepositStatus } from '@prisma/client';

@Injectable()
export class SandboxWalletProvider implements IWalletProvider {
  private readonly logger = new Logger(SandboxWalletProvider.name);
  private readonly SANDBOX_SECRET = 'sandbox_wallet_webhook_secret_key_123';

  async createAddress(
    userId: string,
    asset: CryptoAsset,
    network: BlockchainNetwork,
  ): Promise<GeneratedAddress> {
    const hash = crypto
      .createHash('sha256')
      .update(`${userId}:${asset}:${network}:sandbox_salt`)
      .digest('hex');

    let address = '';

    switch (network) {
      case BlockchainNetwork.TRON_TRC20:
        // TRC20 addresses start with T and are 34 characters long
        address = `T${hash.slice(0, 33).toUpperCase()}`;
        break;
      case BlockchainNetwork.BITCOIN:
        // Native SegWit starts with bc1q
        address = `bc1q${hash.slice(0, 38).toLowerCase()}`;
        break;
      case BlockchainNetwork.ETHEREUM_ERC20:
      case BlockchainNetwork.BINANCE_BEP20:
      case BlockchainNetwork.POLYGON:
      default:
        // EVM format starts with 0x
        address = `0x${hash.slice(0, 40).toLowerCase()}`;
        break;
    }

    const providerRef = `SANDBOX_${network}_${hash.slice(0, 12)}`;

    this.logger.log(`[SANDBOX WALLET] Created simulated address: [${address}] for ${asset} (${network})`);

    return {
      address,
      providerRef,
    };
  }

  async getDepositStatus(txHash: string): Promise<DepositStatusResult | null> {
    // In sandbox mode, returns simulated 3 confirmations
    return {
      txHash,
      address: 'TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6',
      asset: CryptoAsset.USDT,
      network: BlockchainNetwork.TRON_TRC20,
      amountMinor: BigInt(100000000), // 100 USDT
      confirmations: 3,
      requiredConfirmations: 3,
      status: DepositStatus.CONFIRMED,
    };
  }

  async sendCrypto(
    asset: CryptoAsset,
    network: BlockchainNetwork,
    destinationAddress: string,
    amountMinor: bigint,
  ) {
    const txHash = `0x${crypto.randomBytes(32).toString('hex')}`;
    const providerRef = `SANDBOX_TX_${network}_${crypto.randomBytes(8).toString('hex')}`;
    
    // Minor fee: 1 USDT (1_000_000 micro-units) or 10,000 satoshis for BTC
    const networkFeeMinor = asset === CryptoAsset.BTC ? BigInt(10000) : BigInt(1000000);

    this.logger.log(
      `[SANDBOX WALLET] Simulated on-chain broadcast of ${amountMinor.toString()} minor ${asset} on ${network} to [${destinationAddress}]. TxHash: [${txHash}]`,
    );

    return {
      txHash,
      networkFeeMinor,
      status: 'CONFIRMED' as const,
      providerRef,
    };
  }

  verifyWebhookSignature(headers: Record<string, any>, rawPayload: string): boolean {
    const signature =
      headers['x-wallet-signature'] ||
      headers['x-webhook-signature'] ||
      headers['x-signature'];

    if (!signature) {
      return false;
    }

    // Allow dev sandbox signature token
    if (signature === 'sandbox-test-valid-sig') {
      return true;
    }

    // Standard HMAC SHA256 verification
    const computedHmac = crypto
      .createHmac('sha256', this.SANDBOX_SECRET)
      .update(rawPayload)
      .digest('hex');

    return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(computedHmac));
  }
}
