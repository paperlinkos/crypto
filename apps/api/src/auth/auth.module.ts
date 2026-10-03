import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { DeviceService } from './device.service';
import { PinService } from './pin.service';
import { TwoFactorService } from './two-factor.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { RolesGuard } from '../common/guards/roles.guard';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_ACCESS_SECRET') || 'offramp_super_secret_access_jwt_key_change_in_prod_32chars',
        signOptions: {
          expiresIn: config.get<string>('JWT_ACCESS_EXPIRY') || '15m',
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    DeviceService,
    PinService,
    TwoFactorService,
    JwtStrategy,
    RolesGuard,
  ],
  exports: [AuthService, PinService, TwoFactorService, DeviceService, JwtStrategy, PassportModule],
})
export class AuthModule {}
