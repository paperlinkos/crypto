import { FiatCurrency, PayoutStatus } from '@prisma/client';

export interface BankInstitution {
  code: string;
  name: string;
  slug: string;
  currency: FiatCurrency;
}

export interface AccountResolutionResult {
  accountNumber: string;
  bankCode: string;
  accountName: string;
  bankName: string;
}

export interface CreateTransferParams {
  idempotencyKey: string;
  amountMinor: bigint;
  currency: FiatCurrency;
  bankCode: string;
  accountNumber: string;
  recipientName: string;
  narration?: string;
}

export interface TransferResult {
  providerRef: string;
  status: PayoutStatus;
  feeMinor: bigint;
}

export interface IPayoutProvider {
  /**
   * Retrieves list of supported commercial banks & fintech institutions.
   */
  listBanks(currency: FiatCurrency): Promise<BankInstitution[]>;

  /**
   * Resolves an account number against a bank code via NUBAN Name Enquiry.
   */
  resolveAccount(accountNumber: string, bankCode: string): Promise<AccountResolutionResult>;

  /**
   * Initiates a bank transfer payout order.
   */
  createTransfer(params: CreateTransferParams): Promise<TransferResult>;

  /**
   * Queries transfer status from provider rails.
   */
  getTransferStatus(providerRef: string): Promise<{
    providerRef: string;
    status: PayoutStatus;
    failureReason?: string;
  }>;

  /**
   * Validates incoming webhook signature from payout gateway.
   */
  verifyWebhookSignature(headers: Record<string, any>, rawPayload: string): boolean;
}
