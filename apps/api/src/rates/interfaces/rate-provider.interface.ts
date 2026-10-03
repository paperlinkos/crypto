import { CryptoAsset, FiatCurrency } from '@prisma/client';

export interface SpotRateResult {
  asset: CryptoAsset;
  fiat: FiatCurrency;
  spotRate: number;
  source: string;
  timestamp: Date;
}

export interface IRateProvider {
  /**
   * Fetches the current spot exchange price for a single crypto-fiat pair.
   */
  getSpotRate(asset: CryptoAsset, fiat: FiatCurrency): Promise<SpotRateResult>;

  /**
   * Fetches spot prices for all supported crypto-fiat pairs.
   */
  getAllSpotRates(): Promise<SpotRateResult[]>;
}
