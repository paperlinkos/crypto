import { Module } from '@nestjs/common';
import { WalletsService } from './wallets.service';
import { WalletsController } from './wallets.controller';
import { SandboxWalletProvider } from './adapters/sandbox-wallet.provider';
import { ProductionWalletProvider } from './adapters/yellowcard-or-fireblocks-wallet.provider';
import { LedgerModule } from '../ledger/ledger.module';

@Module({
  imports: [LedgerModule],
  controllers: [WalletsController],
  providers: [
    WalletsService,
    SandboxWalletProvider,
    ProductionWalletProvider,
  ],
  exports: [WalletsService, SandboxWalletProvider],
})
export class WalletsModule {}
