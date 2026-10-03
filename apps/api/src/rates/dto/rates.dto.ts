import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CryptoAsset, FiatCurrency } from '@prisma/client';
import { Type } from 'class-transformer';

export class GetQuoteQueryDto {
  @ApiProperty({ enum: CryptoAsset, example: CryptoAsset.USDT })
  @IsEnum(CryptoAsset)
  @IsNotEmpty()
  asset: CryptoAsset;

  @ApiProperty({ example: '100.00', description: 'Crypto amount to off-ramp' })
  @IsString()
  @IsNotEmpty()
  amount: string;

  @ApiPropertyOptional({ enum: FiatCurrency, example: FiatCurrency.NGN, default: FiatCurrency.NGN })
  @IsEnum(FiatCurrency)
  @IsOptional()
  fiat?: FiatCurrency;
}

export class UpdateSpreadDto {
  @ApiProperty({ enum: CryptoAsset, example: CryptoAsset.USDT })
  @IsEnum(CryptoAsset)
  @IsNotEmpty()
  asset: CryptoAsset;

  @ApiProperty({ example: 1.5, description: 'Spread markup percentage (e.g. 1.5 for 1.5%)' })
  @IsNumber()
  @Type(() => Number)
  @Min(0)
  @Max(20)
  spreadPercent: number;
}
