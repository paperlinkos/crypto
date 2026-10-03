export interface BvnVerificationResult {
  success: boolean;
  providerRef: string;
  verifiedName: string;
  confidenceScore: number;
}

export interface NinVerificationResult {
  success: boolean;
  providerRef: string;
  verifiedName: string;
}

export interface LivenessResult {
  success: boolean;
  livenessScore: number;
  matchScore: number;
  providerRef: string;
}

export interface DocumentVerificationResult {
  success: boolean;
  providerRef: string;
  verifiedDetails: {
    documentType: string;
    docNumberMasked: string;
    fullName: string;
  };
}

export interface IKycProvider {
  /**
   * Verifies an 11-digit Nigerian Bank Verification Number (BVN) with NIBSS / verification rails.
   */
  verifyBvn(
    bvn: string,
    firstName: string,
    lastName: string,
    dob?: string,
  ): Promise<BvnVerificationResult>;

  /**
   * Verifies an 11-digit Nigerian National Identity Number (NIN).
   */
  verifyNin(
    nin: string,
    firstName: string,
    lastName: string,
  ): Promise<NinVerificationResult>;

  /**
   * Verifies biometric facial liveness match against stored BVN/ID photo.
   */
  verifyFace(
    selfieBase64: string,
    providerRef: string,
  ): Promise<LivenessResult>;

  /**
   * Verifies government document (International Passport, Driver's License, National ID).
   */
  verifyDocument(
    documentType: string,
    docNumber: string,
    docImageBase64?: string,
  ): Promise<DocumentVerificationResult>;
}
