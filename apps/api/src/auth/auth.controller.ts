import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Req,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { PinService } from './pin.service';
import { TwoFactorService } from './two-factor.service';
import { DeviceService } from './device.service';
import {
  RequestOtpDto,
  VerifyOtpAndSignupDto,
  LoginDto,
  AdminLoginDto,
  RefreshTokenDto,
  SetPinDto,
  VerifyPinDto,
  ChangePinDto,
  Enable2faDto,
} from './dto/auth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';

@ApiTags('Authentication & Security')
@Controller('auth')
export class AuthController {
  constructor(
    private authService: AuthService,
    private pinService: PinService,
    private twoFactorService: TwoFactorService,
    private deviceService: DeviceService,
  ) {}

  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request a 6-digit OTP verification code' })
  @ApiResponse({ status: 200, description: 'OTP sent successfully' })
  async requestOtp(@Body() dto: RequestOtpDto) {
    return await this.authService.requestOtp(dto);
  }

  @Post('signup')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Verify OTP and register new user account' })
  @ApiResponse({ status: 201, description: 'User account created and tokens issued' })
  async signup(@Body() dto: VerifyOtpAndSignupDto, @Req() req: Request) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';
    const userAgent = req.headers['user-agent'] || 'Unknown Agent';

    return await this.authService.signup(dto, {
      fingerprint: dto.deviceFingerprint || 'web-default-fingerprint',
      name: dto.deviceName,
      os: dto.os,
      ipAddress,
      userAgent,
    });
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Authenticate user with email/phone & password' })
  @ApiResponse({ status: 200, description: 'Tokens issued upon successful authentication' })
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';
    const userAgent = req.headers['user-agent'] || 'Unknown Agent';

    return await this.authService.login(dto, {
      fingerprint: dto.deviceFingerprint || 'web-default-fingerprint',
      name: dto.deviceName,
      os: dto.os,
      ipAddress,
      userAgent,
    });
  }

  @Post('admin/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Staff & admin console authentication' })
  async adminLogin(@Body() dto: AdminLoginDto, @Req() req: Request) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';
    return await this.authService.adminLogin(dto, ipAddress);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rotate refresh token and obtain new access token' })
  async refreshTokens(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';
    const userAgent = req.headers['user-agent'] || 'Unknown Agent';

    return await this.authService.refreshTokens(dto, {
      fingerprint: 'refreshed-device',
      ipAddress,
      userAgent,
    });
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke active session and log out' })
  async logout(@CurrentUser() user: AuthenticatedUser) {
    return await this.authService.logout(user.userId, user.sessionId);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current authenticated user profile & KYC limits' })
  async getProfile(@CurrentUser('userId') userId: string) {
    return await this.authService.getProfile(userId);
  }

  @Post('pin/set')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set or initialize 4-digit transaction PIN' })
  async setPin(@CurrentUser('userId') userId: string, @Body() dto: SetPinDto) {
    return await this.pinService.setPin(userId, dto.pin);
  }

  @Post('pin/verify')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify transaction PIN with lockout protection' })
  async verifyPin(@CurrentUser('userId') userId: string, @Body() dto: VerifyPinDto) {
    const isValid = await this.pinService.verifyPin(userId, dto.pin);
    return { valid: isValid, message: 'PIN verified successfully' };
  }

  @Post('pin/change')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change transaction PIN requiring old PIN' })
  async changePin(@CurrentUser('userId') userId: string, @Body() dto: ChangePinDto) {
    await this.pinService.verifyPin(userId, dto.oldPin);
    return await this.pinService.setPin(userId, dto.newPin);
  }

  @Post('2fa/generate')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Generate TOTP 2FA secret and QR code' })
  async generate2faSecret(@CurrentUser('userId') userId: string) {
    return await this.twoFactorService.generateSecret(userId);
  }

  @Post('2fa/enable')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify code and enable 2FA' })
  async enable2fa(@CurrentUser('userId') userId: string, @Body() dto: Enable2faDto) {
    return await this.twoFactorService.enable2FA(userId, dto.code);
  }

  @Post('2fa/disable')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Disable 2FA using valid TOTP code' })
  async disable2fa(@CurrentUser('userId') userId: string, @Body() dto: Enable2faDto) {
    return await this.twoFactorService.disable2FA(userId, dto.code);
  }

  @Get('devices')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List user active devices and sessions' })
  async getDevices(@CurrentUser('userId') userId: string) {
    return await this.deviceService.getUserDevices(userId);
  }

  @Delete('devices/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke specific device session' })
  async revokeDevice(@CurrentUser('userId') userId: string, @Param('id') sessionId: string) {
    await this.deviceService.revokeSession(userId, sessionId);
    return { message: 'Session revoked successfully' };
  }
}
