import { createClient } from "jsr:@supabase/supabase-js@2";
import { publishInstagramPost } from "../_shared/instagram-publisher.ts";

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

    const { post_id } = await req.json();
    if (!post_id || typeof post_id !== "string") {
      return new Response(
        JSON.stringify({ error: "post_id é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Identifica o usuário pelo JWT (nunca por um campo do corpo).
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await authClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Usuário não autenticado" }),
        { status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Service role para a lógica de publish (precisa ler instagram_connections
    // e atualizar posts independentemente da RLS org-wide de `posts`), mas
    // antes disso validamos manualmente que o post pertence ao usuário —
    // a RLS de `posts` é por organização, não por autor, então sem essa
    // checagem outro membro da org poderia publicar usando a conexão de
    // quem criou o post.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: post, error: postError } = await supabase
      .from("posts")
      .select("id, created_by")
      .eq("id", post_id)
      .single();

    if (postError || !post) {
      return new Response(
        JSON.stringify({ error: "Post não encontrado" }),
        { status: 404, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    if (post.created_by !== user.id) {
      return new Response(
        JSON.stringify({ error: "Você só pode publicar posts criados por você" }),
        { status: 403, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    const result = await publishInstagramPost(supabase, post_id);

    return new Response(
      JSON.stringify(result),
      {
        status: result.ok ? 200 : 422,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Erro interno";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }
});
