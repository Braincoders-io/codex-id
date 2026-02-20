import { Injectable, Logger } from "@nestjs/common";
import { BlockchainService } from "../blockchain/blockchain.service";
import { SupabaseService } from "./supabase.service";
import { CreateIdentityDto } from "./dto/create-identity.dto";

@Injectable()
export class IdentityService {
  private readonly logger = new Logger(IdentityService.name);

  constructor(
    private readonly blockchainService: BlockchainService,
    private readonly supabaseService: SupabaseService,
  ) {}

  async createIdentity(dto: CreateIdentityDto) {
    const documentHash = this.blockchainService.hashDocument(dto.documentContent);
    const schemaId = this.blockchainService.getSchemaId(dto.schemaName);

    this.logger.log(`Creating attestation for ${dto.subjectAddress}`);

    const result = await this.blockchainService.createAttestation(
      dto.subjectAddress,
      documentHash,
      schemaId,
      dto.expiresAt,
    );

    await this.supabaseService.storeIdentityRecord({
      subjectAddress: dto.subjectAddress,
      attestationId: result.attestationId,
      documentHash,
      schemaId,
      transactionHash: result.transactionHash,
      expiresAt: new Date(dto.expiresAt * 1000).toISOString(),
    });

    this.logger.log(`Attestation created: ${result.attestationId}`);

    return {
      attestationId: result.attestationId,
      transactionHash: result.transactionHash,
      blockNumber: result.blockNumber,
      documentHash,
    };
  }

  async revokeIdentity(attestationId: string) {
    this.logger.log(`Revoking attestation: ${attestationId}`);
    const txHash = await this.blockchainService.revokeAttestation(attestationId);
    return { attestationId, transactionHash: txHash, revoked: true };
  }

  async verifyIdentity(attestationId: string) {
    const isValid = await this.blockchainService.verifyAttestation(attestationId);
    const record = await this.supabaseService.getIdentityByAttestation(attestationId);
    return { attestationId, valid: isValid, record };
  }

  async getIdentitiesBySubject(subjectAddress: string) {
    return this.supabaseService.getIdentityBySubject(subjectAddress);
  }
}
