import { createClient } from "jsr:@supabase/supabase-js@2";
import { getComposioClient } from "../_shared/composio-client.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function createMediaContainer(
  // deno-lint-ignore no-explicit-any
  composio: any,
  userId: string,
  args: Record<string, unknown>,
): Promise<string> {
  const result = await composio.tools.execute("INSTAGRAM_POST_IG_USER_MEDIA", {
    userId,
    arguments: args,
    dangerouslySkipVersionCheck: true,
  });
  if (!result.successful) throw new Error(JSON.stringify(result.error ?? result.data));
  const data = result.data as Record<string, unknown> | undefined;
  const id = data?.id ?? data?.creation_id;
  if (!id) throw new Error("Composio não retornou id do container");
  return String(id);
}

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

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Usuário não autenticado" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const storagePaths: string[] = body.storagePaths;
    if (!storagePaths?.length) {
      return new Response(JSON.stringify({ error: "storagePaths obrigatório" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const { data: conn } = await supabase
      .from("instagram_connections")
      .select("composio_entity_id, status")
      .eq("user_id", user.id)
      .single();

    if (!conn || conn.status !== "active") {
      return new Response(JSON.stringify({ error: "Conexão Instagram não está ativa" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // Gera URLs assinadas (1h) para os slides no storage
    const admin = createClient(supabaseUrl, serviceKey);
    const signedUrls: string[] = [];
    for (const path of storagePaths) {
      const { data, error } = await admin.storage
        .from("instagram-publish-media")
        .createSignedUrl(path, 3600);
      if (error || !data?.signedUrl) {
        throw new Error(`URL assinada falhou para ${path}: ${error?.message}`);
      }
      signedUrls.push(data.signedUrl);
    }

    const composio = getComposioClient();
    const userId = conn.composio_entity_id;

    let containerId: string;
    if (signedUrls.length > 1) {
      const childIds: string[] = [];
      for (const url of signedUrls.slice(0, 10)) {
        const childId = await createMediaContainer(composio, userId, {
          ig_user_id: "me",
          image_url: url,
          is_carousel_item: true,
        });
        childIds.push(childId);
      }
      containerId = await createMediaContainer(composio, userId, {
        ig_user_id: "me",
        media_type: "CAROUSEL",
        children: childIds,
        caption: "",
      });
    } else {
      containerId = await createMediaContainer(composio, userId, {
        ig_user_id: "me",
        image_url: signedUrls[0],
        caption: "",
      });
    }

    const publishResult = await composio.tools.execute("INSTAGRAM_POST_IG_USER_MEDIA_PUBLISH", {
      userId,
      arguments: { ig_user_id: "me", creation_id: containerId },
      dangerouslySkipVersionCheck: true,
    });

    if (!publishResult.successful) {
      throw new Error(JSON.stringify(publishResult.error ?? publishResult.data));
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[publish-instagram-post]", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
