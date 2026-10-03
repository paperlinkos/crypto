import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { AuthService } from '../src/auth/auth.service';
import { LedgerService } from '../src/ledger/ledger.service';
import { CryptoAsset, BlockchainNetwork } from '@prisma/client';

describe('Wallets & Deposit Webhook Engine (E2E)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let authService: AuthService;
  let ledgerService: LedgerService;

  let testUserId: string;
  let userAccessToken: string;
  let assignedUsdtAddress: string;

  const testTxHash = `0x_test_tx_hash_${Date.now()}`;

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
    ledgerService = app.get(LedgerService);

    const testEmail = `wallet_tester_${Date.now()}@offramp.test`;
    const otpRes = await authService.requestOtp({ recipient: testEmail, purpose: 'SIGNUP' });
    const signupRes = await authService.signup(
      {
        recipient: testEmail,
        code: otpRes.sandboxCode || '123456',
        password: 'Password123!',
      },
      { fingerprint: 'wallet-tester-device' },
    );

    testUserId = signupRes.user.id;
    userAccessToken = signupRes.accessToken;
  });

  afterAll(async () => {
    if (testUserId) {
      await prisma.deposit.deleteMany({ where: { userId: testUserId } });
      await prisma.ledgerEntry.deleteMany({
        where: {
          OR: [
            { debitAccount: { userId: testUserId } },
            { creditAccount: { userId: testUserId } },
          ],
        },
      });
      await prisma.wallet.deleteMany({ where: { userId: testUserId } });
      await prisma.user.deleteMany({ where: { id: testUserId } });
    }
    await app.close();
  });

  describe('1. Wallet Assignment & QR Generation', () => {
    it('POST /api/v1/wallets/assign - should assign a TRON TRC20 USDT address with QR data', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/wallets/assign')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          asset: CryptoAsset.USDT,
          network: BlockchainNetwork.TRON_TRC20,
        })
        .expect(200);

      expect(res.body.address).toBeDefined();
      expect(res.body.address.startsWith('T')).toBe(true);
      expect(res.body.qrCodeDataUrl).toContain('data:image/png;base64');
      assignedUsdtAddress = res.body.address;
    });

    it('GET /api/v1/wallets - should list assigned user wallets', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/wallets')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);
      expect(res.body[0].address).toBe(assignedUsdtAddress);
    });
  });

  describe('2. Deposit Webhook: First Detection (Rate Lock Guarantee)', () => {
    it('POST /api/v1/wallets/webhook - detects 100 USDT deposit (1/3 confirms) and locks rate', async () => {
      const initialBalance = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(initialBalance.availableMinor).toBe('0');

      const res = await request(app.getHttpServer())
        .post('/api/v1/wallets/webhook')
        .set('x-webhook-signature', 'sandbox-test-valid-sig')
        .send({
          txHash: testTxHash,
          address: assignedUsdtAddress,
          asset: CryptoAsset.USDT,
          network: BlockchainNetwork.TRON_TRC20,
          amountMinor: '100000000', // 100 USDT (6 decimals)
          confirmations: 1, // 1 confirmation (below 3 required)
        })
        .expect(200);

      expect(res.body.txHash).toBe(testTxHash);
      expect(res.body.status).toBe('DETECTED');
      expect(res.body.confirmations).toBe(1);
      expect(res.body.lockedRate).toBeDefined();

      // Ensure ledger is NOT credited before required confirmations are reached
      const balanceAfterDetection = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(balanceAfterDetection.availableMinor).toBe('0');
    });
  });

  describe('3. Deposit Webhook: Confirmation & Automatic Ledger Settlement', () => {
    it('POST /api/v1/wallets/webhook - reaches 3/3 confirmations and credits ledger in NGN kobo', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/wallets/webhook')
        .set('x-webhook-signature', 'sandbox-test-valid-sig')
        .send({
          txHash: testTxHash,
          address: assignedUsdtAddress,
          asset: CryptoAsset.USDT,
          network: BlockchainNetwork.TRON_TRC20,
          amountMinor: '100000000', // 100 USDT
          confirmations: 3, // Final confirmation!
        })
        .expect(200);

      expect(res.body.status).toBe('PROCESSED');
      expect(res.body.confirmations).toBe(3);

      // Verify that the double-entry ledger is now credited!
      const balanceAfterConfirmation = await ledgerService.getUserBalances(testUserId, 'NGN');
      expect(BigInt(balanceAfterConfirmation.availableMinor)).toBeGreaterThan(BigInt(0));
      
      const depositRecord = await prisma.deposit.findUnique({ where: { txHash: testTxHash } });
      const expectedKobo = BigInt(Math.floor((100000000 * Number(depositRecord!.lockedRate)) / 10000)).toString();
      expect(balanceAfterConfirmation.availableMinor).toBe(expectedKobo);
    });

    it('Idempotency: Replaying the confirmed deposit webhook does NOT double-credit', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/wallets/webhook')
        .set('x-webhook-signature', 'sandbox-test-valid-sig')
        .send({
          txHash: testTxHash,
          address: assignedUsdtAddress,
          asset: CryptoAsset.USDT,
          network: BlockchainNetwork.TRON_TRC20,
          amountMinor: '100000000',
          confirmations: 3,
        })
        .expect(200);

      const balance = await ledgerService.getUserBalances(testUserId, 'NGN');
      const depositRecord = await prisma.deposit.findUnique({ where: { txHash: testTxHash } });
      const expectedKobo = BigInt(Math.floor((100000000 * Number(depositRecord!.lockedRate)) / 10000)).toString();
      // Balance remains strictly identical (no double credit)
      expect(balance.availableMinor).toBe(expectedKobo);
    });
  });

  describe('4. User Deposit Query Endpoints', () => {
    it('GET /api/v1/wallets/deposits - should return deposit history', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/wallets/deposits')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].txHash).toBe(testTxHash);
      expect(res.body[0].status).toBe('PROCESSED');
    });

    it('GET /api/v1/wallets/deposits/:txHash - should return single deposit tracking detail', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/wallets/deposits/${testTxHash}`)
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(res.body.txHash).toBe(testTxHash);
      expect(res.body.amountMinor).toBe('100000000');
    });
  });
});
