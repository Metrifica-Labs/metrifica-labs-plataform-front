import { createClient } from "@supabase/supabase-js";
import { env } from "@/core/env";

export const supabase = createClient(env.supabaseUrl, env.supabaseAnonKey);
