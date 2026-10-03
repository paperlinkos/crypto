import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { LedgerService } from '../src/ledger/ledger.service';
import { AuthService } from '../src/auth/auth.service';

describe('Double-Entry Ledger Engine (E2E & Concurrency)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let ledgerService: LedgerService;
  let authService: AuthService;

  let testUserId: string;
  let userAccessToken: string;
  let adminAccessToken: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

    await app.init();

    prisma = app.get(PrismaService);
    ledgerService = app.get(LedgerService);
    authService = app.get(AuthService);

    // Create a dedicated test user for ledger tests
    const testEmail = `ledger_test_${Date.now()}@offramp.test`;
    const otpRes = await authService.requestOtp({
      recipient: testEmail,
      purpose: 'SIGNUP',
    });

    const signupRes = await authService.signup(
      {
        recipient: testEmail,
        code: otpRes.sandboxCode || '123456',
        password: 'Password123!',
      },
      { fingerprint: 'ledger-tester' },
    );
    testUserId = signupRes.user.id;
    userAccessToken = signupRes.accessToken;

    // Login admin
    const adminRes = await authService.adminLogin({
      email: 'admin@offramp.test',
      password: 'AdminPassword123!',
    });
    adminAccessToken = adminRes.accessToken;
  });

  afterAll(async () => {
    if (testUserId) {
      await prisma.ledgerEntry.deleteMany({
        where: {
          OR: [
            { debitAccount: { userId: testUserId } },
            { creditAccount: { userId: testUserId } },
          ],
        },
      });
      await prisma.user.deleteMany({ where: { id: testUserId } });
    }
    await app.close();
  });

  describe('1. Initial Balance Check', () => {
    it('GET /api/v1/ledger/balances - should initialize with zero balance', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/ledger/balances?currency=NGN')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(res.body.availableMinor).toBe('0');
      expect(res.body.heldMinor).toBe('0');
      expect(res.body.totalMinor).toBe('0');
      expect(res.body.currency).toBe('NGN');
    });
  });

  describe('2. Credit & Debit Operations', () => {
    it('Credit: should credit user ₦50,000 (5,000,000 kobo)', async () => {
      const res = await ledgerService.credit(
        testUserId,
        BigInt(5000000),
        'NGN',
        `TEST-CREDIT-${Date.now()}`,
        'Test deposit credit',
      );

      expect(res.isDuplicate).toBe(false);
      expect(res.entry.amountMinor).toBe(BigInt(5000000));

      const balance = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balance.availableMinor).toBe('5000000');
      expect(balance.totalMinor).toBe('5000000');
    });

    it('Debit: should debit user ₦10,000 (1,000,000 kobo)', async () => {
      const res = await ledgerService.debit(
        testUserId,
        BigInt(1000000),
        'NGN',
        `TEST-DEBIT-${Date.now()}`,
        'Test payout debit',
      );

      expect(res.isDuplicate).toBe(false);

      const balance = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balance.availableMinor).toBe('4000000'); // ₦40,000 left
      expect(balance.totalMinor).toBe('4000000');
    });

    it('Debit: should reject debit exceeding available balance', async () => {
      await expect(
        ledgerService.debit(
          testUserId,
          BigInt(999999999), // ₦9.9M (user only has ₦40,000)
          'NGN',
          `TEST-OVERDRAFT-${Date.now()}`,
        ),
      ).rejects.toThrow('Insufficient available balance');
    });
  });

  describe('3. Hold & Release (Payout Reservation)', () => {
    it('Hold: should reserve ₦15,000 (1,500,000 kobo) into held liability', async () => {
      const holdRef = `TEST-HOLD-${Date.now()}`;
      await ledgerService.hold(testUserId, BigInt(1500000), 'NGN', holdRef, 'Payout hold');

      const balance = await ledgerService.getUserBalances(testUserId, 'NGN');
      // Available: 40,000 - 15,000 = 25,000 (2,500,000 kobo)
      expect(balance.availableMinor).toBe('2500000');
      // Held: 15,000 (1,500,000 kobo)
      expect(balance.heldMinor).toBe('1500000');
      // Total remains 40,000 (4,000,000 kobo)
      expect(balance.totalMinor).toBe('4000000');
    });

    it('Release: should release ₦5,000 (500,000 kobo) back to available', async () => {
      await ledgerService.release(
        testUserId,
        BigInt(500000),
        'NGN',
        `TEST-RELEASE-${Date.now()}`,
        'Partial payout failed release',
      );

      const balance = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balance.availableMinor).toBe('3000000'); // ₦30,000
      expect(balance.heldMinor).toBe('1000000'); // ₦10,000
      expect(balance.totalMinor).toBe('4000000'); // ₦40,000
    });

    it('SettleHold: should clear ₦10,000 (1,000,000 kobo) on successful payout', async () => {
      await ledgerService.settleHold(
        testUserId,
        BigInt(1000000),
        'NGN',
        `TEST-SETTLE-${Date.now()}`,
        'Payout confirmed to GTBank',
      );

      const balance = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balance.availableMinor).toBe('3000000'); // ₦30,000
      expect(balance.heldMinor).toBe('0'); // 0 held left
      expect(balance.totalMinor).toBe('3000000'); // ₦30,000
    });
  });

  describe('4. Idempotency & Duplicate Request Protection', () => {
    it('Should return existing entry without duplicate posting when same idempotency key is submitted', async () => {
      const fixedRef = `IDEMPOTENT-REF-FIXED-9999`;

      // 1st Call
      const call1 = await ledgerService.credit(testUserId, BigInt(100000), 'NGN', fixedRef, 'Credit 1');
      expect(call1.isDuplicate).toBe(false);

      // 2nd Call (same key)
      const call2 = await ledgerService.credit(testUserId, BigInt(100000), 'NGN', fixedRef, 'Credit 2');
      expect(call2.isDuplicate).toBe(true);
      expect(call2.entry.id).toBe(call1.entry.id);

      // 3rd Call via HTTP Endpoint
      const res = await request(app.getHttpServer())
        .post(`/api/v1/ledger/credit?userId=${testUserId}`)
        .set('Authorization', `Bearer ${adminAccessToken}`)
        .send({
          amountMinor: '100000',
          currency: 'NGN',
          idempotencyRef: fixedRef,
        })
        .expect(200);

      expect(res.body.isDuplicate).toBe(true);
      expect(res.body.entry.id).toBe(call1.entry.id);
    });
  });

  describe('5. High Concurrency Testing (Atomic Transaction Integrity)', () => {
    it('Should execute 10 concurrent credits of ₦1,000 without race conditions or lost updates', async () => {
      const beforeBalance = await ledgerService.getUserBalances(testUserId, 'NGN');
      const startAvailable = BigInt(beforeBalance.availableMinor);

      const concurrencyCount = 10;
      const creditPerTask = BigInt(100000); // ₦1,000 = 100,000 kobo

      const tasks = Array.from({ length: concurrencyCount }, (_, i) =>
        ledgerService.credit(
          testUserId,
          creditPerTask,
          'NGN',
          `CONCURRENT-CREDIT-${Date.now()}-${i}-${Math.random()}`,
          `Concurrent task ${i}`,
        ),
      );

      await Promise.all(tasks);

      const afterBalance = await ledgerService.getUserBalances(testUserId, 'NGN');
      const expectedTotal = startAvailable + creditPerTask * BigInt(concurrencyCount);

      expect(BigInt(afterBalance.availableMinor)).toBe(expectedTotal);
    });
  });
});
