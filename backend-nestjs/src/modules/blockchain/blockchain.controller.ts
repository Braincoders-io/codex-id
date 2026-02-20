import { Controller, Get, Param } from "@nestjs/common";
import { BlockchainService } from "./blockchain.service";

@Controller("blockchain")
export class BlockchainController {
  constructor(private readonly blockchainService: BlockchainService) {}

  @Get("verify/:attestationId")
  async verify(@Param("attestationId") attestationId: string) {
    const isValid = await this.blockchainService.verifyAttestation(attestationId);
    return { attestationId, valid: isValid };
  }

  @Get("hash/:content")
  hashDocument(@Param("content") content: string) {
    return { hash: this.blockchainService.hashDocument(content) };
  }
}
