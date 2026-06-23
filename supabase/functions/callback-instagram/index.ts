import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const userId = url.searchParams.get("userId");
  const error = url.searchParams.get("error");

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const siteUrl = Deno.env.get("SITE_URL") ?? "https://app.metrifica.com.br";

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  if (!userId) {
    return new Response("userId ausente no callback", { status: 400 });
  }

  if (error) {
    await supabase
      .from("instagram_connections")
      .update({ status: "error", error_message: error })
      .eq("user_id", userId);

    return new Response(null, {
      status: 302,
      headers: { Location: `${siteUrl}/instagram-post?connection=error` },
    });
  }

  // Marca conexão como ativa — o Composio gerencia o token internamente
  await supabase
    .from("instagram_connections")
    .update({
      status: "active",
      instagram_handle: null,
      error_message: null,
    })
    .eq("user_id", userId);

  return new Response(null, {
    status: 302,
    headers: { Location: `${siteUrl}/instagram-post?connection=success` },
  });
});
