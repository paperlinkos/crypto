import { Module } from '@nestjs/common';
import { KycService } from './kyc.service';
import { KycController } from './kyc.controller';
import { SandboxKycProvider } from './adapters/sandbox-kyc.provider';
import { ProductionKycProvider } from './adapters/smile-identity-or-dojah-kyc.provider';

@Module({
  controllers: [KycController],
  providers: [
    KycService,
    SandboxKycProvider,
    ProductionKycProvider,
  ],
  exports: [KycService, SandboxKycProvider],
})
export class KycModule {}
