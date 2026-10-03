import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Length,
  Matches,
  ValidateNested,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { FiatCurrency } from '@prisma/client';

export class ResolveAccountDto {
  @ApiProperty({ example: '0123456789', description: '10-digit NUBAN account number' })
  @IsString()
  @Length(10, 10)
  @Matches(/^\d{10}$/)
  accountNumber: string;

  @ApiProperty({ example: '058', description: 'Bank code (e.g. 058 for GTBank)' })
  @IsString()
  @IsNotEmpty()
  bankCode: string;
}

export class AddBankAccountDto {
  @ApiProperty({ example: '0123456789' })
  @IsString()
  @Length(10, 10)
  @Matches(/^\d{10}$/)
  accountNumber: string;

  @ApiProperty({ example: '058' })
  @IsString()
  @IsNotEmpty()
  bankCode: string;

  @ApiPropertyOptional({ default: false })
  @IsBoolean()
  @IsOptional()
  isDefault?: boolean;

  @ApiPropertyOptional({ enum: FiatCurrency, default: FiatCurrency.NGN })
  @IsEnum(FiatCurrency)
  @IsOptional()
  currency?: FiatCurrency;
}

export class InitiateWithdrawalDto {
  @ApiProperty({ example: 'bank-uuid-123' })
  @IsString()
  @IsNotEmpty()
  bankAccountId: string;

  @ApiProperty({ example: '5000000', description: 'Amount in integer minor units (5000000 kobo = ₦50,000)' })
  @IsString()
  @Matches(/^\d+$/)
  amountMinor: string;

  @ApiProperty({ example: '1234', description: '4-digit transaction PIN' })
  @IsString()
  @Length(4, 4)
  pin: string;

  @ApiProperty({ example: 'PAYOUT-20261003-001', description: 'Strictly unique idempotency key' })
  @IsString()
  @IsNotEmpty()
  idempotencyKey: string;

  @ApiPropertyOptional({ enum: FiatCurrency, default: FiatCurrency.NGN })
  @IsEnum(FiatCurrency)
  @IsOptional()
  currency?: FiatCurrency;

  @ApiPropertyOptional({ example: 'Crypto off-ramp payout' })
  @IsString()
  @IsOptional()
  narration?: string;
}

export class UpdateAutoPayoutDto {
  @ApiProperty({ example: true, description: 'Toggle auto-payout upon crypto deposit confirmation' })
  @IsBoolean()
  autoPayout: boolean;
}

export class PayoutWebhookDataDto {
  @ApiProperty({ example: 'TRF_SANDBOX_123456' })
  @IsString()
  @IsNotEmpty()
  reference: string;

  @ApiProperty({ example: 'SUCCESS' })
  @IsString()
  @IsNotEmpty()
  status: 'SUCCESS' | 'FAILED' | 'REVERSED';

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  amount?: number;
}

export class PayoutWebhookDto {
  @ApiProperty({ example: 'transfer.success' })
  @IsString()
  @IsNotEmpty()
  event: string;

  @ApiProperty({ type: PayoutWebhookDataDto })
  @IsObject()
  @ValidateNested()
  @Type(() => PayoutWebhookDataDto)
  data: PayoutWebhookDataDto;
}
