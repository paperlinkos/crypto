import { Injectable, Logger } from '@nestjs/common';
import { IRateProvider, SpotRateResult } from '../interfaces/rate-provider.interface';
import { CryptoAsset, FiatCurrency } from '@prisma/client';

@Injectable()
export class SandboxRateProvider implements IRateProvider {
  private readonly logger = new Logger(SandboxRateProvider.name);

  // Baseline market spot rates for Nigeria (NGN) & Ghana (GHS)
  private readonly baseRates: Record<string, number> = {
    'USDT:NGN': 1545.0,
    'USDC:NGN': 1545.0,
    'BTC:NGN': 104500000.0,
    'ETH:NGN': 4250000.0,
    'USDT:GHS': 15.8,
    'USDC:GHS': 15.8,
    'BTC:GHS': 1070000.0,
    'ETH:GHS': 43500.0,
  };

  async getSpotRate(asset: CryptoAsset, fiat: FiatCurrency): Promise<SpotRateResult> {
    const key = `${asset}:${fiat}`;
    const spotRate = this.baseRates[key] || 1500.0;

    return {
      asset,
      fiat,
      spotRate,
      source: 'SANDBOX_FEED',
      timestamp: new Date(),
    };
  }

  async getAllSpotRates(): Promise<SpotRateResult[]> {
    const results: SpotRateResult[] = [];
    const now = new Date();

    for (const [pair, spotRate] of Object.entries(this.baseRates)) {
      const [assetStr, fiatStr] = pair.split(':');
      results.push({
        asset: assetStr as CryptoAsset,
        fiat: fiatStr as FiatCurrency,
        spotRate,
        source: 'SANDBOX_FEED',
        timestamp: now,
      });
    }

    return results;
  }
}
