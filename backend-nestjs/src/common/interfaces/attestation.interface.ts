export interface AttestationResult {
  attestationId: string;
  transactionHash: string;
  blockNumber: number;
}

export interface AttestationData {
  issuer: string;
  subject: string;
  documentHash: string;
  schemaId: string;
  createdAt: number;
  expiresAt: number;
  revoked: boolean;
}
