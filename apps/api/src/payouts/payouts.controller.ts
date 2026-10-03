import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Headers,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiHeader } from '@nestjs/swagger';
import { PayoutsService } from './payouts.service';
import {
  AddBankAccountDto,
  InitiateWithdrawalDto,
  PayoutWebhookDto,
  ResolveAccountDto,
  UpdateAutoPayoutDto,
} from './dto/payouts.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { FiatCurrency, UserRole } from '@prisma/client';

@ApiTags('Bank Accounts & Off-Ramp Payouts')
@Controller('payouts')
export class PayoutsController {
  constructor(private payoutsService: PayoutsService) {}

  @Get('banks')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List supported commercial banks and mobile money operators' })
  async listBanks(@Query('currency') currency?: FiatCurrency) {
    return await this.payoutsService.listBanks(currency || FiatCurrency.NGN);
  }

  @Post('resolve-account')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'NUBAN bank account name enquiry resolution' })
  async resolveAccount(@Body() dto: ResolveAccountDto) {
    return await this.payoutsService.resolveAccount(dto.accountNumber, dto.bankCode);
  }

  @Post('bank-accounts')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Add a verified bank account to user profile' })
  async addBankAccount(
    @CurrentUser('userId') userId: string,
    @Body() dto: AddBankAccountDto,
  ) {
    return await this.payoutsService.addBankAccount(userId, dto);
  }

  @Get('bank-accounts')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List user saved bank accounts' })
  async getBankAccounts(@CurrentUser('userId') userId: string) {
    return await this.payoutsService.getUserBankAccounts(userId);
  }

  @Delete('bank-accounts/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a saved bank account' })
  async deleteBankAccount(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return await this.payoutsService.deleteBankAccount(userId, id);
  }

  @Post('withdraw')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Initiate off-ramp fiat payout to bank account (PIN protected)' })
  async withdraw(
    @CurrentUser('userId') userId: string,
    @Body() dto: InitiateWithdrawalDto,
  ) {
    return await this.payoutsService.initiateWithdrawal(userId, dto);
  }

  @Patch('auto-settlement')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Toggle automated off-ramp settlement on crypto deposit arrival' })
  async toggleAutoPayout(
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateAutoPayoutDto,
  ) {
    return await this.payoutsService.updateAutoPayoutToggle(userId, dto.autoPayout);
  }

  @Get('history')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get payout history for current user' })
  async getPayoutHistory(@CurrentUser('userId') userId: string) {
    return await this.payoutsService.getUserPayouts(userId);
  }

  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Payout provider asynchronous webhook handler' })
  @ApiHeader({ name: 'x-payout-signature', description: 'HMAC signature for webhook verification' })
  async handleWebhook(
    @Body() payload: PayoutWebhookDto,
    @Headers() headers: Record<string, string>,
  ) {
    return await this.payoutsService.handlePayoutWebhook(payload, headers);
  }

  @Post('reconcile')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Trigger manual or scheduled payout reconciliation (Admin only)' })
  async reconcilePendingPayouts() {
    return await this.payoutsService.reconcilePendingPayouts();
  }
}
