import { IsEmail, IsNotEmpty, IsOptional, IsString, Length, Matches, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RequestOtpDto {
  @ApiProperty({ example: 'user@example.com or +2348012345678' })
  @IsString()
  @IsNotEmpty()
  recipient: string;

  @ApiProperty({ enum: ['SIGNUP', 'LOGIN', 'PASSWORD_RESET', 'PIN_RESET'], default: 'SIGNUP' })
  @IsString()
  @IsNotEmpty()
  purpose: 'SIGNUP' | 'LOGIN' | 'PASSWORD_RESET' | 'PIN_RESET';
}

export class VerifyOtpAndSignupDto {
  @ApiProperty({ example: 'user@example.com or +2348012345678' })
  @IsString()
  @IsNotEmpty()
  recipient: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6)
  code: string;

  @ApiProperty({ example: 'SecurePassword123!' })
  @IsString()
  @MinLength(8)
  password: string;

  @ApiPropertyOptional({ example: 'NG', default: 'NG' })
  @IsString()
  @IsOptional()
  country?: string;

  @ApiPropertyOptional({ example: 'df-ios-uuid-12345' })
  @IsString()
  @IsOptional()
  deviceFingerprint?: string;

  @ApiPropertyOptional({ example: 'iPhone 15 Pro' })
  @IsString()
  @IsOptional()
  deviceName?: string;

  @ApiPropertyOptional({ example: 'iOS 17.5' })
  @IsString()
  @IsOptional()
  os?: string;
}

export class LoginDto {
  @ApiProperty({ example: 'user@offramp.test or +2348012345678' })
  @IsString()
  @IsNotEmpty()
  identifier: string;

  @ApiProperty({ example: 'UserPassword123!' })
  @IsString()
  @IsNotEmpty()
  password: string;

  @ApiPropertyOptional({ example: '123456 (if 2FA is enabled)' })
  @IsString()
  @IsOptional()
  code2fa?: string;

  @ApiPropertyOptional({ example: 'df-ios-uuid-12345' })
  @IsString()
  @IsOptional()
  deviceFingerprint?: string;

  @ApiPropertyOptional({ example: 'iPhone 15 Pro' })
  @IsString()
  @IsOptional()
  deviceName?: string;

  @ApiPropertyOptional({ example: 'iOS 17.5' })
  @IsString()
  @IsOptional()
  os?: string;
}

export class RefreshTokenDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class SetPinDto {
  @ApiProperty({ example: '1234' })
  @IsString()
  @Length(4, 4)
  @Matches(/^\d{4}$/, { message: 'PIN must be exactly 4 numeric digits' })
  pin: string;
}

export class VerifyPinDto {
  @ApiProperty({ example: '1234' })
  @IsString()
  @Length(4, 4)
  @Matches(/^\d{4}$/, { message: 'PIN must be exactly 4 numeric digits' })
  pin: string;
}

export class ChangePinDto {
  @ApiProperty({ example: '1234' })
  @IsString()
  @Length(4, 4)
  oldPin: string;

  @ApiProperty({ example: '5678' })
  @IsString()
  @Length(4, 4)
  @Matches(/^\d{4}$/, { message: 'New PIN must be exactly 4 numeric digits' })
  newPin: string;
}

export class Enable2faDto {
  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6)
  code: string;
}

export class AdminLoginDto {
  @ApiProperty({ example: 'admin@offramp.test' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'AdminPassword123!' })
  @IsString()
  @IsNotEmpty()
  password: string;
}
