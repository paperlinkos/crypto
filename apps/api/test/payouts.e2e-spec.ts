import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { AuthService } from '../src/auth/auth.service';
import { PinService } from '../src/auth/pin.service';
import { KycService } from '../src/kyc/kyc.service';
import { LedgerService } from '../src/ledger/ledger.service';
import { FiatCurrency, PayoutStatus } from '@prisma/client';

describe('Bank Accounts & Off-Ramp Payouts (E2E)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let authService: AuthService;
  let pinService: PinService;
  let kycService: KycService;
  let ledgerService: LedgerService;

  let testUserId: string;
  let userAccessToken: string;
  let adminAccessToken: string;
  let createdBankAccountId: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

    await app.init();

    prisma = app.get(PrismaService);
    authService = app.get(AuthService);
    pinService = app.get(PinService);
    kycService = app.get(KycService);
    ledgerService = app.get(LedgerService);

    // 1. Create test user
    const testEmail = `payout_tester_${Date.now()}@offramp.test`;
    const otpRes = await authService.requestOtp({ recipient: testEmail, purpose: 'SIGNUP' });
    const signupRes = await authService.signup(
      {
        recipient: testEmail,
        code: otpRes.sandboxCode || '123456',
        password: 'Password123!',
      },
      { fingerprint: 'payout-test-device' },
    );

    testUserId = signupRes.user.id;
    userAccessToken = signupRes.accessToken;

    // 2. Set transaction PIN
    await pinService.setPin(testUserId, '1234');

    // 3. Upgrade user to Tier 2 (₦1M single tx limit, ₦5M daily limit)
    await kycService.submitTier1(testUserId, {
      idType: 'BVN',
      idNumber: '22334455667',
      firstName: 'Chukwudi',
      lastName: 'Okonkwo',
    });
    await kycService.submitTier2(testUserId, {
      idType: 'PASSPORT',
      idNumber: 'A12345678',
      selfieBase64: 'sample-base64',
    });

    // 4. Fund user's NGN ledger balance with ₦500,000 (50,000,000 kobo)
    await ledgerService.credit(
      testUserId,
      BigInt(50000000),
      'NGN',
      `FUND-TEST-${Date.now()}`,
      'Initial test seed balance',
    );

    // 5. Login Admin
    const adminRes = await authService.adminLogin({
      email: 'admin@offramp.test',
      password: 'AdminPassword123!',
    });
    adminAccessToken = adminRes.accessToken;
  });

  afterAll(async () => {
    if (testUserId) {
      await prisma.payout.deleteMany({ where: { userId: testUserId } });
      await prisma.bankAccount.deleteMany({ where: { userId: testUserId } });
      await prisma.ledgerEntry.deleteMany({
        where: {
          OR: [
            { debitAccount: { userId: testUserId } },
            { creditAccount: { userId: testUserId } },
          ],
        },
      });
      await prisma.ledgerAccount.deleteMany({ where: { userId: testUserId } });
      await prisma.kycProfile.deleteMany({ where: { userId: testUserId } });
      await prisma.user.deleteMany({ where: { id: testUserId } });
    }
    await app.close();
  });

  describe('1. Bank Directory & NUBAN Name Enquiry', () => {
    it('GET /api/v1/payouts/banks - should list supported Nigerian commercial banks', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/payouts/banks?currency=NGN')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);
      const gtbank = res.body.find((b: any) => b.code === '058');
      expect(gtbank).toBeDefined();
      expect(gtbank.name).toBe('Guaranty Trust Bank (GTBank)');
    });

    it('POST /api/v1/payouts/resolve-account - should resolve account name for valid NUBAN', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/payouts/resolve-account')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          accountNumber: '0123456789',
          bankCode: '058',
        })
        .expect(200);

      expect(res.body.accountNumber).toBe('0123456789');
      expect(res.body.accountName).toBe('CHUKWUDI EMMANUEL OKONKWO');
      expect(res.body.bankName).toBe('Guaranty Trust Bank (GTBank)');
    });

    it('POST /api/v1/payouts/resolve-account - should reject non-existent bank account (999...)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/payouts/resolve-account')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          accountNumber: '9990000000',
          bankCode: '058',
        })
        .expect(400);
    });
  });

  describe('2. Bank Account Management', () => {
    it('POST /api/v1/payouts/bank-accounts - should add verified bank account as default', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/payouts/bank-accounts')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          bankCode: '058',
          accountNumber: '0123456789',
          isDefault: true,
          currency: FiatCurrency.NGN,
        })
        .expect(201);

      expect(res.body.id).toBeDefined();
      expect(res.body.accountNumber).toBe('0123456789');
      expect(res.body.verifiedName).toBe('CHUKWUDI EMMANUEL OKONKWO');
      expect(res.body.isDefault).toBe(true);
      expect(res.body.isVerified).toBe(true);

      createdBankAccountId = res.body.id;
    });

    it('GET /api/v1/payouts/bank-accounts - should retrieve saved bank accounts', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/payouts/bank-accounts')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].id).toBe(createdBankAccountId);
    });
  });

  describe('3. PIN & Limit Enforced Off-Ramp Withdrawal', () => {
    it('POST /api/v1/payouts/withdraw - should reject withdrawal with wrong PIN', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/payouts/withdraw')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          bankAccountId: createdBankAccountId,
          amountMinor: '5000000', // ₦50,000
          pin: '9999',
          idempotencyKey: `FAIL-PIN-${Date.now()}`,
        })
        .expect(400);
    });

    it('POST /api/v1/payouts/withdraw - should reject withdrawal exceeding Tier 2 single limit (₦1M)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/payouts/withdraw')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          bankAccountId: createdBankAccountId,
          amountMinor: '200000000', // ₦2M (Tier 2 single limit is ₦1M)
          pin: '1234',
          idempotencyKey: `EXCEED-LIMIT-${Date.now()}`,
        })
        .expect(403);
    });

    it('POST /api/v1/payouts/withdraw - should execute valid withdrawal with double-entry hold reservation', async () => {
      const initialBalance = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(initialBalance.availableMinor).toBe('50000000'); // ₦500,000

      const withdrawAmount = '5000000'; // ₦50,000 (5,000,000 kobo)
      const idempotencyKey = `WITHDRAW-SUCCESS-${Date.now()}`;

      const res = await request(app.getHttpServer())
        .post('/api/v1/payouts/withdraw')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          bankAccountId: createdBankAccountId,
          amountMinor: withdrawAmount,
          pin: '1234',
          idempotencyKey,
          narration: 'E2E Off-Ramp Test',
        })
        .expect(200);

      expect(res.body.id).toBeDefined();
      expect(res.body.status).toBe(PayoutStatus.PROCESSING);
      expect(res.body.amountMinor).toBe(withdrawAmount);

      // Verify double-entry ledger balance placed on HOLD
      const balanceAfterHold = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balanceAfterHold.availableMinor).toBe('45000000'); // ₦450,000 available
      expect(balanceAfterHold.heldMinor).toBe('5000000'); // ₦50,000 held

      // Now simulate payout gateway asynchronous webhook SUCCESS notification
      await request(app.getHttpServer())
        .post('/api/v1/payouts/webhook')
        .set('x-payout-signature', 'sandbox-test-valid-sig')
        .send({
          event: 'transfer.success',
          data: {
            reference: res.body.providerRef,
            status: 'SUCCESS',
            amount: 50000,
          },
        })
        .expect(200);

      // Verify double-entry ledger hold settled
      const balanceAfterSettle = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balanceAfterSettle.availableMinor).toBe('45000000');
      expect(balanceAfterSettle.heldMinor).toBe('0'); // Held settled
    });

    it('POST /api/v1/payouts/withdraw - should be idempotent and not double-debit on replay', async () => {
      const replayKey = `WITHDRAW-REPLAY-${Date.now()}`;

      // First call
      const res1 = await request(app.getHttpServer())
        .post('/api/v1/payouts/withdraw')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          bankAccountId: createdBankAccountId,
          amountMinor: '1000000', // ₦10,000
          pin: '1234',
          idempotencyKey: replayKey,
        })
        .expect(200);

      const balanceAfterFirst = await ledgerService.getUserBalances(testUserId, 'NGN');

      // Second call with same idempotencyKey
      const res2 = await request(app.getHttpServer())
        .post('/api/v1/payouts/withdraw')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          bankAccountId: createdBankAccountId,
          amountMinor: '1000000',
          pin: '1234',
          idempotencyKey: replayKey,
        })
        .expect(200);

      expect(res2.body.id).toBe(res1.body.id);

      // Balance MUST NOT have changed on duplicate request
      const balanceAfterSecond = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balanceAfterSecond.availableMinor).toBe(balanceAfterFirst.availableMinor);
    });
  });

  describe('4. Asynchronous Webhooks & Auto-Settlement', () => {
    it('PATCH /api/v1/payouts/auto-settlement - should toggle auto-payout preference', async () => {
      const res = await request(app.getHttpServer())
        .patch('/api/v1/payouts/auto-settlement')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({ autoPayout: true })
        .expect(200);

      expect(res.body.autoPayout).toBe(true);
    });

    it('GET /api/v1/payouts/history - should retrieve user payout history', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/payouts/history')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(2);
    });

    it('POST /api/v1/payouts/reconcile - admin can run payout reconciliation', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/payouts/reconcile')
        .set('Authorization', `Bearer ${adminAccessToken}`)
        .expect(200);

      expect(res.body.reconciledCount).toBeDefined();
    });
  });
});
