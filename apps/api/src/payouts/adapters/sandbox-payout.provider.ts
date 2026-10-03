import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import {
  IPayoutProvider,
  BankInstitution,
  AccountResolutionResult,
  CreateTransferParams,
  TransferResult,
} from '../interfaces/payout-provider.interface';
import { FiatCurrency, PayoutStatus } from '@prisma/client';
import * as crypto from 'crypto';

@Injectable()
export class SandboxPayoutProvider implements IPayoutProvider {
  private readonly logger = new Logger(SandboxPayoutProvider.name);

  private readonly NIGERIAN_BANKS: BankInstitution[] = [
    { code: '058', name: 'Guaranty Trust Bank (GTBank)', slug: 'gtbank', currency: FiatCurrency.NGN },
    { code: '011', name: 'First Bank of Nigeria', slug: 'first-bank', currency: FiatCurrency.NGN },
    { code: '033', name: 'United Bank for Africa (UBA)', slug: 'uba', currency: FiatCurrency.NGN },
    { code: '057', name: 'Zenith Bank', slug: 'zenith-bank', currency: FiatCurrency.NGN },
    { code: '044', name: 'Access Bank', slug: 'access-bank', currency: FiatCurrency.NGN },
    { code: '035', name: 'Wema Bank (ALAT)', slug: 'wema-alat', currency: FiatCurrency.NGN },
    { code: '070', name: 'Fidelity Bank', slug: 'fidelity-bank', currency: FiatCurrency.NGN },
    { code: '214', name: 'First City Monument Bank (FCMB)', slug: 'fcmb', currency: FiatCurrency.NGN },
    { code: '090110', name: 'Kuda Microfinance Bank', slug: 'kuda-bank', currency: FiatCurrency.NGN },
    { code: '999992', name: 'OPay Digital Services', slug: 'opay', currency: FiatCurrency.NGN },
    { code: '999991', name: 'PalmPay Limited', slug: 'palmpay', currency: FiatCurrency.NGN },
  ];

  private readonly GHANAIAN_BANKS: BankInstitution[] = [
    { code: 'MTN', name: 'MTN Mobile Money Ghana', slug: 'mtn-momo', currency: FiatCurrency.GHS },
    { code: 'VOD', name: 'Telecel (Vodafone) Cash', slug: 'telecel-cash', currency: FiatCurrency.GHS },
    { code: 'GCB', name: 'GCB Bank Limited', slug: 'gcb-bank', currency: FiatCurrency.GHS },
    { code: 'ECO', name: 'Ecobank Ghana', slug: 'ecobank-ghana', currency: FiatCurrency.GHS },
    { code: 'CAL', name: 'CalBank Ghana', slug: 'calbank', currency: FiatCurrency.GHS },
  ];

  async listBanks(currency: FiatCurrency): Promise<BankInstitution[]> {
    if (currency === FiatCurrency.GHS) {
      return this.GHANAIAN_BANKS;
    }
    return this.NIGERIAN_BANKS;
  }

  async resolveAccount(accountNumber: string, bankCode: string): Promise<AccountResolutionResult> {
    const cleanNumber = accountNumber.trim();
    if (!/^\d{10}$/.test(cleanNumber)) {
      throw new BadRequestException('Nigerian NUBAN account number must be exactly 10 digits');
    }

    const allBanks = [...this.NIGERIAN_BANKS, ...this.GHANAIAN_BANKS];
    const bank = allBanks.find((b) => b.code === bankCode);
    if (!bank) {
      throw new BadRequestException(`Bank with code [${bankCode}] is not supported`);
    }

    // Simulated rejection for test account numbers starting with 999
    if (cleanNumber.startsWith('999')) {
      throw new BadRequestException('Account number could not be resolved with NUBAN provider');
    }

    // Return realistic verified name
    return {
      accountNumber: cleanNumber,
      bankCode,
      bankName: bank.name,
      accountName: 'CHUKWUDI EMMANUEL OKONKWO',
    };
  }

  async createTransfer(params: CreateTransferParams): Promise<TransferResult> {
    const providerRef = `TRF_SANDBOX_${crypto.randomBytes(6).toString('hex').toUpperCase()}`;
    const feeMinor = params.currency === FiatCurrency.NGN ? BigInt(5375) : BigInt(50); // ₦53.75 or GH₵0.50 fee

    this.logger.log(
      `[SANDBOX PAYOUT] Dispatched ${params.currency} payout of ${params.amountMinor.toString()} minor units to ${params.bankCode}:${params.accountNumber} (Ref: ${providerRef})`,
    );

    return {
      providerRef,
      status: PayoutStatus.PROCESSING,
      feeMinor,
    };
  }

  async getTransferStatus(providerRef: string): Promise<{
    providerRef: string;
    status: PayoutStatus;
    failureReason?: string;
  }> {
    return {
      providerRef,
      status: PayoutStatus.SUCCESS,
    };
  }

  verifyWebhookSignature(headers: Record<string, any>, rawPayload: string): boolean {
    const signature = headers['x-payout-signature'] || headers['x-webhook-signature'];
    return signature === 'sandbox-test-valid-sig' || !signature; // Default true in sandbox unless specified
  }
}
