import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Headers,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { Request } from 'express';
import { WalletsService } from './wallets.service';
import { AssignWalletDto, DepositWebhookDto, WithdrawCryptoDto } from './dto/wallets.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '@prisma/client';

@ApiTags('Wallets & Deposit Detection')
@Controller('wallets')
export class WalletsController {
  constructor(private walletsService: WalletsService) {}

  @Post('withdraw')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Withdraw crypto on-chain to external wallet address' })
  async withdrawCrypto(
    @CurrentUser('userId') userId: string,
    @Body() dto: WithdrawCryptoDto,
  ) {
    return await this.walletsService.withdrawCrypto(userId, dto);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List user deposit addresses with QR code data URLs' })
  async getMyWallets(@CurrentUser('userId') userId: string) {
    return await this.walletsService.getUserWallets(userId);
  }

  @Post('assign')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Generate or assign dedicated deposit address for asset & network' })
  async assignWallet(
    @CurrentUser('userId') userId: string,
    @Body() dto: AssignWalletDto,
  ) {
    return await this.walletsService.getOrCreateUserWallet(userId, dto.asset, dto.network);
  }

  @Get('deposits')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List user deposit history and confirmation statuses' })
  async getMyDeposits(@CurrentUser('userId') userId: string) {
    return await this.walletsService.getUserDeposits(userId);
  }

  @Get('deposits/:txHash')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get single deposit status, locked rate, and confirmations' })
  async getDepositDetail(@Param('txHash') txHash: string) {
    return await this.walletsService.getDepositByTxHash(txHash);
  }

  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Deposit webhook listener for blockchain custody provider' })
  async handleDepositWebhook(
    @Body() payload: DepositWebhookDto,
    @Headers() headers: Record<string, any>,
    @Req() req: Request,
  ) {
    const rawBody = (req as any).rawBody || JSON.stringify(payload);
    return await this.walletsService.handleDepositWebhook(payload, headers, rawBody);
  }

  @Post('simulate-deposit')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Simulate a blockchain deposit event (Sandbox/Admin testing tool)' })
  async simulateDeposit(@Body() payload: DepositWebhookDto) {
    return await this.walletsService.handleDepositWebhook(payload, {
      'x-webhook-signature': 'sandbox-test-valid-sig',
    });
  }
}
