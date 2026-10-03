import { Injectable, NotImplementedException } from '@nestjs/common';
import {
  IPayoutProvider,
  BankInstitution,
  AccountResolutionResult,
  CreateTransferParams,
  TransferResult,
} from '../interfaces/payout-provider.interface';
import { FiatCurrency, PayoutStatus } from '@prisma/client';

/**
 * Production Payout Disbursement Gateway Adapter
 *
 * Supported Vendors:
 * 1. Paystack Transfers API (Nigeria & Ghana): https://paystack.com/docs/transfers/
 * 2. Monnify Disbursement API (Nigeria): https://teamapt.atlassian.net/wiki/spaces/MON/pages/212009028/Disbursements
 * 3. Flutterwave Payouts API: https://developer.flutterwave.com/docs/transfers
 * 4. Yellow Card Local Currency Payouts: https://docs.yellowcard.io/docs/local-payouts
 */
@Injectable()
export class ProductionPayoutProvider implements IPayoutProvider {
  async listBanks(currency: FiatCurrency): Promise<BankInstitution[]> {
    // TODO: Call GET https://api.paystack.co/bank?currency=NGN
    throw new NotImplementedException(
      'ProductionPayoutProvider: Real API keys not configured. Switch PAYOUT_PROVIDER_MODE=sandbox in development.',
    );
  }

  async resolveAccount(accountNumber: string, bankCode: string): Promise<AccountResolutionResult> {
    // TODO: Call GET https://api.paystack.co/bank/resolve?account_number=...&bank_code=...
    throw new NotImplementedException(
      'ProductionPayoutProvider: Real API keys not configured.',
    );
  }

  async createTransfer(params: CreateTransferParams): Promise<TransferResult> {
    // TODO: Call POST https://api.paystack.co/transfer (or Monnify /v2/disbursements/single)
    throw new NotImplementedException(
      'ProductionPayoutProvider: Real API keys not configured.',
    );
  }

  async getTransferStatus(providerRef: string): Promise<{
    providerRef: string;
    status: PayoutStatus;
    failureReason?: string;
  }> {
    throw new NotImplementedException(
      'ProductionPayoutProvider: Real API keys not configured.',
    );
  }

  verifyWebhookSignature(headers: Record<string, any>, rawPayload: string): boolean {
    return false;
  }
}
