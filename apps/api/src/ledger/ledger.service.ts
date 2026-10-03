import {
  Injectable,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerAccountType } from '@prisma/client';

(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

export interface UserBalanceResult {
  userId: string;
  currency: string;
  availableMinor: string;
  heldMinor: string;
  totalMinor: string;
}

@Injectable()
export class LedgerService {
  private readonly logger = new Logger(LedgerService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Retrieves or provisions a user ledger sub-account.
   */
  async getOrCreateUserAccount(
    userId: string,
    currency = 'NGN',
    category: 'ACTIVE' | 'HOLD' = 'ACTIVE',
  ) {
    const cleanCurrency = currency.toUpperCase().trim();
    const prefix = category === 'ACTIVE' ? '2010' : '2020';
    const accountCode = `${prefix}-USER-${userId.slice(0, 8)}-${cleanCurrency}`;

    let account = await this.prisma.ledgerAccount.findUnique({
      where: { accountNumber: accountCode },
    });

    if (!account) {
      account = await this.prisma.ledgerAccount.create({
        data: {
          accountNumber: accountCode,
          name: `User ${category === 'ACTIVE' ? 'Available' : 'Held'} Liability (${cleanCurrency})`,
          type: LedgerAccountType.LIABILITY,
          currency: cleanCurrency,
          userId,
          isActive: true,
        },
      });
    }

    return account;
  }

  /**
   * Retrieves a platform master ledger account.
   */
  async getMasterAccount(accountNumber: string) {
    const account = await this.prisma.ledgerAccount.findUnique({
      where: { accountNumber },
    });
    if (!account) {
      throw new NotFoundException(`Master ledger account [${accountNumber}] not found`);
    }
    return account;
  }

  /**
   * Computes the balance of any ledger account from immutable journal entries.
   * ASSET / EXPENSE: Debits - Credits
   * LIABILITY / EQUITY / REVENUE: Credits - Debits
   */
  async getAccountBalance(accountId: string): Promise<bigint> {
    const account = await this.prisma.ledgerAccount.findUnique({
      where: { id: accountId },
    });
    if (!account) {
      throw new NotFoundException(`Ledger account [${accountId}] not found`);
    }

    const [debitAgg, creditAgg] = await Promise.all([
      this.prisma.ledgerEntry.aggregate({
        where: { debitAccountId: accountId },
        _sum: { amountMinor: true },
      }),
      this.prisma.ledgerEntry.aggregate({
        where: { creditAccountId: accountId },
        _sum: { amountMinor: true },
      }),
    ]);

    const totalDebits = debitAgg._sum.amountMinor || BigInt(0);
    const totalCredits = creditAgg._sum.amountMinor || BigInt(0);

    if (
      account.type === LedgerAccountType.LIABILITY ||
      account.type === LedgerAccountType.EQUITY ||
      account.type === LedgerAccountType.REVENUE
    ) {
      return totalCredits - totalDebits;
    } else {
      // ASSET or EXPENSE
      return totalDebits - totalCredits;
    }
  }

  /**
   * Computes customer balances (available, held, and total) from double-entry entries.
   */
  async getUserBalances(userId: string, currency = 'NGN'): Promise<UserBalanceResult> {
    const cleanCurrency = currency.toUpperCase().trim();
    const activeAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'ACTIVE');
    const holdAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'HOLD');

    const [availableMinor, heldMinor] = await Promise.all([
      this.getAccountBalance(activeAccount.id),
      this.getAccountBalance(holdAccount.id),
    ]);

    const totalMinor = availableMinor + heldMinor;

    return {
      userId,
      currency: cleanCurrency,
      availableMinor: availableMinor.toString(),
      heldMinor: heldMinor.toString(),
      totalMinor: totalMinor.toString(),
    };
  }

  /**
   * Core double-entry posting primitive.
   * Executes within an atomic database transaction.
   * Strict idempotency: returns existing entry if transactionRef already posted.
   */
  async postBalancedEntry(
    debitAccountId: string,
    creditAccountId: string,
    amountMinor: bigint,
    currency: string,
    transactionRef: string,
    description: string,
    metadata?: any,
  ) {
    if (amountMinor <= BigInt(0)) {
      throw new BadRequestException('Transaction amount must be a positive integer minor unit greater than 0');
    }

    if (debitAccountId === creditAccountId) {
      throw new BadRequestException('Debit and credit accounts must be distinct');
    }

    const cleanRef = transactionRef.trim();

    // 1. Idempotency Check: if this exact transactionRef exists, return the existing record
    const existing = await this.prisma.ledgerEntry.findFirst({
      where: { transactionRef: cleanRef },
    });
    if (existing) {
      this.logger.log(`[IDEMPOTENCY] Ledger entry for ref [${cleanRef}] already exists. Returning recorded entry.`);
      return { entry: existing, isDuplicate: true };
    }

    // 2. Atomic Database Transaction
    const entry = await this.prisma.$transaction(async (tx) => {
      // Ensure accounts exist and are active
      const [debitAcc, creditAcc] = await Promise.all([
        tx.ledgerAccount.findUnique({ where: { id: debitAccountId } }),
        tx.ledgerAccount.findUnique({ where: { id: creditAccountId } }),
      ]);

      if (!debitAcc || !debitAcc.isActive) {
        throw new BadRequestException(`Debit account [${debitAccountId}] invalid or inactive`);
      }
      if (!creditAcc || !creditAcc.isActive) {
        throw new BadRequestException(`Credit account [${creditAccountId}] invalid or inactive`);
      }

      const createdEntry = await tx.ledgerEntry.create({
        data: {
          transactionRef: cleanRef,
          debitAccountId,
          creditAccountId,
          amountMinor,
          currency: currency.toUpperCase().trim(),
          description,
          metadata: metadata || {},
        },
      });

      // Audit trail
      await tx.auditLog.create({
        data: {
          actorType: 'SYSTEM',
          action: 'LEDGER_POSTED',
          entityType: 'LEDGER',
          entityId: createdEntry.id,
          newState: {
            ref: cleanRef,
            debitAccount: debitAcc.accountNumber,
            creditAccount: creditAcc.accountNumber,
            amountMinor: amountMinor.toString(),
            currency,
          },
        },
      });

      return createdEntry;
    });

    return { entry, isDuplicate: false };
  }

  /**
   * High-Level Primitive: Credit User Account (e.g. from crypto off-ramp deposit conversion)
   */
  async credit(
    userId: string,
    amountMinor: bigint,
    currency: string,
    idempotencyRef: string,
    description = 'Ledger credit',
    metadata?: any,
  ) {
    const cleanCurrency = currency.toUpperCase().trim();
    const userAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'ACTIVE');

    // Default clearing source based on currency/asset
    let masterClearingNumber = '1030-BANK-FLOAT-NGN';
    if (cleanCurrency === 'USDT') masterClearingNumber = '1010-VAULT-USDT';
    else if (cleanCurrency === 'BTC') masterClearingNumber = '1020-VAULT-BTC';

    const masterAccount = await this.getMasterAccount(masterClearingNumber);

    return await this.postBalancedEntry(
      masterAccount.id,
      userAccount.id,
      amountMinor,
      cleanCurrency,
      idempotencyRef,
      description,
      metadata,
    );
  }

  /**
   * High-Level Primitive: Debit User Account (e.g. direct withdrawal)
   */
  async debit(
    userId: string,
    amountMinor: bigint,
    currency: string,
    idempotencyRef: string,
    description = 'Ledger debit',
    metadata?: any,
  ) {
    const cleanCurrency = currency.toUpperCase().trim();
    const userAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'ACTIVE');

    // Idempotency check before balance verification
    const existing = await this.prisma.ledgerEntry.findFirst({
      where: { transactionRef: idempotencyRef.trim() },
    });
    if (existing) {
      return { entry: existing, isDuplicate: true };
    }

    // Verify sufficient available balance
    const available = await this.getAccountBalance(userAccount.id);
    if (available < amountMinor) {
      throw new BadRequestException(
        `Insufficient available balance. Available: ${available.toString()}, Requested: ${amountMinor.toString()}`,
      );
    }

    let masterClearingNumber = '1030-BANK-FLOAT-NGN';
    if (cleanCurrency === 'USDT') masterClearingNumber = '1010-VAULT-USDT';
    else if (cleanCurrency === 'BTC') masterClearingNumber = '1020-VAULT-BTC';

    const masterAccount = await this.getMasterAccount(masterClearingNumber);

    return await this.postBalancedEntry(
      userAccount.id,
      masterAccount.id,
      amountMinor,
      cleanCurrency,
      idempotencyRef,
      description,
      metadata,
    );
  }

  /**
   * High-Level Primitive: Hold funds (Reserves balance for pending payout)
   */
  async hold(
    userId: string,
    amountMinor: bigint,
    currency: string,
    idempotencyRef: string,
    description = 'Payout reserve hold',
    metadata?: any,
  ) {
    const cleanCurrency = currency.toUpperCase().trim();
    const userActiveAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'ACTIVE');
    const userHoldAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'HOLD');

    // Idempotency check
    const existing = await this.prisma.ledgerEntry.findFirst({
      where: { transactionRef: idempotencyRef.trim() },
    });
    if (existing) {
      return { entry: existing, isDuplicate: true };
    }

    // Check available balance
    const available = await this.getAccountBalance(userActiveAccount.id);
    if (available < amountMinor) {
      throw new BadRequestException(
        `Insufficient funds to place hold. Available: ${available.toString()}, Required: ${amountMinor.toString()}`,
      );
    }

    // Move from ACTIVE to HOLD
    return await this.postBalancedEntry(
      userActiveAccount.id,
      userHoldAccount.id,
      amountMinor,
      cleanCurrency,
      idempotencyRef,
      description,
      metadata,
    );
  }

  /**
   * High-Level Primitive: Release held funds (Returns funds back to active balance on payout failure)
   */
  async release(
    userId: string,
    amountMinor: bigint,
    currency: string,
    idempotencyRef: string,
    description = 'Release held funds',
    metadata?: any,
  ) {
    const cleanCurrency = currency.toUpperCase().trim();
    const userActiveAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'ACTIVE');
    const userHoldAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'HOLD');

    // Idempotency check
    const existing = await this.prisma.ledgerEntry.findFirst({
      where: { transactionRef: idempotencyRef.trim() },
    });
    if (existing) {
      return { entry: existing, isDuplicate: true };
    }

    // Check held balance
    const held = await this.getAccountBalance(userHoldAccount.id);
    if (held < amountMinor) {
      throw new BadRequestException(
        `Insufficient held funds to release. Held: ${held.toString()}, Requested: ${amountMinor.toString()}`,
      );
    }

    // Move from HOLD back to ACTIVE
    return await this.postBalancedEntry(
      userHoldAccount.id,
      userActiveAccount.id,
      amountMinor,
      cleanCurrency,
      idempotencyRef,
      description,
      metadata,
    );
  }

  /**
   * High-Level Primitive: Settle held funds (Clears held liability upon successful payout confirmation)
   */
  async settleHold(
    userId: string,
    amountMinor: bigint,
    currency: string,
    idempotencyRef: string,
    description = 'Settlement of held funds upon payout completion',
    metadata?: any,
  ) {
    const cleanCurrency = currency.toUpperCase().trim();
    const userHoldAccount = await this.getOrCreateUserAccount(userId, cleanCurrency, 'HOLD');
    const masterAccount = await this.getMasterAccount('1030-BANK-FLOAT-NGN');

    // Idempotency check
    const existing = await this.prisma.ledgerEntry.findFirst({
      where: { transactionRef: idempotencyRef.trim() },
    });
    if (existing) {
      return { entry: existing, isDuplicate: true };
    }

    const held = await this.getAccountBalance(userHoldAccount.id);
    if (held < amountMinor) {
      throw new BadRequestException(
        `Insufficient held funds to settle. Held: ${held.toString()}, Requested: ${amountMinor.toString()}`,
      );
    }

    return await this.postBalancedEntry(
      userHoldAccount.id,
      masterAccount.id,
      amountMinor,
      cleanCurrency,
      idempotencyRef,
      description,
      metadata,
    );
  }
}
