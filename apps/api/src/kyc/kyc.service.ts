import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SandboxKycProvider } from './adapters/sandbox-kyc.provider';
import {
  SubmitTier1Dto,
  SubmitTier2Dto,
  SubmitTier3Dto,
  AdminReviewKycDto,
} from './dto/kyc.dto';
import { KycTier, KycStatus, PayoutStatus } from '@prisma/client';

@Injectable()
export class KycService {
  private readonly logger = new Logger(KycService.name);

  // Tier Limits in Minor Units (Kobo: ₦1.00 = 100 kobo)
  public static readonly TIER_LIMITS = {
    [KycTier.TIER_0]: {
      dailyLimitMinor: BigInt(0),
      singleTxLimitMinor: BigInt(0),
    },
    [KycTier.TIER_1]: {
      dailyLimitMinor: BigInt(50000000), // ₦500,000
      singleTxLimitMinor: BigInt(10000000), // ₦100,000
    },
    [KycTier.TIER_2]: {
      dailyLimitMinor: BigInt(500000000), // ₦5,000,000
      singleTxLimitMinor: BigInt(100000000), // ₦1,000,000
    },
    [KycTier.TIER_3]: {
      dailyLimitMinor: BigInt(5000000000), // ₦50,000,000
      singleTxLimitMinor: BigInt(1000000000), // ₦10,000,000
    },
  };

  constructor(
    private prisma: PrismaService,
    private kycProvider: SandboxKycProvider,
  ) {}

  /**
   * Retrieves KYC profile and live limit consumption for a user.
   */
  async getKycStatus(userId: string) {
    const profile = await this.prisma.kycProfile.findUnique({
      where: { userId },
    });

    if (!profile) {
      throw new NotFoundException('KYC Profile not found for user');
    }

    const { dailyUsedMinor, dailyRemainingMinor } = await this.calculateDailyLimitUsage(
      userId,
      profile.dailyLimitMinor,
    );

    return {
      tier: profile.tier,
      status: profile.status,
      idType: profile.idType,
      idNumberMasked: profile.idNumberMasked,
      verifiedName: profile.verifiedName,
      rejectionReason: profile.rejectionReason,
      dailyLimitMinor: profile.dailyLimitMinor.toString(),
      singleTxLimitMinor: profile.singleTxLimitMinor.toString(),
      dailyUsedMinor: dailyUsedMinor.toString(),
      dailyRemainingMinor: dailyRemainingMinor.toString(),
      updatedAt: profile.updatedAt,
    };
  }

  /**
   * Tier 1 Verification: BVN / NIN lookup.
   */
  async submitTier1(userId: string, dto: SubmitTier1Dto) {
    const cleanId = dto.idNumber.trim();
    let result: any;

    if (dto.idType === 'BVN') {
      result = await this.kycProvider.verifyBvn(cleanId, dto.firstName, dto.lastName, dto.dob);
    } else {
      result = await this.kycProvider.verifyNin(cleanId, dto.firstName, dto.lastName);
    }

    if (!result.success) {
      throw new BadRequestException('Identity verification failed: details could not be validated');
    }

    const masked = `${cleanId.slice(0, 4)}****${cleanId.slice(-3)}`;
    const limits = KycService.TIER_LIMITS[KycTier.TIER_1];

    const updated = await this.prisma.kycProfile.upsert({
      where: { userId },
      update: {
        tier: KycTier.TIER_1,
        status: KycStatus.APPROVED,
        providerRef: result.providerRef,
        idType: dto.idType,
        idNumberMasked: masked,
        verifiedName: result.verifiedName,
        dailyLimitMinor: limits.dailyLimitMinor,
        singleTxLimitMinor: limits.singleTxLimitMinor,
        rejectionReason: null,
      },
      create: {
        userId,
        tier: KycTier.TIER_1,
        status: KycStatus.APPROVED,
        providerRef: result.providerRef,
        idType: dto.idType,
        idNumberMasked: masked,
        verifiedName: result.verifiedName,
        dailyLimitMinor: limits.dailyLimitMinor,
        singleTxLimitMinor: limits.singleTxLimitMinor,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: 'KYC_SUBMITTED',
        entityType: 'KYC',
        entityId: updated.id,
        newState: {
          tier: KycTier.TIER_1,
          status: KycStatus.APPROVED,
          verifiedName: result.verifiedName,
        },
      },
    });

    return {
      message: 'Tier 1 identity verification successful',
      tier: KycTier.TIER_1,
      status: KycStatus.APPROVED,
      verifiedName: result.verifiedName,
      dailyLimitMinor: limits.dailyLimitMinor.toString(),
      singleTxLimitMinor: limits.singleTxLimitMinor.toString(),
    };
  }

  /**
   * Tier 2 Verification: Government ID + Biometric Face Liveness.
   * Compliance: Stores only provider reference, no raw images.
   */
  async submitTier2(userId: string, dto: SubmitTier2Dto) {
    const profile = await this.prisma.kycProfile.findUnique({ where: { userId } });
    if (!profile || profile.tier === KycTier.TIER_0) {
      throw new BadRequestException('Must complete Tier 1 verification before submitting Tier 2');
    }

    const docResult = await this.kycProvider.verifyDocument(dto.idType, dto.idNumber);
    const faceResult = await this.kycProvider.verifyFace(dto.selfieBase64, docResult.providerRef);

    if (!docResult.success || !faceResult.success) {
      throw new BadRequestException('Biometric or Document verification failed');
    }

    const limits = KycService.TIER_LIMITS[KycTier.TIER_2];

    const updated = await this.prisma.kycProfile.update({
      where: { userId },
      data: {
        tier: KycTier.TIER_2,
        status: KycStatus.APPROVED,
        providerRef: faceResult.providerRef,
        idType: dto.idType,
        idNumberMasked: docResult.verifiedDetails.docNumberMasked,
        dailyLimitMinor: limits.dailyLimitMinor,
        singleTxLimitMinor: limits.singleTxLimitMinor,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: 'KYC_SUBMITTED',
        entityType: 'KYC',
        entityId: updated.id,
        newState: {
          tier: KycTier.TIER_2,
          status: KycStatus.APPROVED,
        },
      },
    });

    return {
      message: 'Tier 2 Biometric & ID verification successful',
      tier: KycTier.TIER_2,
      status: KycStatus.APPROVED,
      dailyLimitMinor: limits.dailyLimitMinor.toString(),
      singleTxLimitMinor: limits.singleTxLimitMinor.toString(),
    };
  }

