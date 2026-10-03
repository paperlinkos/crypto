import { Module } from '@nestjs/common';
import { PayoutsController } from './payouts.controller';
import { PayoutsService } from './payouts.service';
import { SandboxPayoutProvider } from './adapters/sandbox-payout.provider';
import { ProductionPayoutProvider } from './adapters/paystack-or-monnify-payout.provider';
import { LedgerModule } from '../ledger/ledger.module';
import { KycModule } from '../kyc/kyc.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [LedgerModule, KycModule, AuthModule],
  controllers: [PayoutsController],
  providers: [
    PayoutsService,
    SandboxPayoutProvider,
    ProductionPayoutProvider,
  ],
  exports: [PayoutsService, SandboxPayoutProvider],
})
export class PayoutsModule {}
