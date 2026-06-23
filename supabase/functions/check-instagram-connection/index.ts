import { createClient } from "jsr:@supabase/supabase-js@2";
import { getComposioClient, syncInstagramHandle } from "../_shared/composio-client.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Authorization é obrigatório" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Usuário não autenticado" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const { data: conn } = await supabase
      .from("instagram_connections")
      .select("composio_entity_id, status, instagram_handle, error_message, updated_at")
      .eq("user_id", user.id)
      .maybeSingle();

    // Sem registro ou já ativo — devolve estado do DB diretamente
    if (!conn?.composio_entity_id || conn.status === "active") {
      return new Response(JSON.stringify(conn ?? null), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // Pendente/erro — consulta Composio pra ver se mudou
    const composio = getComposioClient();
    const account = await composio.connectedAccounts.get(conn.composio_entity_id);

    if (account.status === "ACTIVE") {
      const handle = await syncInstagramHandle(composio, supabase, user.id);
      return new Response(
        JSON.stringify({ ...conn, status: "active", instagram_handle: handle }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (account.status === "FAILED") {
      await supabase
        .from("instagram_connections")
        .update({ status: "error", error_message: "Autorização falhou no Instagram" })
        .eq("user_id", user.id);
      return new Response(
        JSON.stringify({ ...conn, status: "error" }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify(conn), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[check-instagram-connection]", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
