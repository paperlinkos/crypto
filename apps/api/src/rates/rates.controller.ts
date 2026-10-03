import {
  Controller,
  Get,
  Patch,
  Post,
  Query,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { RatesService } from './rates.service';
import { GetQuoteQueryDto, UpdateSpreadDto } from './dto/rates.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole, FiatCurrency } from '@prisma/client';

@ApiTags('Rates Engine & Quotes')
@Controller('rates')
export class RatesController {
  constructor(private ratesService: RatesService) {}

  @Get()
  @ApiOperation({ summary: 'List live exchange rates and spreads for all supported crypto assets' })
  @ApiQuery({ name: 'fiat', enum: FiatCurrency, required: false, example: FiatCurrency.NGN })
  async getLiveRates(@Query('fiat') fiat = FiatCurrency.NGN) {
    return await this.ratesService.getLiveRates(fiat);
  }

  @Get('quote')
  @ApiOperation({ summary: 'Calculate a guaranteed rate quote and payout breakdown' })
  async getQuote(@Query() query: GetQuoteQueryDto) {
    return await this.ratesService.getQuote(
      query.asset,
      query.amount,
      query.fiat || FiatCurrency.NGN,
    );
  }

  @Patch('spread')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update spread percentage for an asset (Admin only)' })
  async updateSpread(
    @CurrentUser('userId') adminId: string,
    @Body() dto: UpdateSpreadDto,
  ) {
    return await this.ratesService.updateSpread(dto.asset, dto.spreadPercent, adminId);
  }

  @Post('refresh')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Force refresh rate feeds and cache (Admin only)' })
  async forceRefreshRates() {
    await this.ratesService.refreshRates();
    return { message: 'Rates successfully refreshed and cached' };
  }
}
