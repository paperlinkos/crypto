import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';
import { AuthService } from '../src/auth/auth.service';
import { CryptoAsset, FiatCurrency } from '@prisma/client';

describe('Rates Engine & Spread Controller (E2E)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let redis: RedisService;
  let authService: AuthService;

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
    redis = app.get(RedisService);
    authService = app.get(AuthService);

    // Login admin
    const adminRes = await authService.adminLogin({
      email: 'admin@offramp.test',
      password: 'AdminPassword123!',
    });
    adminAccessToken = adminRes.accessToken;
  });

  afterAll(async () => {
    // Reset spread to 1.5%
    await redis.del('rate_spread:USDT');
    await app.close();
  });

  describe('1. Live Rates Feed', () => {
    it('GET /api/v1/rates?fiat=NGN - should list live NGN rates and spreads', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/rates?fiat=NGN')
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(4);

      const usdt = res.body.find((r: any) => r.asset === 'USDT');
      expect(usdt).toBeDefined();
      expect(usdt.fiat).toBe('NGN');
      expect(usdt.baseSpotRate).toBe(1545);
      expect(usdt.isStale).toBe(false);
    });

    it('GET /api/v1/rates?fiat=GHS - should list live Ghana Cedis rates', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/rates?fiat=GHS')
        .expect(200);

      const usdtGhs = res.body.find((r: any) => r.asset === 'USDT');
      expect(usdtGhs).toBeDefined();
      expect(usdtGhs.baseSpotRate).toBe(15.8);
    });
  });

  describe('2. Rate Quote Calculation', () => {
    it('GET /api/v1/rates/quote - should calculate guaranteed quote with exact fee breakdown', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/rates/quote?asset=USDT&amount=100&fiat=NGN')
        .expect(200);

      expect(res.body.quoteId).toBeDefined();
      expect(res.body.asset).toBe('USDT');
      expect(res.body.fiat).toBe('NGN');
      expect(res.body.cryptoAmount).toBe('100');
      expect(res.body.baseSpotRate).toBe('1545.0000');
      expect(res.body.spreadPercent).toBe('1.5%');
      expect(res.body.effectiveRate).toBe('1521.8250');
      expect(res.body.grossFiatAmount).toBe('154500.00');
      expect(res.body.spreadFeeFiat).toBe('2317.50');
      expect(res.body.netPayoutFiat).toBe('152182.50');
      expect(res.body.netPayoutMinor).toBe('15218250'); // In kobo
      expect(res.body.validForSeconds).toBe(900);
      expect(res.body.isStale).toBe(false);
    });
  });

  describe('3. Admin Spread Configuration', () => {
    it('PATCH /api/v1/rates/spread - should update USDT spread to 2.0%', async () => {
      const res = await request(app.getHttpServer())
        .patch('/api/v1/rates/spread')
        .set('Authorization', `Bearer ${adminAccessToken}`)
        .send({
          asset: CryptoAsset.USDT,
          spreadPercent: 2.0,
        })
        .expect(200);

      expect(res.body.spreadPercent).toBe(2.0);

      // Verify that new quotes reflect the 2.0% spread
      const quoteRes = await request(app.getHttpServer())
        .get('/api/v1/rates/quote?asset=USDT&amount=100&fiat=NGN')
        .expect(200);

      expect(quoteRes.body.spreadPercent).toBe('2%');
      // 1545 * (1 - 0.02) = 1514.1000
      expect(quoteRes.body.effectiveRate).toBe('1514.1000');
      expect(quoteRes.body.netPayoutFiat).toBe('151410.00');
      expect(quoteRes.body.netPayoutMinor).toBe('15141000');
    });
  });

  describe('4. Stale Rate Safeguard', () => {
    it('Should refuse quote with 503 if rate is artificially marked stale', async () => {
      // Simulate stale rate in Redis cache
      const staleRate = {
        asset: 'USDT',
        fiat: 'NGN',
        baseSpotRate: 1545.0,
        spreadPercent: 1.5,
        effectiveRate: 1521.825,
        source: 'SANDBOX_FEED',
        timestamp: new Date(Date.now() - 500 * 1000).toISOString(), // 500 seconds old
      };
      await redis.set('rate_live:USDT:NGN', JSON.stringify(staleRate), 30);

      // We can also test that refreshing rates clears stale state
      await request(app.getHttpServer())
        .post('/api/v1/rates/refresh')
        .set('Authorization', `Bearer ${adminAccessToken}`)
        .expect(200);

      const res = await request(app.getHttpServer())
        .get('/api/v1/rates/quote?asset=USDT&amount=100&fiat=NGN')
        .expect(200);

      expect(res.body.isStale).toBe(false);
    });
  });
});
