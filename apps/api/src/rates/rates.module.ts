import { Module } from '@nestjs/common';
import { RatesService } from './rates.service';
import { RatesController } from './rates.controller';
import { SandboxRateProvider } from './adapters/sandbox-rate.provider';
import { ProductionRateProvider } from './adapters/binance-or-coingecko-rate.provider';

@Module({
  controllers: [RatesController],
  providers: [
    RatesService,
    SandboxRateProvider,
    ProductionRateProvider,
  ],
  exports: [RatesService, SandboxRateProvider],
})
export class RatesModule {}
