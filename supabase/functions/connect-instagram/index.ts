import { createClient } from "jsr:@supabase/supabase-js@2";
import { getComposioClient, getInstagramAuthConfigId, syncInstagramHandle } from "../_shared/composio-client.ts";

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

    const composio = getComposioClient();
    const authConfigId = await getInstagramAuthConfigId(composio);

    // Reusa conta ativa existente sem criar nova
    const existing = await composio.connectedAccounts.list({
      userIds: [user.id],
      authConfigIds: [authConfigId],
    });

    const activeAccount = existing.items.find((acc) => acc.status === "ACTIVE");
    if (activeAccount) {
      await supabase.from("instagram_connections").upsert(
        { user_id: user.id, composio_entity_id: activeAccount.id, status: "active", error_message: null },
        { onConflict: "user_id" },
      );
      await syncInstagramHandle(composio, supabase, user.id);
      return new Response(JSON.stringify({ already_active: true }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // Limpa contas pendentes/falhas anteriores para evitar "Multiple connected accounts"
    for (const stale of existing.items) {
      await composio.connectedAccounts.delete(stale.id).catch(() => {});
    }

    const connectionRequest = await composio.connectedAccounts.link(user.id, authConfigId);

    await supabase.from("instagram_connections").upsert(
      {
        user_id: user.id,
        composio_entity_id: connectionRequest.id,
        status: "pending",
        error_message: null,
      },
      { onConflict: "user_id" },
    );

    return new Response(
      JSON.stringify({ redirectUrl: connectionRequest.redirectUrl }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[connect-instagram]", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
