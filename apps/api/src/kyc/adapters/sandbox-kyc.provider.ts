import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import {
  IKycProvider,
  BvnVerificationResult,
  NinVerificationResult,
  LivenessResult,
  DocumentVerificationResult,
} from '../interfaces/kyc-provider.interface';
import * as crypto from 'crypto';

@Injectable()
export class SandboxKycProvider implements IKycProvider {
  private readonly logger = new Logger(SandboxKycProvider.name);

  async verifyBvn(
    bvn: string,
    firstName: string,
    lastName: string,
    dob?: string,
  ): Promise<BvnVerificationResult> {
    const cleanBvn = bvn.trim();
    if (!/^\d{11}$/.test(cleanBvn)) {
      throw new BadRequestException('BVN must be exactly 11 numeric digits');
    }

    // Simulated rejection for test BVNs starting with 999
    if (cleanBvn.startsWith('999')) {
      return {
        success: false,
        providerRef: `SANDBOX_BVN_FAIL_${cleanBvn.slice(0, 4)}`,
        verifiedName: '',
        confidenceScore: 0.1,
      };
    }

    const providerRef = `SANDBOX_BVN_OK_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const verifiedName = `${firstName.toUpperCase().trim()} ${lastName.toUpperCase().trim()}`;

    this.logger.log(`[SANDBOX KYC] BVN verified for ${verifiedName} (Ref: ${providerRef})`);

    return {
      success: true,
      providerRef,
      verifiedName,
      confidenceScore: 0.98,
    };
  }

  async verifyNin(
    nin: string,
    firstName: string,
    lastName: string,
  ): Promise<NinVerificationResult> {
    const cleanNin = nin.trim();
    if (!/^\d{11}$/.test(cleanNin)) {
      throw new BadRequestException('NIN must be exactly 11 numeric digits');
    }

    if (cleanNin.startsWith('999')) {
      return {
        success: false,
        providerRef: `SANDBOX_NIN_FAIL_${cleanNin.slice(0, 4)}`,
        verifiedName: '',
      };
    }

    const providerRef = `SANDBOX_NIN_OK_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const verifiedName = `${firstName.toUpperCase().trim()} ${lastName.toUpperCase().trim()}`;

    return {
      success: true,
      providerRef,
      verifiedName,
    };
  }

  async verifyFace(
    selfieBase64: string,
    providerRef: string,
  ): Promise<LivenessResult> {
    return {
      success: true,
      livenessScore: 99.2,
      matchScore: 97.8,
      providerRef: `SANDBOX_FACE_${providerRef}_${Date.now()}`,
    };
  }

  async verifyDocument(
    documentType: string,
    docNumber: string,
  ): Promise<DocumentVerificationResult> {
    const masked = docNumber.length > 4
      ? `${docNumber.slice(0, 2)}****${docNumber.slice(-2)}`
      : '****';

    return {
      success: true,
      providerRef: `SANDBOX_DOC_${documentType}_${Date.now()}`,
      verifiedDetails: {
        documentType,
        docNumberMasked: masked,
        fullName: 'VERIFIED CITIZEN',
      },
    };
  }
}
