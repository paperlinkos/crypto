import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from './otp.service';
import { DeviceService, DeviceContext } from './device.service';
import { TwoFactorService } from './two-factor.service';
import {
  RequestOtpDto,
  VerifyOtpAndSignupDto,
  LoginDto,
  AdminLoginDto,
  RefreshTokenDto,
} from './dto/auth.dto';
import { UserStatus, KycTier, KycStatus, UserRole } from '@prisma/client';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private otpService: OtpService,
    private deviceService: DeviceService,
    private twoFactorService: TwoFactorService,
  ) {}

  async requestOtp(dto: RequestOtpDto) {
    return await this.otpService.generateOtp(dto.recipient, dto.purpose);
  }

  async signup(dto: VerifyOtpAndSignupDto, deviceCtx: DeviceContext) {
    // 1. Verify OTP
    await this.otpService.verifyOtp(dto.recipient, dto.code, 'SIGNUP');

    // 2. Identify email vs phone
    const isEmail = dto.recipient.includes('@');
    const email = isEmail ? dto.recipient.toLowerCase().trim() : null;
    const phoneNumber = !isEmail ? dto.recipient.trim() : null;

    // 3. Check for existing user
    if (email) {
      const existing = await this.prisma.user.findUnique({ where: { email } });
      if (existing) throw new ConflictException('An account with this email already exists');
    }
    if (phoneNumber) {
      const existing = await this.prisma.user.findUnique({ where: { phoneNumber } });
      if (existing) throw new ConflictException('An account with this phone number already exists');
    }

    // 4. Hash password
    const passwordHash = await bcrypt.hash(dto.password, 10);

    // 5. Create user, default KYC profile, and customer sub-ledger account in a transaction
    const user = await this.prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          email,
          phoneNumber,
          passwordHash,
          country: dto.country || 'NG',
          status: UserStatus.ACTIVE,
          autoPayout: true,
        },
      });

      // Default Tier 0 KYC Profile
      await tx.kycProfile.create({
        data: {
          userId: newUser.id,
          tier: KycTier.TIER_0,
          status: KycStatus.NOT_SUBMITTED,
          dailyLimitMinor: BigInt(50000000), // Default ₦500k limit in kobo
          singleTxLimitMinor: BigInt(10000000),
        },
      });

      // Customer Fiat Liability Ledger Sub-Account
      await tx.ledgerAccount.create({
        data: {
          accountNumber: `2010-USER-${newUser.id.slice(0, 8)}`,
          name: `User Liability Pool (${email || phoneNumber})`,
          type: 'LIABILITY',
          currency: 'NGN',
          userId: newUser.id,
        },
      });

      // Audit log
      await tx.auditLog.create({
        data: {
          actorType: 'USER',
          actorId: newUser.id,
          action: 'USER_SIGNUP',
          entityType: 'USER',
          entityId: newUser.id,
          ipAddress: deviceCtx.ipAddress,
          newState: { email, phoneNumber, country: newUser.country },
        },
      });

      return newUser;
    });

    // 6. Generate Tokens & Session
    return await this.generateUserAuthResponse(user, deviceCtx);
  }

  async login(dto: LoginDto, deviceCtx: DeviceContext) {
    const identifier = dto.identifier.trim().toLowerCase();
    const isEmail = identifier.includes('@');

    const user = await this.prisma.user.findFirst({
      where: isEmail ? { email: identifier } : { phoneNumber: identifier },
      include: { kycProfile: true },
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status === UserStatus.LOCKED || user.status === UserStatus.SUSPENDED) {
      throw new UnauthorizedException(`Account is ${user.status.toLowerCase()}. Please contact support.`);
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // 2FA check if enabled
    if (user.isTwoFactorEnabled) {
      if (!dto.code2fa) {
        return {
          requires2FA: true,
          message: 'Two-Factor Authentication (2FA) code required to complete login',
        };
      }
      await this.twoFactorService.verifyUser2FA(user.id, dto.code2fa);
    }

    // Record audit log
    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: user.id,
        action: 'USER_LOGIN',
        entityType: 'USER',
        entityId: user.id,
        ipAddress: deviceCtx.ipAddress,
      },
    });

    return await this.generateUserAuthResponse(user, deviceCtx);
  }

  async adminLogin(dto: AdminLoginDto, ipAddress?: string) {
    const admin = await this.prisma.adminUser.findUnique({
      where: { email: dto.email.trim().toLowerCase() },
    });

    if (!admin || !admin.isActive) {
      throw new UnauthorizedException('Invalid admin credentials');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, admin.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid admin credentials');
    }

    await this.prisma.adminUser.update({
      where: { id: admin.id },
      data: { lastLoginAt: new Date() },
    });

    const payload = {
      sub: admin.id,
      email: admin.email,
      role: admin.role,
    };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRY') || '15m',
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'ADMIN',
        actorId: admin.id,
        action: 'ADMIN_ACTION',
        entityType: 'USER',
        entityId: admin.id,
        ipAddress,
        newState: { message: 'Admin login successful' },
      },
    });

    return {
      accessToken,
      admin: {
        id: admin.id,
        email: admin.email,
        name: admin.name,
        role: admin.role,
      },
    };
  }

  async refreshTokens(dto: RefreshTokenDto, deviceCtx: DeviceContext) {
    let payload: any;
    try {
      payload = this.jwtService.verify(dto.refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const session = await this.prisma.session.findUnique({
      where: { id: payload.sessionId },
      include: { user: true, device: true },
    });

    if (!session || session.isRevoked || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Session expired or revoked');
    }

    const isHashMatch = await bcrypt.compare(dto.refreshToken, session.refreshTokenHash);
    if (!isHashMatch) {
      // Possible token reuse attack: revoke session immediately!
      await this.prisma.session.update({
        where: { id: session.id },
        data: { isRevoked: true },
      });
      throw new UnauthorizedException('Security alert: Refresh token mismatch. Session revoked.');
    }

    // Revoke old session and issue new token pair
    await this.prisma.session.update({
      where: { id: session.id },
      data: { isRevoked: true },
    });

    const activeDeviceCtx: DeviceContext = {
      fingerprint: session.device?.deviceFingerprint || deviceCtx.fingerprint,
      name: session.device?.deviceName || deviceCtx.name,
      os: session.device?.os || deviceCtx.os,
      ipAddress: deviceCtx.ipAddress,
      userAgent: deviceCtx.userAgent,
    };

    return await this.generateUserAuthResponse(session.user, activeDeviceCtx);
  }

  async logout(userId: string, sessionId?: string) {
    if (sessionId) {
      await this.deviceService.revokeSession(userId, sessionId);
    } else {
      await this.deviceService.revokeAllUserSessions(userId);
    }
    return { message: 'Successfully logged out' };
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        phoneNumber: true,
        country: true,
        status: true,
        isTwoFactorEnabled: true,
        autoPayout: true,
        createdAt: true,
        pinHash: true,
        kycProfile: {
          select: {
            tier: true,
            status: true,
            verifiedName: true,
            idType: true,
            dailyLimitMinor: true,
            singleTxLimitMinor: true,
          },
        },
      },
    });

    if (!user) throw new NotFoundException('User profile not found');

    const { pinHash, kycProfile, ...rest } = user;

    return {
      ...rest,
      isPinSet: !!pinHash,
      kyc: kycProfile
        ? {
            tier: kycProfile.tier,
            status: kycProfile.status,
            verifiedName: kycProfile.verifiedName,
            idType: kycProfile.idType,
            dailyLimitMinor: kycProfile.dailyLimitMinor.toString(),
            singleTxLimitMinor: kycProfile.singleTxLimitMinor.toString(),
          }
        : null,
    };
  }

  private async generateUserAuthResponse(user: any, deviceCtx: DeviceContext) {
    const refreshSecret = this.configService.get<string>('JWT_REFRESH_SECRET') || 'offramp_refresh_secret';
    const accessSecret = this.configService.get<string>('JWT_ACCESS_SECRET') || 'offramp_access_secret';
    const accessExpiry = this.configService.get<string>('JWT_ACCESS_EXPIRY') || '15m';
    const refreshExpiry = this.configService.get<string>('JWT_REFRESH_EXPIRY') || '7d';

    const rawRefreshToken = this.jwtService.sign(
      { sub: user.id, type: 'REFRESH' },
      { secret: refreshSecret, expiresIn: refreshExpiry },
    );

    const refreshTokenHash = await bcrypt.hash(rawRefreshToken, 10);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const { device, session } = await this.deviceService.trackDeviceAndCreateSession(
      user.id,
      deviceCtx,
      refreshTokenHash,
      expiresAt,
    );

    // Re-sign refresh token with sessionId embedded
    const tokenWithSession = this.jwtService.sign(
      { sub: user.id, sessionId: session.id, type: 'REFRESH' },
      { secret: refreshSecret, expiresIn: refreshExpiry },
    );
    const tokenWithSessionHash = await bcrypt.hash(tokenWithSession, 10);

    await this.prisma.session.update({
      where: { id: session.id },
      data: { refreshTokenHash: tokenWithSessionHash },
    });

    const accessToken = this.jwtService.sign(
      {
        sub: user.id,
        email: user.email,
        phoneNumber: user.phoneNumber,
        role: 'USER',
        sessionId: session.id,
        deviceId: device.id,
      },
      { secret: accessSecret, expiresIn: accessExpiry },
    );

    return {
      accessToken,
      refreshToken: tokenWithSession,
      sessionId: session.id,
      user: {
        id: user.id,
        email: user.email,
        phoneNumber: user.phoneNumber,
        country: user.country,
        status: user.status,
        isPinSet: !!user.pinHash,
        isTwoFactorEnabled: user.isTwoFactorEnabled,
      },
    };
  }
}
