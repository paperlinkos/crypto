import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

describe('Auth & Security (E2E)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let redis: RedisService;

  let accessToken: string;
  let refreshToken: string;
  let testUserId: string;

  const testEmail = `testuser_${Date.now()}@offramp.test`;
  const testPassword = 'StrongPassword123!';

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

    await app.init();

    prisma = app.get(PrismaService);
    redis = app.get(RedisService);
  });

  afterAll(async () => {
    // Cleanup created test user
    if (testUserId) {
      await prisma.user.deleteMany({ where: { id: testUserId } });
    }
    await app.close();
  });

  describe('1. OTP & Registration Flow', () => {
    let sandboxOtp: string;

    it('POST /api/v1/auth/otp/request - should generate and send OTP', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/otp/request')
        .send({
          recipient: testEmail,
          purpose: 'SIGNUP',
        })
        .expect(200);

      expect(res.body.message).toContain('Verification code sent');
      expect(res.body.sandboxCode).toBeDefined();
      sandboxOtp = res.body.sandboxCode;
    });

    it('POST /api/v1/auth/signup - should fail with wrong OTP', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/signup')
        .send({
          recipient: testEmail,
          code: '000000',
          password: testPassword,
        })
        .expect(400);
    });

    it('POST /api/v1/auth/signup - should register user and issue token pair', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/signup')
        .send({
          recipient: testEmail,
          code: sandboxOtp,
          password: testPassword,
          deviceFingerprint: 'test-device-uuid-001',
          deviceName: 'Jest Test Runner',
          os: 'macOS',
        })
        .expect(201);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user.email).toBe(testEmail);
      expect(res.body.user.status).toBe('ACTIVE');

      accessToken = res.body.accessToken;
      refreshToken = res.body.refreshToken;
      testUserId = res.body.user.id;
    });
  });

  describe('2. User Login & Token Refresh Flow', () => {
    it('POST /api/v1/auth/login - should authenticate with valid credentials', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          identifier: testEmail,
          password: testPassword,
          deviceFingerprint: 'test-device-uuid-001',
        })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
    });

    it('POST /api/v1/auth/login - should reject incorrect password', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          identifier: testEmail,
          password: 'WrongPassword!',
        })
        .expect(401);
    });

    it('POST /api/v1/auth/refresh - should rotate refresh token', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({
          refreshToken,
        })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();

      // Update tokens
      accessToken = res.body.accessToken;
      refreshToken = res.body.refreshToken;
    });
  });

  describe('3. Authenticated Profile & Device Tracking', () => {
    it('GET /api/v1/auth/me - should return user profile and KYC limits', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.id).toBe(testUserId);
      expect(res.body.email).toBe(testEmail);
      expect(res.body.kyc).toBeDefined();
      expect(res.body.kyc.tier).toBe('TIER_0');
    });

    it('GET /api/v1/auth/devices - should list registered active devices', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/auth/devices')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);
      expect(res.body[0].deviceFingerprint).toBe('test-device-uuid-001');
    });
  });

  describe('4. Transaction PIN & Lockout Protection', () => {
    it('POST /api/v1/auth/pin/set - should set 4-digit transaction PIN', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/pin/set')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ pin: '4321' })
        .expect(200);

      expect(res.body.message).toContain('successfully set');
    });

    it('POST /api/v1/auth/pin/verify - should successfully verify correct PIN', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/pin/verify')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ pin: '4321' })
        .expect(200);

      expect(res.body.valid).toBe(true);
    });

    it('POST /api/v1/auth/pin/verify - should fail on incorrect PIN and track attempts', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/pin/verify')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ pin: '0000' })
        .expect(400);

      expect(res.body.message).toContain('attempt(s) remaining');
    });

    it('PIN Lockout - should lock PIN after 5 consecutive failed attempts', async () => {
      // Send 4 more failed attempts (1 already sent above)
      for (let i = 0; i < 3; i++) {
        await request(app.getHttpServer())
          .post('/api/v1/auth/pin/verify')
          .set('Authorization', `Bearer ${accessToken}`)
          .send({ pin: '0000' })
          .expect(400);
      }

      // 5th failed attempt triggers 403 Forbidden Lockout
      const lockoutRes = await request(app.getHttpServer())
        .post('/api/v1/auth/pin/verify')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ pin: '0000' })
        .expect(403);

      expect(lockoutRes.body.message).toContain('locked for 30 minutes');

      // Even correct PIN is now refused during lockout
      const subsequentRes = await request(app.getHttpServer())
        .post('/api/v1/auth/pin/verify')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ pin: '4321' })
        .expect(403);

      expect(subsequentRes.body.message).toContain('is locked');
    });
  });

  describe('5. Two-Factor Authentication (2FA TOTP)', () => {
    let totpSecret: string;

    it('POST /api/v1/auth/2fa/generate - should generate TOTP secret and QR code URI', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/2fa/generate')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(201);

      expect(res.body.secret).toBeDefined();
      expect(res.body.qrCodeDataUrl).toContain('data:image/png;base64');
      totpSecret = res.body.secret;
    });

    it('POST /api/v1/auth/2fa/enable - should enable 2FA with valid token', async () => {
      const { authenticator } = await import('otplib');
      const validCode = authenticator.generate(totpSecret);

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/2fa/enable')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ code: validCode })
        .expect(200);

      expect(res.body.message).toContain('successfully enabled');
    });

    it('POST /api/v1/auth/2fa/disable - should disable 2FA with valid token', async () => {
      const { authenticator } = await import('otplib');
      const validCode = authenticator.generate(totpSecret);

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/2fa/disable')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ code: validCode })
        .expect(200);

      expect(res.body.message).toContain('has been disabled');
    });
  });

  describe('6. Admin Authentication & Role Guards', () => {
    it('POST /api/v1/auth/admin/login - should authenticate seeded admin user', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/admin/login')
        .send({
          email: 'admin@offramp.test',
          password: 'AdminPassword123!',
        })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.admin.role).toBe('SUPER_ADMIN');
    });
  });
});
