import { getComposioClient } from "./composio-client.ts";

export interface PublishResult {
  ok: boolean;
  error?: string;
}

/**
 * Publica um post no Instagram via Composio (2 passos: cria o container de
 * mídia, depois publica). A conexão usada é sempre a do `created_by` do post
 * — nunca a de outro usuário, mesmo na mesma organização.
 */
export async function publishInstagramPost(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  supabase: any,
  postId: string,
): Promise<PublishResult> {
  const { data: post, error: postError } = await supabase
    .from("posts")
    .select("id, content, image_url, created_by, status")
    .eq("id", postId)
    .single();

  if (postError || !post) return { ok: false, error: "Post não encontrado" };
  if (!post.created_by) return { ok: false, error: "Post sem autor (created_by)" };
  if (!post.image_url) return { ok: false, error: "Post sem imagem para publicar" };

  const { data: connection, error: connError } = await supabase
    .from("instagram_connections")
    .select("user_id, ig_user_id, status")
    .eq("user_id", post.created_by)
    .single();

  if (connError || !connection || connection.status !== "active") {
    return { ok: false, error: "Usuário sem conexão Instagram ativa" };
  }
  if (!connection.ig_user_id) {
    return { ok: false, error: "Conexão Instagram sem ig_user_id resolvido" };
  }

  const composio = getComposioClient();
  const userId: string = connection.user_id;

  try {
    const containerResult = await composio.tools.execute("INSTAGRAM_POST_IG_USER_MEDIA", {
      userId,
      arguments: {
        ig_user_id: connection.ig_user_id,
        image_url: post.image_url,
        caption: post.content,
      },
      dangerouslySkipVersionCheck: true,
    });

    if (!containerResult.successful) {
      throw new Error(JSON.stringify(containerResult.error ?? containerResult.data));
    }

    const containerData = containerResult.data as Record<string, unknown> | undefined;
    const containerId = containerData?.id ?? containerData?.creation_id;
    if (!containerId) throw new Error("Composio não retornou o id do container de mídia");

    await supabase
      .from("posts")
      .update({ composio_container_id: String(containerId) })
      .eq("id", postId);

    const publishResult = await composio.tools.execute(
      "INSTAGRAM_POST_IG_USER_MEDIA_PUBLISH",
      {
        userId,
        arguments: {
          ig_user_id: connection.ig_user_id,
          creation_id: String(containerId),
        },
        dangerouslySkipVersionCheck: true,
      },
    );

    if (!publishResult.successful) {
      throw new Error(JSON.stringify(publishResult.error ?? publishResult.data));
    }

    await supabase
      .from("posts")
      .update({ status: "published", publish_error: null })
      .eq("id", postId);

    return { ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await supabase.from("posts").update({ publish_error: message }).eq("id", postId);
    return { ok: false, error: message };
  }
}
