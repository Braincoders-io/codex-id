import { registerAs } from "@nestjs/config";

export const supabaseConfig = registerAs("supabase", () => ({
  url: process.env.SUPABASE_URL,
  anonKey: process.env.SUPABASE_ANON_KEY,
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
}));
