/**
 * @offramp/shared - Core types, enums, and monetary arithmetic utilities
 * Adheres strictly to Non-Negotiable Rules:
 * 1. Double-entry ledger with integer minor units (kobo, satoshi, micro-units).
 * 2. Idempotency on all financial transactions and webhooks.
 * 3. Provider-agnostic domain models.
 */

// ==========================================
// 1. ENUMS & CONSTANTS
// ==========================================

export enum UserStatus {
  ACTIVE = 'ACTIVE',
  SUSPENDED = 'SUSPENDED',
  LOCKED = 'LOCKED',
}

export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
  SUPPORT = 'SUPPORT',
  COMPLIANCE = 'COMPLIANCE',
  SUPER_ADMIN = 'SUPER_ADMIN',
}

export enum KycTier {
  TIER_0 = 'TIER_0', // Unverified: zero or test-only limits
  TIER_1 = 'TIER_1', // BVN/NIN verified: basic daily limit (e.g. ₦500,000)
  TIER_2 = 'TIER_2', // Government ID + Liveness: intermediate daily limit (e.g. ₦5,000,000)
  TIER_3 = 'TIER_3', // Proof of Address + Enhanced Due Diligence: high/unlimited (e.g. ₦50,000,000)
}

export enum KycStatus {
  NOT_SUBMITTED = 'NOT_SUBMITTED',
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  NEEDS_MORE_INFO = 'NEEDS_MORE_INFO',
}

export enum CryptoAsset {
  USDT = 'USDT',
  USDC = 'USDC',
  BTC = 'BTC',
  ETH = 'ETH',
}

export enum BlockchainNetwork {
  TRON_TRC20 = 'TRON_TRC20',
  ETHEREUM_ERC20 = 'ETHEREUM_ERC20',
  BINANCE_BEP20 = 'BINANCE_BEP20',
  POLYGON = 'POLYGON',
  BITCOIN = 'BITCOIN',
}

export enum FiatCurrency {
  NGN = 'NGN',
  GHS = 'GHS',
}

export enum DepositStatus {
  DETECTED = 'DETECTED',
  CONFIRMING = 'CONFIRMING',
  CONFIRMED = 'CONFIRMED',
  PROCESSED = 'PROCESSED',
  FAILED = 'FAILED',
  REFUNDED = 'REFUNDED',
}

export enum PayoutStatus {
  INITIATED = 'INITIATED',
  HOLD_RESERVED = 'HOLD_RESERVED',
  PROCESSING = 'PROCESSING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
  RECONCILING = 'RECONCILING',
}

export enum LedgerAccountType {
  ASSET = 'ASSET',         // Platform's assets (e.g., crypto held with custody provider, fiat in settlement bank)
  LIABILITY = 'LIABILITY', // Customer deposits owed to users (fiat balances, pending crypto liabilities)
  EQUITY = 'EQUITY',       // Retained earnings, capital
  REVENUE = 'REVENUE',     // FX spread earned, off-ramp fees
  EXPENSE = 'EXPENSE',     // Network gas costs, bank payout gateway fees
}

export enum LedgerEntryType {
  DEBIT = 'DEBIT',
  CREDIT = 'CREDIT',
}

export enum AuditAction {
  USER_SIGNUP = 'USER_SIGNUP',
  USER_LOGIN = 'USER_LOGIN',
  PIN_CHANGED = 'PIN_CHANGED',
  KYC_SUBMITTED = 'KYC_SUBMITTED',
  KYC_REVIEWED = 'KYC_REVIEWED',
  WALLET_CREATED = 'WALLET_CREATED',
  DEPOSIT_DETECTED = 'DEPOSIT_DETECTED',
  DEPOSIT_CONFIRMED = 'DEPOSIT_CONFIRMED',
  RATE_LOCKED = 'RATE_LOCKED',
  SPREAD_UPDATED = 'SPREAD_UPDATED',
  LEDGER_POSTED = 'LEDGER_POSTED',
  PAYOUT_INITIATED = 'PAYOUT_INITIATED',
  PAYOUT_COMPLETED = 'PAYOUT_COMPLETED',
  PAYOUT_FAILED = 'PAYOUT_FAILED',
  BANK_ACCOUNT_ADDED = 'BANK_ACCOUNT_ADDED',
  ADMIN_ACTION = 'ADMIN_ACTION',
}

