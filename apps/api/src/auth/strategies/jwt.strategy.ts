import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';

export interface JwtPayload {
  sub: string;
  email?: string;
  phoneNumber?: string;
  role: string;
  sessionId?: string;
  deviceId?: string;
  iat?: number;
  exp?: number;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_ACCESS_SECRET') || 'offramp_super_secret_access_jwt_key_change_in_prod_32chars',
    });
  }

  async validate(payload: JwtPayload) {
    // If it's an admin user
    if (payload.role !== 'USER') {
      const admin = await this.prisma.adminUser.findUnique({
        where: { id: payload.sub },
      });
      if (!admin || !admin.isActive) {
        throw new UnauthorizedException('Admin account inactive or not found');
      }
      return {
        userId: admin.id,
        email: admin.email,
        role: admin.role,
      };
    }

    // Standard user
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user || user.status === 'SUSPENDED' || user.status === 'LOCKED') {
      throw new UnauthorizedException('User account is suspended, locked, or invalid');
    }

    // Verify session validity if sessionId is present
    if (payload.sessionId) {
      const session = await this.prisma.session.findUnique({
        where: { id: payload.sessionId },
      });
      if (!session || session.isRevoked || session.expiresAt < new Date()) {
        throw new UnauthorizedException('Session expired or revoked');
      }
    }

    return {
      userId: user.id,
      email: user.email,
      phoneNumber: user.phoneNumber,
      role: 'USER',
      sessionId: payload.sessionId,
      deviceId: payload.deviceId,
    };
  }
}
