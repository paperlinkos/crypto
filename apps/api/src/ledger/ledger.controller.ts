import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { LedgerService } from './ledger.service';
import { LedgerTransactionDto, CreateAccountDto } from './dto/ledger.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '@prisma/client';

@ApiTags('Double-Entry Ledger')
@Controller('ledger')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class LedgerController {
  constructor(private ledgerService: LedgerService) {}

  @Get('balances')
  @ApiOperation({ summary: 'Get current user available, held, and total balances' })
  @ApiQuery({ name: 'currency', required: false, example: 'NGN' })
  async getMyBalances(
    @CurrentUser('userId') userId: string,
    @Query('currency') currency = 'NGN',
  ) {
    return await this.ledgerService.getUserBalances(userId, currency);
  }

  @Post('credit')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Credit user account with balanced double-entry journal (Admin only)' })
  async creditUser(
    @Query('userId') userId: string,
    @Body() dto: LedgerTransactionDto,
  ) {
    const amountMinor = BigInt(dto.amountMinor);
    return await this.ledgerService.credit(
      userId,
      amountMinor,
      dto.currency,
      dto.idempotencyRef,
      dto.description || 'Admin manual credit',
    );
  }

  @Post('debit')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Debit user account with balanced double-entry journal (Admin only)' })
  async debitUser(
    @Query('userId') userId: string,
    @Body() dto: LedgerTransactionDto,
  ) {
    const amountMinor = BigInt(dto.amountMinor);
    return await this.ledgerService.debit(
      userId,
      amountMinor,
      dto.currency,
      dto.idempotencyRef,
      dto.description || 'Admin manual debit',
    );
  }

  @Post('hold')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reserve available user funds into held liability' })
  async holdFunds(
    @CurrentUser('userId') userId: string,
    @Body() dto: LedgerTransactionDto,
  ) {
    const amountMinor = BigInt(dto.amountMinor);
    return await this.ledgerService.hold(
      userId,
      amountMinor,
      dto.currency,
      dto.idempotencyRef,
      dto.description || 'Payout reserve hold',
    );
  }

  @Post('release')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Release held funds back to available balance' })
  async releaseFunds(
    @CurrentUser('userId') userId: string,
    @Body() dto: LedgerTransactionDto,
  ) {
    const amountMinor = BigInt(dto.amountMinor);
    return await this.ledgerService.release(
      userId,
      amountMinor,
      dto.currency,
      dto.idempotencyRef,
      dto.description || 'Release held funds',
    );
  }
}
