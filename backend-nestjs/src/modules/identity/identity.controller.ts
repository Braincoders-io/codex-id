import { Controller, Post, Get, Delete, Body, Param } from "@nestjs/common";
import { IdentityService } from "./identity.service";
import { CreateIdentityDto } from "./dto/create-identity.dto";

@Controller("identity")
export class IdentityController {
  constructor(private readonly identityService: IdentityService) {}

  @Post()
  async create(@Body() dto: CreateIdentityDto) {
    return this.identityService.createIdentity(dto);
  }

  @Delete(":attestationId")
  async revoke(@Param("attestationId") attestationId: string) {
    return this.identityService.revokeIdentity(attestationId);
  }

  @Get("verify/:attestationId")
  async verify(@Param("attestationId") attestationId: string) {
    return this.identityService.verifyIdentity(attestationId);
  }

  @Get("subject/:address")
  async getBySubject(@Param("address") address: string) {
    return this.identityService.getIdentitiesBySubject(address);
  }
}
