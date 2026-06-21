import { createClient } from "jsr:@supabase/supabase-js@2";
import { publishInstagramPost } from "../_shared/instagram-publisher.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Disparado pelo pg_cron (migration 20260621220100_instagram_publish_cron.sql)
// a cada minuto. Não recebe nenhum parâmetro do chamador — só varre o banco
// e publica o que já está vencido, então não há superfície para um chamador
// externo manipular qual post é publicado ou em nome de quem.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: duePosts, error } = await supabase
      .from("posts")
      .select("id")
      .eq("status", "scheduled")
      .eq("flow_slug", "instagram-text-post")
      .lte("scheduled_at", new Date().toISOString())
      .limit(20);

    if (error) throw error;

    const results = [];
    for (const post of duePosts ?? []) {
      const result = await publishInstagramPost(supabase, post.id);
      results.push({ post_id: post.id, ...result });
    }

    return new Response(
      JSON.stringify({ processed: results.length, results }),
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
