import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface DeviceContext {
  fingerprint: string;
  name?: string;
  os?: string;
  ipAddress?: string;
  userAgent?: string;
}

@Injectable()
export class DeviceService {
  constructor(private prisma: PrismaService) {}

  async trackDeviceAndCreateSession(
    userId: string,
    context: DeviceContext,
    refreshTokenHash: string,
    expiresAt: DateTimeStringOrDate,
  ) {
    const fingerprint = context.fingerprint || 'unknown_device';

    // 1. Upsert Device
    const device = await this.prisma.device.upsert({
      where: {
        userId_deviceFingerprint: {
          userId,
          deviceFingerprint: fingerprint,
        },
      },
      update: {
        deviceName: context.name,
        os: context.os,
        ipAddress: context.ipAddress,
        lastActiveAt: new Date(),
      },
      create: {
        userId,
        deviceFingerprint: fingerprint,
        deviceName: context.name || 'Unknown Device',
        os: context.os || 'Unknown OS',
        ipAddress: context.ipAddress || '127.0.0.1',
        isTrusted: false,
      },
    });

    // 2. Create Session
    const session = await this.prisma.session.create({
      data: {
        userId,
        deviceId: device.id,
        refreshTokenHash,
        ipAddress: context.ipAddress || '127.0.0.1',
        userAgent: context.userAgent || 'Unknown Agent',
        expiresAt: typeof expiresAt === 'string' ? new Date(expiresAt) : expiresAt,
        isRevoked: false,
      },
    });

    return { device, session };
  }

  async getUserDevices(userId: string) {
    return await this.prisma.device.findMany({
      where: { userId },
      include: {
        sessions: {
          where: { isRevoked: false, expiresAt: { gt: new Date() } },
          select: { id: true, ipAddress: true, userAgent: true, createdAt: true },
        },
      },
      orderBy: { lastActiveAt: 'desc' },
    });
  }

  async revokeSession(userId: string, sessionId: string) {
    return await this.prisma.session.updateMany({
      where: { id: sessionId, userId },
      data: { isRevoked: true },
    });
  }

  async revokeAllUserSessions(userId: string, exceptSessionId?: string) {
    return await this.prisma.session.updateMany({
      where: {
        userId,
        ...(exceptSessionId ? { id: { not: exceptSessionId } } : {}),
      },
      data: { isRevoked: true },
    });
  }
}

type DateTimeStringOrDate = string | Date;
