import { Injectable, OnModuleInit, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

@Injectable()
export class SupabaseService implements OnModuleInit {
  private readonly logger = new Logger(SupabaseService.name);
  private client!: SupabaseClient;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const url = this.configService.get<string>("supabase.url");
    const serviceRoleKey = this.configService.get<string>("supabase.serviceRoleKey");

    if (url && serviceRoleKey) {
      this.client = createClient(url, serviceRoleKey);
      this.logger.log("Supabase client initialized");
    } else {
      this.logger.warn("Supabase credentials not configured");
    }
  }

  getClient(): SupabaseClient {
    return this.client;
  }

  async storeIdentityRecord(record: {
    subjectAddress: string;
    attestationId: string;
    documentHash: string;
    schemaId: string;
    transactionHash: string;
    expiresAt: string;
  }) {
    const { data, error } = await this.client
      .from("identity_records")
      .insert({
        subject_address: record.subjectAddress,
        attestation_id: record.attestationId,
        document_hash: record.documentHash,
        schema_id: record.schemaId,
        transaction_hash: record.transactionHash,
        expires_at: record.expiresAt,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  async getIdentityBySubject(subjectAddress: string) {
    const { data, error } = await this.client
      .from("identity_records")
      .select("*")
      .eq("subject_address", subjectAddress)
      .order("created_at", { ascending: false });

    if (error) throw error;
    return data;
  }

  async getIdentityByAttestation(attestationId: string) {
    const { data, error } = await this.client
      .from("identity_records")
      .select("*")
      .eq("attestation_id", attestationId)
      .single();

    if (error) throw error;
    return data;
  }
}
