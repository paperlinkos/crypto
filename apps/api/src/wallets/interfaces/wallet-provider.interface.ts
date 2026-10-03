import { CryptoAsset, BlockchainNetwork, DepositStatus } from '@prisma/client';

export interface GeneratedAddress {
  address: string;
  providerRef: string;
}

export interface DepositStatusResult {
  txHash: string;
  address: string;
  asset: CryptoAsset;
  network: BlockchainNetwork;
  amountMinor: bigint;
  confirmations: number;
  requiredConfirmations: number;
  status: DepositStatus;
}

export interface WebhookDepositPayload {
  txHash: string;
  address: string;
  asset: CryptoAsset;
  network: BlockchainNetwork;
  amountMinor: string; // Serialized string of minor units
  confirmations: number;
}

export interface IWalletProvider {
  /**
   * Generates or assigns a unique per-user deposit address for an asset & blockchain.
   */
  createAddress(
    userId: string,
    asset: CryptoAsset,
    network: BlockchainNetwork,
  ): Promise<GeneratedAddress>;

  /**
   * Queries provider for current blockchain confirmation status of a transaction hash.
   */
  getDepositStatus(txHash: string): Promise<DepositStatusResult | null>;

  /**
   * Verifies incoming webhook signature to prevent tampering.
   */
  verifyWebhookSignature(headers: Record<string, any>, rawPayload: string): boolean;
}
