import { createClient } from "jsr:@supabase/supabase-js@2";
import { getComposioClient, getInstagramAuthConfigId } from "../_shared/composio-client.ts";

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

    // Cliente com a identidade do usuário chamador — toda leitura/escrita em
    // instagram_connections passa pela RLS (user_id = auth.uid()), nunca
    // aceitamos um user_id vindo do corpo da requisição.
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

    const composio = getComposioClient();
    const authConfigId = await getInstagramAuthConfigId(composio);

    // Evita o erro "Multiple connected accounts found" do Composio: cada
    // clique em "Conectar" antes da autorização terminar cria uma nova
    // connected account pendente para o mesmo usuário+authConfig. Antes de
    // pedir um novo link, reaproveita uma conexão ACTIVE existente e limpa
    // as que ficaram penduradas (INITIATED/FAILED) sem nunca virar ACTIVE.
    const existing = await composio.connectedAccounts.list({
      userIds: [user.id],
      authConfigIds: [authConfigId],
    });

    const activeAccount = existing.items.find((acc) => acc.status === "ACTIVE");
    if (activeAccount) {
      await supabase.from("instagram_connections").upsert(
        {
          user_id: user.id,
          composio_connected_account_id: activeAccount.id,
          status: "active",
          status_reason: null,
        },
        { onConflict: "user_id" },
      );
      return new Response(
        JSON.stringify({ already_active: true }),
        { headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    for (const stale of existing.items) {
      await composio.connectedAccounts.delete(stale.id).catch(() => {});
    }

    const connectionRequest = await composio.connectedAccounts.link(user.id, authConfigId);

    await supabase.from("instagram_connections").upsert(
      {
        user_id: user.id,
        composio_connected_account_id: connectionRequest.id,
        status: "pending",
        status_reason: null,
      },
      { onConflict: "user_id" },
    );

    return new Response(
      JSON.stringify({
        redirect_url: connectionRequest.redirectUrl,
        connection_id: connectionRequest.id,
      }),
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
