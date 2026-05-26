import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });

  try {
    const { squad_slug, user_message, organization_id } = await req.json();
    if (!squad_slug || !user_message) {
      return new Response(JSON.stringify({ error: "squad_slug e user_message são obrigatórios" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: squad, error: squadError } = await supabase
      .from("squad_definitions")
      .select("slug, name")
      .eq("slug", squad_slug)
      .single();

    if (squadError || !squad) {
      return new Response(JSON.stringify({ error: `Squad '${squad_slug}' não encontrada` }), {
        status: 404,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }

    const { data: run, error: runError } = await supabase
      .from("squad_runs")
      .insert({
        squad_slug: squad.slug,
        squad_name: squad.name,
        initial_prompt: user_message,
        status: "running",
        ...(organization_id ? { organization_id } : {}),
      })
      .select("id, squad_slug, squad_name, initial_prompt, status, created_at, completed_at")
      .single();

    if (runError || !run) throw runError ?? new Error("Erro ao criar run");

    return new Response(JSON.stringify({ run }), {
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  }
});
