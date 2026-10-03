import { IsEnum, IsNotEmpty, IsOptional, IsString, Length, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { KycStatus } from '@prisma/client';

export class SubmitTier1Dto {
  @ApiProperty({ example: '22334455667', description: '11-digit Nigerian BVN or NIN' })
  @IsString()
  @Length(11, 11)
  @Matches(/^\d{11}$/, { message: 'Identification number must be exactly 11 digits' })
  idNumber: string;

  @ApiProperty({ enum: ['BVN', 'NIN'], default: 'BVN' })
  @IsString()
  @IsNotEmpty()
  idType: 'BVN' | 'NIN';

  @ApiProperty({ example: 'Chukwudi' })
  @IsString()
  @IsNotEmpty()
  firstName: string;

  @ApiProperty({ example: 'Okonkwo' })
  @IsString()
  @IsNotEmpty()
  lastName: string;

  @ApiPropertyOptional({ example: '1990-05-15' })
  @IsString()
  @IsOptional()
  dob?: string;
}

export class SubmitTier2Dto {
  @ApiProperty({ enum: ['PASSPORT', 'DRIVERS_LICENSE', 'NATIONAL_ID'] })
  @IsString()
  @IsNotEmpty()
  idType: string;

  @ApiProperty({ example: 'A12345678' })
  @IsString()
  @IsNotEmpty()
  idNumber: string;

  @ApiProperty({ example: 'data:image/jpeg;base64,...', description: 'Base64 encoded selfie for liveness verification' })
  @IsString()
  @IsNotEmpty()
  selfieBase64: string;
}

export class SubmitTier3Dto {
  @ApiProperty({ example: '12 Admiralty Way, Lekki Phase 1' })
  @IsString()
  @IsNotEmpty()
  residentialAddress: string;

  @ApiProperty({ example: 'Lagos' })
  @IsString()
  @IsNotEmpty()
  city: string;

  @ApiProperty({ example: 'Lagos' })
  @IsString()
  @IsNotEmpty()
  state: string;

  @ApiProperty({ enum: ['ELECTRICITY_BILL', 'BANK_STATEMENT', 'WATER_BILL'] })
  @IsString()
  @IsNotEmpty()
  utilityDocType: string;
}

export class AdminReviewKycDto {
  @ApiProperty({ enum: KycStatus, example: KycStatus.APPROVED })
  @IsEnum(KycStatus)
  @IsNotEmpty()
  status: KycStatus;

  @ApiPropertyOptional({ example: 'Name mismatch on government database' })
  @IsString()
  @IsOptional()
  rejectionReason?: string;
}
