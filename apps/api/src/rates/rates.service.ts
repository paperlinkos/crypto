import {
  Injectable,
  ServiceUnavailableException,
  BadRequestException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { SandboxRateProvider } from './adapters/sandbox-rate.provider';
import { CryptoAsset, FiatCurrency } from '@prisma/client';
import { MoneyUtil } from '@offramp/shared';
import { v4 as uuidv4 } from 'uuid';

export interface RateQuoteResponse {
  quoteId: string;
  asset: CryptoAsset;
  fiat: FiatCurrency;
  cryptoAmount: string;
  baseSpotRate: string;
  spreadPercent: string;
  effectiveRate: string;
  grossFiatAmount: string;
  spreadFeeFiat: string;
  netPayoutFiat: string;
  netPayoutMinor: string;
  validForSeconds: number;
  expiresAt: string;
  isStale: boolean;
}

@Injectable()
export class RatesService implements OnModuleInit {
  private readonly logger = new Logger(RatesService.name);
  private readonly STALE_THRESHOLD_SECONDS = 90; // Stale rate cutoff per Rule #5

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private configService: ConfigService,
    private rateProvider: SandboxRateProvider,
  ) {}

  async onModuleInit() {
    await this.refreshRates();
  }

  /**
   * Retrieves configured spread percentage for an asset.
   */
  async getSpreadPercent(asset: CryptoAsset): Promise<number> {
    const cached = await this.redis.get(`rate_spread:${asset}`);
    if (cached) {
      return parseFloat(cached);
    }
    const defaultSpread = this.configService.get<number>('DEFAULT_SPREAD_PERCENTAGE') || 1.5;
    return defaultSpread;
  }

  /**
   * Updates spread percentage for an asset (Admin operation).
   */
  async updateSpread(asset: CryptoAsset, spreadPercent: number, adminId?: string) {
    if (spreadPercent < 0 || spreadPercent > 20) {
      throw new BadRequestException('Spread percentage must be between 0% and 20%');
    }

    await this.redis.set(`rate_spread:${asset}`, spreadPercent.toString());
    await this.refreshRates();

    if (adminId) {
      await this.prisma.auditLog.create({
        data: {
          actorType: 'ADMIN',
          actorId: adminId,
          action: 'SPREAD_UPDATED',
          entityType: 'RATE',
          newState: { asset, spreadPercent },
        },
      });
    }

    return { message: `Spread for ${asset} updated to ${spreadPercent}%`, asset, spreadPercent };
  }

  /**
   * Fetches latest spot prices, applies spread, caches in Redis, and stores DB snapshot.
   */
  async refreshRates() {
    const spotRates = await this.rateProvider.getAllSpotRates();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 15 * 60 * 1000); // 15 mins snapshot

    for (const item of spotRates) {
      const spreadPercent = await this.getSpreadPercent(item.asset);
      const effectiveRate = item.spotRate * (1 - spreadPercent / 100);

      const ratePayload = {
        asset: item.asset,
        fiat: item.fiat,
        baseSpotRate: item.spotRate,
        spreadPercent,
        effectiveRate,
        source: item.source,
        timestamp: item.timestamp.toISOString(),
      };

      // Cache live price in Redis (30-sec TTL)
      await this.redis.set(`rate_live:${item.asset}:${item.fiat}`, JSON.stringify(ratePayload), 30);

      // Persist snapshot to database
      await this.prisma.rate.create({
        data: {
          asset: item.asset,
          fiat: item.fiat,
          baseSpotRate: item.spotRate,
          spreadPercent,
          effectiveRate,
          source: item.source,
          expiresAt,
        },
      });
    }

    this.logger.log(' Exchange rates refreshed and cached in Redis');
  }

  /**
   * Lists all live exchange rates and spreads for a target fiat currency.
   */
  async getLiveRates(fiat: FiatCurrency = FiatCurrency.NGN) {
    const assets = [CryptoAsset.USDT, CryptoAsset.USDC, CryptoAsset.BTC, CryptoAsset.ETH];
    const results = [];

    for (const asset of assets) {
      const rateInfo = await this.getLatestRateForPair(asset, fiat);
      results.push(rateInfo);
    }

    return results;
  }

  /**
   * Generates a guaranteed rate quote with transparent fee and payout breakdown.
   */
  async getQuote(
    asset: CryptoAsset,
    amountStr: string,
    fiat: FiatCurrency = FiatCurrency.NGN,
  ): Promise<RateQuoteResponse> {
    const amountNum = parseFloat(amountStr);
    if (isNaN(amountNum) || amountNum <= 0) {
      throw new BadRequestException('Amount must be a positive number');
    }

    const rateInfo = await this.getLatestRateForPair(asset, fiat);

    // Stale Rate Protection: refuse quote if feed is stale
    if (rateInfo.isStale) {
      throw new ServiceUnavailableException(
        `Exchange rate feed for ${asset}/${fiat} is currently stale. Quotes temporarily disabled for price protection.`,
      );
    }

    const baseSpotRate = rateInfo.baseSpotRate;
    const spreadPercent = rateInfo.spreadPercent;
    const effectiveRate = rateInfo.effectiveRate;

    // Gross fiat value
    const grossFiat = amountNum * baseSpotRate;
    // Spread fee deducted
    const spreadFee = grossFiat * (spreadPercent / 100);
    // Net fiat payout
    const netPayout = amountNum * effectiveRate;

    // Convert net payout to integer minor units (kobo/pesewas)
    const fiatDecimals = MoneyUtil.getDecimals(fiat);
    const netPayoutMinor = MoneyUtil.toMinorUnit(netPayout.toFixed(fiatDecimals), fiatDecimals);

    const quoteId = `QUOTE-${uuidv4()}`;
    const validForSeconds = 900; // 15 minutes guaranteed rate
    const expiresAt = new Date(Date.now() + validForSeconds * 1000).toISOString();

    const quoteResponse: RateQuoteResponse = {
      quoteId,
      asset,
      fiat,
      cryptoAmount: amountNum.toString(),
      baseSpotRate: baseSpotRate.toFixed(4),
      spreadPercent: `${spreadPercent}%`,
      effectiveRate: effectiveRate.toFixed(4),
      grossFiatAmount: grossFiat.toFixed(fiatDecimals),
      spreadFeeFiat: spreadFee.toFixed(fiatDecimals),
      netPayoutFiat: netPayout.toFixed(fiatDecimals),
      netPayoutMinor: netPayoutMinor.toString(),
      validForSeconds,
      expiresAt,
      isStale: false,
    };

    // Cache quote in Redis for validation during deposit/off-ramp execution
    await this.redis.set(`quote:${quoteId}`, JSON.stringify(quoteResponse), validForSeconds);

    return quoteResponse;
  }

  /**
   * Helper: fetches latest rate with stale-rate detection.
   */
  private async getLatestRateForPair(asset: CryptoAsset, fiat: FiatCurrency) {
    // 1. Check Redis cache first
    const cached = await this.redis.get(`rate_live:${asset}:${fiat}`);
    if (cached) {
      const data = JSON.parse(cached);
      return {
        asset,
        fiat,
        baseSpotRate: data.baseSpotRate,
        spreadPercent: data.spreadPercent,
        effectiveRate: data.effectiveRate,
        source: data.source,
        timestamp: data.timestamp,
        isStale: false,
      };
    }

    // 2. Query DB if Redis cache missed
    const latestDb = await this.prisma.rate.findFirst({
      where: { asset, fiat },
      orderBy: { createdAt: 'desc' },
    });

    if (!latestDb) {
      // Re-trigger refresh if no rates in DB
      await this.refreshRates();
      return await this.getLatestRateForPair(asset, fiat);
    }

    const ageSeconds = (Date.now() - latestDb.createdAt.getTime()) / 1000;
    const isStale = ageSeconds > this.STALE_THRESHOLD_SECONDS;

    return {
      asset,
      fiat,
      baseSpotRate: Number(latestDb.baseSpotRate),
      spreadPercent: Number(latestDb.spreadPercent),
      effectiveRate: Number(latestDb.effectiveRate),
      source: latestDb.source,
      timestamp: latestDb.createdAt.toISOString(),
      isStale,
    };
  }
}
