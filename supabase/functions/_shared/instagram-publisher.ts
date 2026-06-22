import { getComposioClient } from "./composio-client.ts";

export interface PublishResult {
  ok: boolean;
  error?: string;
}

async function createMediaContainer(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  composio: any,
  userId: string,
  args: Record<string, unknown>,
): Promise<string> {
  const result = await composio.tools.execute("INSTAGRAM_POST_IG_USER_MEDIA", {
    userId,
    arguments: args,
    dangerouslySkipVersionCheck: true,
  });

  if (!result.successful) {
    throw new Error(JSON.stringify(result.error ?? result.data));
  }

  const data = result.data as Record<string, unknown> | undefined;
  const containerId = data?.id ?? data?.creation_id;
  if (!containerId) throw new Error("Composio não retornou o id do container de mídia");
  return String(containerId);
}

/**
 * Publica um post no Instagram via Composio. Se houver mais de uma imagem
 * (carrossel de slides), cria um container filho por imagem e um container
 * pai do tipo CAROUSEL referenciando os filhos; senão publica imagem única.
 * A conexão usada é sempre a do `created_by` do post — nunca a de outro
 * usuário, mesmo na mesma organização.
 */
export async function publishInstagramPost(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  supabase: any,
  postId: string,
): Promise<PublishResult> {
  const { data: post, error: postError } = await supabase
    .from("posts")
    .select("id, content, image_url, image_urls, created_by, status")
    .eq("id", postId)
    .single();

  if (postError || !post) return { ok: false, error: "Post não encontrado" };
  if (!post.created_by) return { ok: false, error: "Post sem autor (created_by)" };

  const imageUrls: string[] =
    (post.image_urls as string[] | null)?.filter(Boolean) ??
    (post.image_url ? [post.image_url] : []);
  if (imageUrls.length === 0) return { ok: false, error: "Post sem imagem para publicar" };

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
  const igUserId: string = connection.ig_user_id;

  try {
    let containerId: string;

    if (imageUrls.length > 1) {
      // Carrossel: 1 container filho por imagem (máx. 10 no Instagram),
      // depois um container pai CAROUSEL referenciando os filhos.
      const childIds: string[] = [];
      for (const url of imageUrls.slice(0, 10)) {
        const childId = await createMediaContainer(composio, userId, {
          ig_user_id: igUserId,
          image_url: url,
          is_carousel_item: true,
        });
        childIds.push(childId);
      }

      containerId = await createMediaContainer(composio, userId, {
        ig_user_id: igUserId,
        media_type: "CAROUSEL",
        children: childIds,
        caption: post.content,
      });
    } else {
      containerId = await createMediaContainer(composio, userId, {
        ig_user_id: igUserId,
        image_url: imageUrls[0],
        caption: post.content,
      });
    }

    await supabase
      .from("posts")
      .update({ composio_container_id: containerId })
      .eq("id", postId);

    const publishResult = await composio.tools.execute(
      "INSTAGRAM_POST_IG_USER_MEDIA_PUBLISH",
      {
        userId,
        arguments: {
          ig_user_id: igUserId,
          creation_id: containerId,
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