export enum SupportTicketStatus {
  OPEN = 'OPEN',
  IN_PROGRESS = 'IN_PROGRESS',
  RESOLVED = 'RESOLVED',
  CLOSED = 'CLOSED',
}

export enum SupportTicketPriority {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  URGENT = 'URGENT',
}

// ==========================================
// 2. MONETARY ARITHMETIC UTILITIES (INTEGER MINOR UNITS)
// ==========================================

export class MoneyUtil {
  /**
   * Decimal places per currency/asset:
   * NGN = 2 (Kobo: ₦1.00 = 100 kobo)
   * GHS = 2 (Pesewas: GH₵1.00 = 100 pesewas)
   * USDT / USDC = 6 (micro-units: 1 USDT = 1,000,000 units)
   * BTC = 8 (Satoshis: 1 BTC = 100,000,000 sats)
   * ETH = 18 (Wei: 1 ETH = 10^18 wei - represented as BigInt)
   */
  static getDecimals(currencyOrAsset: string): number {
    switch (currencyOrAsset.toUpperCase()) {
      case 'NGN':
      case 'GHS':
        return 2;
      case 'USDT':
      case 'USDC':
        return 6;
      case 'BTC':
        return 8;
      case 'ETH':
        return 18;
      default:
        return 2;
    }
  }

  /**
   * Converts decimal string/number into integer minor units (BigInt)
   * e.g., "100.50" NGN -> 10050n kobo
   */
  static toMinorUnit(amount: string | number, decimals: number): bigint {
    const parts = amount.toString().trim().split('.');
    const integerPart = parts[0] || '0';
    let fractionalPart = parts[1] || '';

    if (fractionalPart.length > decimals) {
      fractionalPart = fractionalPart.slice(0, decimals);
    } else {
      fractionalPart = fractionalPart.padEnd(decimals, '0');
    }

    return BigInt(integerPart + fractionalPart);
  }

  /**
   * Converts integer minor units (BigInt) into formatted decimal string
   * e.g., 10050n kobo -> "100.50"
   */
  static fromMinorUnit(minorUnits: bigint | string | number, decimals: number): string {
    const rawStr = minorUnits.toString().padStart(decimals + 1, '0');
    const integerPart = rawStr.slice(0, rawStr.length - decimals);
    const fractionalPart = rawStr.slice(rawStr.length - decimals);

    if (decimals === 0) return integerPart;
    return `${integerPart}.${fractionalPart}`;
  }
}

// ==========================================
// 3. CORE DOMAIN TYPES & DTOs
// ==========================================

export interface UserDto {
  id: string;
  email: string | null;
  phoneNumber: string | null;
  status: UserStatus;
  country: string;
  isTwoFactorEnabled: boolean;
  isPinSet: boolean;
  createdAt: Date;
}

export interface KycProfileDto {
  id: string;
  userId: string;
  tier: KycTier;
  status: KycStatus;
  providerRef: string | null;
  idType: string | null;
  idNumberMasked: string | null;
  verifiedName: string | null;
  rejectionReason: string | null;
  dailyLimitMinor: bigint;
  singleTxLimitMinor: bigint;
  createdAt: Date;
  updatedAt: Date;
}

export interface WalletDto {
  id: string;
  userId: string;
  asset: CryptoAsset;
  network: BlockchainNetwork;
  address: string;
  providerRef: string;
  createdAt: Date;
}

export interface RateQuoteDto {
  quoteId: string;
  asset: CryptoAsset;
  fiat: FiatCurrency;
  baseSpotRate: string;
  spreadPercent: string;
  effectiveRate: string; // Rate client receives
  validForSeconds: number;
  expiresAt: Date;
}

export interface BankAccountDto {
  id: string;
  userId: string;
  bankCode: string;
  bankName: string;
  accountNumber: string;
  verifiedAccountName: string;
  currency: FiatCurrency;
  isDefault: boolean;
  createdAt: Date;
}
