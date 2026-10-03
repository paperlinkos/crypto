import { IsNotEmpty, IsString, IsEnum, Matches, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { FiatCurrency, CryptoAsset, LedgerAccountType } from '@prisma/client';

export class CreateAccountDto {
  @ApiProperty({ example: '2010-USER-abc12345' })
  @IsString()
  @IsNotEmpty()
  accountNumber: string;

  @ApiProperty({ example: 'Customer NGN Fiat Liability' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ enum: LedgerAccountType, example: 'LIABILITY' })
  @IsEnum(LedgerAccountType)
  type: LedgerAccountType;

  @ApiProperty({ example: 'NGN' })
  @IsString()
  @IsNotEmpty()
  currency: string;

  @ApiPropertyOptional({ example: 'user-uuid-123' })
  @IsString()
  @IsOptional()
  userId?: string;
}

export class LedgerTransactionDto {
  @ApiProperty({ example: '500000', description: 'Amount in integer minor units (e.g. 500000 kobo = ₦5,000)' })
  @IsString()
  @Matches(/^\d+$/, { message: 'amountMinor must be a positive integer minor unit string' })
  amountMinor: string;

  @ApiProperty({ example: 'NGN', description: 'Currency or Asset symbol (NGN, GHS, USDT, BTC)' })
  @IsString()
  @IsNotEmpty()
  currency: string;

  @ApiProperty({ example: 'DEP-USDT-20261003-001', description: 'Strictly unique idempotency reference' })
  @IsString()
  @IsNotEmpty()
  idempotencyRef: string;

  @ApiPropertyOptional({ example: 'Deposit credit for 100 USDT off-ramp' })
  @IsString()
  @IsOptional()
  description?: string;
}
