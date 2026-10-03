import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { AuthService } from '../src/auth/auth.service';
import { KycService } from '../src/kyc/kyc.service';
import { KycTier, KycStatus } from '@prisma/client';

describe('KYC & Tiered Compliance Engine (E2E)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let authService: AuthService;
  let kycService: KycService;

  let testUserId: string;
  let userAccessToken: string;
  let adminAccessToken: string;
  let userKycProfileId: string;

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
    kycService = app.get(KycService);

    // Create a new user starting at Tier 0
    const testEmail = `kyc_tester_${Date.now()}@offramp.test`;
    const otpRes = await authService.requestOtp({ recipient: testEmail, purpose: 'SIGNUP' });
    const signupRes = await authService.signup(
      {
        recipient: testEmail,
        code: otpRes.sandboxCode || '123456',
        password: 'Password123!',
      },
      { fingerprint: 'kyc-tester-device' },
    );

    testUserId = signupRes.user.id;
    userAccessToken = signupRes.accessToken;

    const profile = await prisma.kycProfile.findUnique({ where: { userId: testUserId } });
    userKycProfileId = profile!.id;

    // Login admin
    const adminRes = await authService.adminLogin({
      email: 'admin@offramp.test',
      password: 'AdminPassword123!',
    });
    adminAccessToken = adminRes.accessToken;
  });

  afterAll(async () => {
    if (testUserId) {
      await prisma.kycProfile.deleteMany({ where: { userId: testUserId } });
      await prisma.user.deleteMany({ where: { id: testUserId } });
    }
    await app.close();
  });

  describe('1. Initial Tier 0 Status', () => {
    it('GET /api/v1/kyc/status - should show Tier 0 with unverified status', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/kyc/status')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .expect(200);

      expect(res.body.tier).toBe('TIER_0');
      expect(res.body.status).toBe('NOT_SUBMITTED');
    });
  });

  describe('2. Tier 1 BVN Verification', () => {
    it('POST /api/v1/kyc/tier1 - should reject invalid/failing BVN (999...)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/kyc/tier1')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          idNumber: '99912345678',
          idType: 'BVN',
          firstName: 'Chukwudi',
          lastName: 'Okonkwo',
        })
        .expect(400);
    });

    it('POST /api/v1/kyc/tier1 - should verify valid BVN and upgrade to Tier 1 (₦500k daily limit)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/kyc/tier1')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          idNumber: '22334455667',
          idType: 'BVN',
          firstName: 'Chukwudi',
          lastName: 'Okonkwo',
        })
        .expect(200);

      expect(res.body.tier).toBe('TIER_1');
      expect(res.body.status).toBe('APPROVED');
      expect(res.body.verifiedName).toBe('CHUKWUDI OKONKWO');
      expect(res.body.dailyLimitMinor).toBe('50000000'); // ₦500k in kobo
      expect(res.body.singleTxLimitMinor).toBe('10000000'); // ₦100k in kobo
    });
  });

  describe('3. Tier 2 Biometrics & Government ID', () => {
    it('POST /api/v1/kyc/tier2 - should verify ID & face liveness, upgrading to Tier 2 (₦5M limit)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/kyc/tier2')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          idType: 'PASSPORT',
          idNumber: 'A98765432',
          selfieBase64: 'data:image/jpeg;base64,/9j/4AAQSkZJRg...',
        })
        .expect(200);

      expect(res.body.tier).toBe('TIER_2');
      expect(res.body.status).toBe('APPROVED');
      expect(res.body.dailyLimitMinor).toBe('500000000'); // ₦5M in kobo
      expect(res.body.singleTxLimitMinor).toBe('100000000'); // ₦1M in kobo
    });
  });

  describe('4. Tier 3 Proof of Address & Admin Review Queue', () => {
    it('POST /api/v1/kyc/tier3 - should submit Proof of Address for compliance review', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/kyc/tier3')
        .set('Authorization', `Bearer ${userAccessToken}`)
        .send({
          residentialAddress: 'Plot 10, Victoria Island',
          city: 'Lagos',
          state: 'Lagos',
          utilityDocType: 'ELECTRICITY_BILL',
        })
        .expect(200);

      expect(res.body.status).toBe('PENDING');
    });

    it('GET /api/v1/kyc/admin/queue - admin should see pending submission in compliance queue', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/kyc/admin/queue')
        .set('Authorization', `Bearer ${adminAccessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      const target = res.body.find((p: any) => p.userId === testUserId);
      expect(target).toBeDefined();
      expect(target.status).toBe('PENDING');
    });

    it('PATCH /api/v1/kyc/admin/review/:profileId - admin approves Tier 3 (₦50M limit)', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/kyc/admin/review/${userKycProfileId}`)
        .set('Authorization', `Bearer ${adminAccessToken}`)
        .send({
          status: KycStatus.APPROVED,
        })
        .expect(200);

      expect(res.body.tier).toBe('TIER_3');
      expect(res.body.status).toBe('APPROVED');
      expect(res.body.dailyLimitMinor).toBe('5000000000'); // ₦50M in kobo
    });
  });

  describe('5. Payout Limit Enforcement Logic', () => {
    it('Should allow payout within single transaction and daily limit', async () => {
      // ₦2M payout (within Tier 3 single limit of ₦10M and daily limit of ₦50M)
      const check = await kycService.enforcePayoutLimits(testUserId, BigInt(200000000));
      expect(check.allowed).toBe(true);
    });

    it('Should reject payout exceeding single transaction limit', async () => {
      // ₦15M payout (exceeds Tier 3 single tx limit of ₦10M)
      await expect(
        kycService.enforcePayoutLimits(testUserId, BigInt(1500000000)),
      ).rejects.toThrow('exceeds your maximum per-transaction limit');
    });
  });
});
