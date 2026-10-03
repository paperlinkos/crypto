import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';

export interface OtpResult {
  message: string;
  expiresInSeconds: number;
  sandboxCode?: string; // Included only in non-production/sandbox environments for automated testing
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly OTP_TTL_SECONDS = 600; // 10 minutes
  private readonly MAX_ATTEMPTS = 5;

  constructor(private redis: RedisService) {}

  async generateOtp(recipient: string, purpose: 'SIGNUP' | 'LOGIN' | 'PASSWORD_RESET' | 'PIN_RESET'): Promise<OtpResult> {
    const cleanRecipient = recipient.trim().toLowerCase();
    const rateLimitKey = `otp_ratelimit:${purpose}:${cleanRecipient}`;

    // Throttle: maximum 5 OTP requests per 10 minutes
    const requestCount = await this.redis.incr(rateLimitKey);
    if (requestCount === 1) {
      await this.redis.expire(rateLimitKey, 600);
    } else if (requestCount > 5) {
      throw new BadRequestException('Too many OTP requests. Please wait before requesting another code.');
    }

    // Generate random 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const otpKey = `otp:${purpose}:${cleanRecipient}`;
    const attemptsKey = `otp_attempts:${purpose}:${cleanRecipient}`;

    await this.redis.set(otpKey, code, this.OTP_TTL_SECONDS);
    await this.redis.set(attemptsKey, '0', this.OTP_TTL_SECONDS);

    this.logger.log(`[SANDBOX OTP] Code for ${cleanRecipient} (${purpose}): ${code}`);

    return {
      message: `Verification code sent to ${cleanRecipient}`,
      expiresInSeconds: this.OTP_TTL_SECONDS,
      sandboxCode: process.env.NODE_ENV !== 'production' ? code : undefined,
    };
  }

  async verifyOtp(recipient: string, code: string, purpose: 'SIGNUP' | 'LOGIN' | 'PASSWORD_RESET' | 'PIN_RESET'): Promise<boolean> {
    const cleanRecipient = recipient.trim().toLowerCase();
    const otpKey = `otp:${purpose}:${cleanRecipient}`;
    const attemptsKey = `otp_attempts:${purpose}:${cleanRecipient}`;

    const storedCode = await this.redis.get(otpKey);
    if (!storedCode) {
      throw new BadRequestException('OTP has expired or was not requested');
    }

    const currentAttempts = parseInt((await this.redis.get(attemptsKey)) || '0', 10);
    if (currentAttempts >= this.MAX_ATTEMPTS) {
      await this.redis.del(otpKey);
      await this.redis.del(attemptsKey);
      throw new BadRequestException('Maximum verification attempts exceeded. Please request a new code.');
    }

    if (storedCode !== code.trim()) {
      await this.redis.incr(attemptsKey);
      const remaining = this.MAX_ATTEMPTS - (currentAttempts + 1);
      throw new BadRequestException(`Invalid verification code. ${remaining} attempt(s) remaining.`);
    }

    // Success: cleanup used OTP
    await this.redis.del(otpKey);
    await this.redis.del(attemptsKey);
    return true;
  }
}
