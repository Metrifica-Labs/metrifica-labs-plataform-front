import { createClient } from "jsr:@supabase/supabase-js@2";
import { getComposioClient, syncInstagramIdentity } from "../_shared/composio-client.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Authorization é obrigatório" }),
        { status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // RLS (user_id = auth.uid()) garante que só lemos/atualizamos a conexão
    // do próprio usuário autenticado.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Usuário não autenticado" }),
        { status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    const { data: connection, error: connError } = await supabase
      .from("instagram_connections")
      .select("composio_connected_account_id, status")
      .eq("user_id", user.id)
      .maybeSingle();

    if (connError || !connection?.composio_connected_account_id) {
      return new Response(
        JSON.stringify({ status: "none" }),
        { headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    const composio = getComposioClient();
    const account = await composio.connectedAccounts.get(
      connection.composio_connected_account_id,
    );

    if (account.status !== "ACTIVE") {
      await supabase
        .from("instagram_connections")
        .update({ status: account.status === "FAILED" ? "error" : "pending" })
        .eq("user_id", user.id);

      return new Response(
        JSON.stringify({ status: account.status }),
        { headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Conexão ativa — resolve o ig_user_id/username da própria conta autenticada.
    const { igUsername } = await syncInstagramIdentity(composio, supabase, user.id);

    return new Response(
      JSON.stringify({ status: "active", ig_username: igUsername }),
      { headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Erro interno";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }
});