  /**
   * Tier 3 Submission: Proof of Address / Enhanced Due Diligence.
   */
  async submitTier3(userId: string, dto: SubmitTier3Dto) {
    const profile = await this.prisma.kycProfile.findUnique({ where: { userId } });
    if (!profile || profile.tier !== KycTier.TIER_2) {
      throw new BadRequestException('Must be Tier 2 verified before applying for Tier 3 higher limits');
    }

    const updated = await this.prisma.kycProfile.update({
      where: { userId },
      data: {
        status: KycStatus.PENDING,
        providerRef: `SANDBOX_POA_${dto.utilityDocType}_${Date.now()}`,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'USER',
        actorId: userId,
        action: 'KYC_SUBMITTED',
        entityType: 'KYC',
        entityId: updated.id,
        newState: { tier: KycTier.TIER_3, status: KycStatus.PENDING },
      },
    });

    return {
      message: 'Tier 3 documents submitted and queued for Compliance review',
      status: KycStatus.PENDING,
    };
  }

  /**
   * Admin / Compliance Review for Tier 3 or flagged profiles.
   */
  async adminReviewKyc(adminId: string, profileId: string, dto: AdminReviewKycDto) {
    const profile = await this.prisma.kycProfile.findUnique({
      where: { id: profileId },
    });

    if (!profile) {
      throw new NotFoundException(`KYC Profile [${profileId}] not found`);
    }

    let nextTier = profile.tier;
    let dailyLimit = profile.dailyLimitMinor;
    let singleTxLimit = profile.singleTxLimitMinor;

    if (dto.status === KycStatus.APPROVED) {
      nextTier = KycTier.TIER_3;
      const limits = KycService.TIER_LIMITS[KycTier.TIER_3];
      dailyLimit = limits.dailyLimitMinor;
      singleTxLimit = limits.singleTxLimitMinor;
    }

    const updated = await this.prisma.kycProfile.update({
      where: { id: profileId },
      data: {
        status: dto.status,
        tier: nextTier,
        dailyLimitMinor: dailyLimit,
        singleTxLimitMinor: singleTxLimit,
        rejectionReason: dto.rejectionReason || null,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorType: 'ADMIN',
        actorId: adminId,
        action: 'KYC_REVIEWED',
        entityType: 'KYC',
        entityId: profileId,
        newState: {
          status: dto.status,
          tier: nextTier,
          rejectionReason: dto.rejectionReason,
        },
      },
    });

    return updated;
  }

  /**
   * Retrieves compliance review queue for staff.
   */
  async getAdminQueue() {
    return await this.prisma.kycProfile.findMany({
      where: { status: KycStatus.PENDING },
      include: {
        user: { select: { id: true, email: true, phoneNumber: true, createdAt: true } },
      },
      orderBy: { updatedAt: 'asc' },
    });
  }

  /**
   * Core Payout Limit Enforcement (Rule #6).
   * Verifies both single-transaction and 24-hour aggregate limits before execution.
   */
  async enforcePayoutLimits(userId: string, amountMinor: bigint) {
    const profile = await this.prisma.kycProfile.findUnique({
      where: { userId },
    });

    if (!profile || profile.status !== KycStatus.APPROVED) {
      throw new ForbiddenException('Account requires approved KYC verification before off-ramp payouts can be processed.');
    }

    // 1. Single Transaction Limit Check
    if (amountMinor > profile.singleTxLimitMinor) {
      throw new ForbiddenException(
        `Amount exceeds your maximum per-transaction limit of ${profile.singleTxLimitMinor.toString()} minor units for Tier ${profile.tier}.`,
      );
    }

    // 2. 24-Hour Rolling Daily Limit Check
    const { dailyUsedMinor, dailyRemainingMinor } = await this.calculateDailyLimitUsage(
      userId,
      profile.dailyLimitMinor,
    );

    if (amountMinor > dailyRemainingMinor) {
      throw new ForbiddenException(
        `Transaction exceeds your remaining 24-hour daily limit. Remaining: ${dailyRemainingMinor.toString()}, Requested: ${amountMinor.toString()}`,
      );
    }

    return {
      allowed: true,
      tier: profile.tier,
      dailyLimitMinor: profile.dailyLimitMinor,
      dailyUsedMinor,
      dailyRemainingMinor,
    };
  }

  private async calculateDailyLimitUsage(userId: string, dailyLimitMinor: bigint) {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const aggregate = await this.prisma.payout.aggregate({
      where: {
        userId,
        createdAt: { gte: oneDayAgo },
        status: { in: [PayoutStatus.SUCCESS, PayoutStatus.PROCESSING, PayoutStatus.HOLD_RESERVED] },
      },
      _sum: { amountMinor: true },
    });

    const dailyUsedMinor = aggregate._sum.amountMinor || BigInt(0);
    const dailyRemainingMinor =
      dailyLimitMinor > dailyUsedMinor ? dailyLimitMinor - dailyUsedMinor : BigInt(0);

    return { dailyUsedMinor, dailyRemainingMinor };
  }
}
