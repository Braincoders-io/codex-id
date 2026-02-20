import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { IdentityModule } from "./modules/identity/identity.module";
import { BlockchainModule } from "./modules/blockchain/blockchain.module";
import { supabaseConfig } from "./config/supabase.config";
import { blockchainConfig } from "./config/blockchain.config";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [supabaseConfig, blockchainConfig],
      envFilePath: ".env",
    }),
    IdentityModule,
    BlockchainModule,
  ],
})
export class AppModule {}
