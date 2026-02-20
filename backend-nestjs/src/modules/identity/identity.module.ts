import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { BlockchainModule } from "../blockchain/blockchain.module";
import { IdentityService } from "./identity.service";
import { IdentityController } from "./identity.controller";
import { SupabaseService } from "./supabase.service";

@Module({
  imports: [ConfigModule, BlockchainModule],
  controllers: [IdentityController],
  providers: [IdentityService, SupabaseService],
  exports: [IdentityService],
})
export class IdentityModule {}
