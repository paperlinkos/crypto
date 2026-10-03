import { Injectable, NotImplementedException } from '@nestjs/common';
import {
  IKycProvider,
  BvnVerificationResult,
  NinVerificationResult,
  LivenessResult,
  DocumentVerificationResult,
} from '../interfaces/kyc-provider.interface';

/**
 * Production KYC Verification Adapter
 *
 * Supported Vendors:
 * 1. Smile Identity (Pan-Africa Biometric KYC & BVN/NIN): https://docs.usesmileid.com/
 * 2. Dojah KYC & Verification API: https://docs.dojah.io/
 * 3. Prembly (Identitypass): https://docs.prembly.com/
 *
 * Privacy Rule:
 * In compliance with Rule #5, raw selfie photos or unmasked ID scans must never
 * be stored in our database. Store only the vendor's immutable verification token / provider reference.
 */
@Injectable()
export class ProductionKycProvider implements IKycProvider {
  async verifyBvn(
    bvn: string,
    firstName: string,
    lastName: string,
    dob?: string,
  ): Promise<BvnVerificationResult> {
    // TODO: Call SmileID or Dojah BVN Lookup API
    throw new NotImplementedException(
      'ProductionKycProvider: Real API keys not configured. Switch KYC_PROVIDER_MODE=sandbox in development.',
    );
  }

  async verifyNin(
    nin: string,
    firstName: string,
    lastName: string,
  ): Promise<NinVerificationResult> {
    throw new NotImplementedException(
      'ProductionKycProvider: Real API keys not configured.',
    );
  }

  async verifyFace(
    selfieBase64: string,
    providerRef: string,
  ): Promise<LivenessResult> {
    throw new NotImplementedException(
      'ProductionKycProvider: Real API keys not configured.',
    );
  }

  async verifyDocument(
    documentType: string,
    docNumber: string,
    docImageBase64?: string,
  ): Promise<DocumentVerificationResult> {
    throw new NotImplementedException(
      'ProductionKycProvider: Real API keys not configured.',
    );
  }
}
