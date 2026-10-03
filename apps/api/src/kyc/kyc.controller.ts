import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { KycService } from './kyc.service';
import {
  SubmitTier1Dto,
  SubmitTier2Dto,
  SubmitTier3Dto,
  AdminReviewKycDto,
} from './dto/kyc.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '@prisma/client';

@ApiTags('KYC & Tiered Compliance')
@Controller('kyc')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class KycController {
  constructor(private kycService: KycService) {}

  @Get('status')
  @ApiOperation({ summary: 'Get current user KYC tier, verification status, and daily limits' })
  async getMyKycStatus(@CurrentUser('userId') userId: string) {
    return await this.kycService.getKycStatus(userId);
  }

  @Post('tier1')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Submit Tier 1 (BVN / NIN) for instant verification' })
  async submitTier1(
    @CurrentUser('userId') userId: string,
    @Body() dto: SubmitTier1Dto,
  ) {
    return await this.kycService.submitTier1(userId, dto);
  }

  @Post('tier2')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Submit Tier 2 (Government ID + Biometric Liveness)' })
  async submitTier2(
    @CurrentUser('userId') userId: string,
    @Body() dto: SubmitTier2Dto,
  ) {
    return await this.kycService.submitTier2(userId, dto);
  }

  @Post('tier3')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Submit Tier 3 Proof of Address for high/unlimited limits' })
  async submitTier3(
    @CurrentUser('userId') userId: string,
    @Body() dto: SubmitTier3Dto,
  ) {
    return await this.kycService.submitTier3(userId, dto);
  }

  @Get('admin/queue')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.COMPLIANCE, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Get compliance officer KYC review queue (Staff only)' })
  async getComplianceQueue() {
    return await this.kycService.getAdminQueue();
  }

  @Patch('admin/review/:profileId')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.COMPLIANCE, UserRole.SUPER_ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve or reject KYC submission with audit logging (Staff only)' })
  async reviewKyc(
    @CurrentUser('userId') adminId: string,
    @Param('profileId') profileId: string,
    @Body() dto: AdminReviewKycDto,
  ) {
    return await this.kycService.adminReviewKyc(adminId, profileId, dto);
  }
}
