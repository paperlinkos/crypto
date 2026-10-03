import { Injectable, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PinService {
  private readonly MAX_FAILED_ATTEMPTS = 5;
  private readonly LOCKOUT_MINUTES = 30;

  constructor(private prisma: PrismaService) {}

  async setPin(userId: string, pin: string) {
    this.validatePinFormat(pin);

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const pinHash = await bcrypt.hash(pin, 10);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        pinHash,
        pinAttempts: 0,
        pinLockedUntil: null,
      },
    });

    // Write audit log
    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: 'PIN_CHANGED',
        entityType: 'USER',
        entityId: userId,
        newState: { message: 'Transaction PIN set or updated' },
      },
    });

    return { message: 'Transaction PIN successfully set' };
  }

  async verifyPin(userId: string, pin: string): Promise<boolean> {
    this.validatePinFormat(pin);

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (!user.pinHash) {
      throw new BadRequestException('Transaction PIN has not been set');
    }

    // Check if PIN is currently locked out
    const now = new Date();
    if (user.pinLockedUntil && user.pinLockedUntil > now) {
      const minutesRemaining = Math.ceil((user.pinLockedUntil.getTime() - now.getTime()) / (60 * 1000));
      throw new ForbiddenException(
        `Transaction PIN is locked due to repeated incorrect entries. Try again in ${minutesRemaining} minute(s).`,
      );
    }

    const isMatch = await bcrypt.compare(pin, user.pinHash);

    if (!isMatch) {
      const nextAttempts = user.pinAttempts + 1;

      if (nextAttempts >= this.MAX_FAILED_ATTEMPTS) {
        const lockoutTime = new Date(now.getTime() + this.LOCKOUT_MINUTES * 60 * 1000);
        await this.prisma.user.update({
          where: { id: userId },
          data: {
            pinAttempts: nextAttempts,
            pinLockedUntil: lockoutTime,
          },
        });

        // Audit lockout
        await this.prisma.auditLog.create({
          data: {
            actorType: 'SYSTEM',
            actorId: userId,
            action: 'PIN_LOCKOUT_TRIGGERED',
            entityType: 'USER',
            entityId: userId,
            newState: { lockoutUntil: lockoutTime },
          },
        });

        throw new ForbiddenException(
          `Incorrect PIN. Maximum failed attempts reached. Your PIN is locked for ${this.LOCKOUT_MINUTES} minutes.`,
        );
      } else {
        await this.prisma.user.update({
          where: { id: userId },
          data: { pinAttempts: nextAttempts },
        });

        const remaining = this.MAX_FAILED_ATTEMPTS - nextAttempts;
        throw new BadRequestException(`Incorrect transaction PIN. ${remaining} attempt(s) remaining before lockout.`);
      }
    }

    // Success: reset attempts
    if (user.pinAttempts > 0 || user.pinLockedUntil) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { pinAttempts: 0, pinLockedUntil: null },
      });
    }

    return true;
  }

  private validatePinFormat(pin: string) {
    if (!pin || !/^\d{4}$/.test(pin.trim())) {
      throw new BadRequestException('Transaction PIN must be exactly 4 numeric digits');
    }
  }
}
