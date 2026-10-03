import { Injectable, NotImplementedException } from '@nestjs/common';
import {
  IWalletProvider,
  GeneratedAddress,
  DepositStatusResult,
} from '../interfaces/wallet-provider.interface';
import { CryptoAsset, BlockchainNetwork } from '@prisma/client';

/**
 * Production Wallet Custody & Deposit Adapter
 *
 * Supported Vendors:
 * 1. Yellow Card Payments API: https://docs.yellowcard.io/
 * 2. Fireblocks Non-Custodial / Embedded Wallets API: https://developers.fireblocks.com/
 * 3. Quidax Crypto Deposit Webhooks: https://developer.quidax.com/
 *
 * To activate in production:
 * 1. Set WALLET_PROVIDER_MODE=production in .env
 * 2. Provide API_KEY, SECRET, and WEBHOOK_SECRET in environment variables.
 * 3. Implement the methods below against the vendor's REST & Webhook specification.
 */
@Injectable()
export class ProductionWalletProvider implements IWalletProvider {
  async createAddress(
    userId: string,
    asset: CryptoAsset,
    network: BlockchainNetwork,
  ): Promise<GeneratedAddress> {
    // TODO: Call vendor API (e.g. POST /v1/wallets/generate-address)
    // Docs: https://docs.yellowcard.io/docs/crypto-addresses
    throw new NotImplementedException(
      'ProductionWalletProvider: Real vendor keys not configured. Switch WALLET_PROVIDER_MODE=sandbox in development.',
    );
  }

  async getDepositStatus(txHash: string): Promise<DepositStatusResult | null> {
    // TODO: Call vendor API (e.g. GET /v1/transactions/{txHash})
    // Docs: https://docs.yellowcard.io/docs/transaction-status
    throw new NotImplementedException(
      'ProductionWalletProvider: Real vendor keys not configured.',
    );
  }

  verifyWebhookSignature(headers: Record<string, any>, rawPayload: string): boolean {
    // TODO: Verify HMAC-SHA512 / RSA signature with vendor's public key or secret
    return false;
  }
}
