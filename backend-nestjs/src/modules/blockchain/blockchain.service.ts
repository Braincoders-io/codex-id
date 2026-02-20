import { Injectable, OnModuleInit, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { ethers } from "ethers";
import { AttestationResult } from "../../common/interfaces/attestation.interface";

const CODEX_IDENTITY_ABI = [
  "function createAttestation(address subject, bytes32 documentHash, bytes32 schemaId, uint64 expiresAt) external returns (bytes32)",
  "function revokeAttestation(bytes32 attestationId) external",
  "function verifyAttestation(bytes32 attestationId) external view returns (bool)",
  "function getAttestation(bytes32 attestationId) external view returns (address, address, bytes32, bytes32, uint64, uint64, bool)",
  "event AttestationCreated(bytes32 indexed attestationId, address indexed subject, address indexed issuer, bytes32 documentHash, uint64 expiresAt)",
  "event AttestationRevoked(bytes32 indexed attestationId, address indexed revokedBy, uint64 revokedAt)",
];

@Injectable()
export class BlockchainService implements OnModuleInit {
  private readonly logger = new Logger(BlockchainService.name);
  private provider!: ethers.JsonRpcProvider;
  private signer!: ethers.Wallet;
  private contract!: ethers.Contract;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const rpcUrl = this.configService.get<string>("blockchain.rpcUrl")!;
    const chainId = this.configService.get<number>("blockchain.chainId")!;
    const privateKey = this.configService.get<string>("blockchain.signerPrivateKey");
    const contractAddress = this.configService.get<string>("blockchain.codexIdentityAddress");

    this.provider = new ethers.JsonRpcProvider(rpcUrl, chainId);

    if (privateKey && contractAddress) {
      this.signer = new ethers.Wallet(privateKey, this.provider);
      this.contract = new ethers.Contract(contractAddress, CODEX_IDENTITY_ABI, this.signer);
      this.logger.log(`Connected to CodexIdentity at ${contractAddress} on chain ${chainId}`);
    } else {
      this.logger.warn("Blockchain signer or contract address not configured");
    }
  }

  async createAttestation(
    subjectAddress: string,
    documentHash: string,
    schemaId: string,
    expiresAt: number,
  ): Promise<AttestationResult> {
    const tx = await this.contract.createAttestation(
      subjectAddress,
      documentHash,
      schemaId,
      expiresAt,
    );

    const receipt = await tx.wait();
    const iface = new ethers.Interface(CODEX_IDENTITY_ABI);
    const log = receipt.logs.find(
      (l: ethers.Log) => l.topics[0] === iface.getEvent("AttestationCreated")!.topicHash,
    );

    const parsed = iface.parseLog({ topics: log.topics, data: log.data });

    return {
      attestationId: parsed!.args.attestationId,
      transactionHash: receipt.hash,
      blockNumber: receipt.blockNumber,
    };
  }

  async revokeAttestation(attestationId: string): Promise<string> {
    const tx = await this.contract.revokeAttestation(attestationId);
    const receipt = await tx.wait();
    return receipt.hash;
  }

  async verifyAttestation(attestationId: string): Promise<boolean> {
    return this.contract.verifyAttestation(attestationId);
  }

  hashDocument(content: string): string {
    return ethers.keccak256(ethers.toUtf8Bytes(content));
  }

  getSchemaId(schemaName: string): string {
    return ethers.keccak256(ethers.toUtf8Bytes(schemaName));
  }
}
