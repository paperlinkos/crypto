import { Injectable, BadRequestException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { authenticator } from 'otplib';
import * as QRCode from 'qrcode';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class TwoFactorService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
  ) {}

  async generateSecret(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const secret = authenticator.generateSecret();
    const identifier = user.email || user.phoneNumber || 'user';
    const otpAuthUrl = authenticator.keyuri(identifier, 'OffRamp Financial', secret);

    // Store temp secret in Redis for 15 minutes awaiting user confirmation
    await this.redis.set(`temp_2fa_secret:${userId}`, secret, 900);

    const qrCodeDataUrl = await QRCode.toDataURL(otpAuthUrl);

    return {
      secret,
      otpAuthUrl,
      qrCodeDataUrl,
      message: 'Scan the QR code in Google Authenticator or your 2FA app, then submit the 6-digit code to enable 2FA.',
    };
  }

  async enable2FA(userId: string, code: string) {
    const tempSecret = await this.redis.get(`temp_2fa_secret:${userId}`);
    if (!tempSecret) {
      throw new BadRequestException('2FA setup session expired or not started. Please generate a new secret.');
    }

    const isValid = authenticator.verify({
      token: code.trim(),
      secret: tempSecret,
    });

    if (!isValid) {
      throw new BadRequestException('Invalid 6-digit 2FA code');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isTwoFactorEnabled: true,
        twoFactorSecret: tempSecret,
      },
    });

    await this.redis.del(`temp_2fa_secret:${userId}`);

    // Audit log
    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: '2FA_ENABLED',
        entityType: 'USER',
        entityId: userId,
        newState: { isTwoFactorEnabled: true },
      },
    });

    return { message: 'Two-Factor Authentication (2FA) successfully enabled' };
  }

  async disable2FA(userId: string, code: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.isTwoFactorEnabled || !user.twoFactorSecret) {
      throw new BadRequestException('2FA is not currently enabled for this account');
    }

    const isValid = authenticator.verify({
      token: code.trim(),
      secret: user.twoFactorSecret,
    });

    if (!isValid) {
      throw new UnauthorizedException('Invalid 2FA code');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isTwoFactorEnabled: false,
        twoFactorSecret: null,
      },
    });

    // Audit log
    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: '2FA_DISABLED',
        entityType: 'USER',
        entityId: userId,
        newState: { isTwoFactorEnabled: false },
      },
    });

    return { message: 'Two-Factor Authentication (2FA) has been disabled' };
  }

  async verifyUser2FA(userId: string, code: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.isTwoFactorEnabled || !user.twoFactorSecret) {
      return true; // 2FA not enabled
    }

    const isValid = authenticator.verify({
      token: code.trim(),
      secret: user.twoFactorSecret,
    });

    if (!isValid) {
      throw new UnauthorizedException('Invalid 2FA code');
    }

    return true;
  }
}
