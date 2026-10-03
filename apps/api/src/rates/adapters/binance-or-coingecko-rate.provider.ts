import { Injectable, NotImplementedException } from '@nestjs/common';
import { IRateProvider, SpotRateResult } from '../interfaces/rate-provider.interface';
import { CryptoAsset, FiatCurrency } from '@prisma/client';

/**
 * Production Market Rate Provider
 *
 * Supported Feeds:
 * 1. Binance P2P API (NGN & GHS Merchant orderbook averages): https://binance-docs.github.io/apidocs/p2p/en/
 * 2. CoinGecko Pro API: https://docs.coingecko.com/reference/simple-price
 * 3. Yellow Card Exchange Rate Feed: https://docs.yellowcard.io/docs/exchange-rates
 */
@Injectable()
export class ProductionRateProvider implements IRateProvider {
  async getSpotRate(asset: CryptoAsset, fiat: FiatCurrency): Promise<SpotRateResult> {
    // TODO: Connect live WebSocket / REST feed from Binance P2P or CoinGecko Pro
    throw new NotImplementedException(
      'ProductionRateProvider: Live API keys not configured. Switch RATE_PROVIDER_MODE=sandbox in development.',
    );
  }

  async getAllSpotRates(): Promise<SpotRateResult[]> {
    throw new NotImplementedException(
      'ProductionRateProvider: Live API keys not configured.',
    );
  }
}
