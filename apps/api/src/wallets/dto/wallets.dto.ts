import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Matches, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CryptoAsset, BlockchainNetwork } from '@prisma/client';

export class AssignWalletDto {
  @ApiProperty({ enum: CryptoAsset, example: CryptoAsset.USDT })
  @IsEnum(CryptoAsset)
  @IsNotEmpty()
  asset: CryptoAsset;

  @ApiProperty({ enum: BlockchainNetwork, example: BlockchainNetwork.TRON_TRC20 })
  @IsEnum(BlockchainNetwork)
  @IsNotEmpty()
  network: BlockchainNetwork;
}

export class DepositWebhookDto {
  @ApiProperty({ example: '0x8f3d... or 7b2a...' })
  @IsString()
  @IsNotEmpty()
  txHash: string;

  @ApiProperty({ example: 'TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6' })
  @IsString()
  @IsNotEmpty()
  address: string;

  @ApiProperty({ enum: CryptoAsset, example: CryptoAsset.USDT })
  @IsEnum(CryptoAsset)
  @IsNotEmpty()
  asset: CryptoAsset;

  @ApiProperty({ enum: BlockchainNetwork, example: BlockchainNetwork.TRON_TRC20 })
  @IsEnum(BlockchainNetwork)
  @IsNotEmpty()
  network: BlockchainNetwork;

  @ApiProperty({ example: '100000000', description: 'Amount in micro-units/satoshis' })
  @IsString()
  @Matches(/^\d+$/)
  amountMinor: string;

  @ApiProperty({ example: 3 })
  @IsNumber()
  @Min(0)
  confirmations: number;
}
