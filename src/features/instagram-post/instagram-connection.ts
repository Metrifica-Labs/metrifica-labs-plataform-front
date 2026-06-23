import { supabase } from "@/core/supabase/client";
import { edgeFunctionUrl } from "@/core/sse/sse-client";
import { env } from "@/core/env";

export type ConnectionStatus = "none" | "pending" | "active" | "error";

export interface InstagramConnection {
  id: string;
  userId: string;
  status: ConnectionStatus;
  instagramHandle: string | null;
  errorMessage: string | null;
  updatedAt: string;
}

export async function fetchInstagramConnection(_userId: string): Promise<InstagramConnection | null> {
  const headers = await authHeaders();
  const res = await fetch(edgeFunctionUrl("check-instagram-connection"), { headers });
  if (!res.ok) {
    // fallback: leitura direta do DB se a edge function falhar
    const { data, error } = await supabase
      .from("instagram_connections")
      .select("id, user_id, status, instagram_handle, error_message, updated_at")
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    return mapRow(data);
  }
  const data = await res.json();
  if (!data) return null;
  return mapRow(data);
}

function mapRow(data: Record<string, unknown>): InstagramConnection {
  return {
    id: data.id as string,
    userId: data.user_id as string,
    status: data.status as ConnectionStatus,
    instagramHandle: data.instagram_handle as string | null,
    errorMessage: data.error_message as string | null,
    updatedAt: data.updated_at as string,
  };
}

async function authHeaders(): Promise<Record<string, string>> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token ?? env.supabaseAnonKey;
  return {
    Authorization: `Bearer ${token}`,
    apikey: env.supabaseAnonKey,
    "Content-Type": "application/json",
  };
}

export async function initiateInstagramConnection(): Promise<string> {
  const headers = await authHeaders();
  const res = await fetch(edgeFunctionUrl("connect-instagram"), {
    method: "POST",
    headers,
  });
  if (!res.ok) {
    const msg = await res.text().catch(() => res.status.toString());
    throw new Error(`Falha ao iniciar conexão: ${msg}`);
  }
  const json = (await res.json()) as { redirectUrl: string };
  return json.redirectUrl;
}

export async function disconnectInstagram(connectionId: string): Promise<void> {
  const { error } = await supabase
    .from("instagram_connections")
    .delete()
    .eq("id", connectionId);
  if (error) throw error;
}
