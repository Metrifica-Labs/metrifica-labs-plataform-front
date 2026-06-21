import { Composio } from "npm:@composio/core";

let client: Composio | undefined;

export function getComposioClient(): Composio {
  if (!client) {
    const apiKey = Deno.env.get("COMPOSIO_API_KEY");
    if (!apiKey) throw new Error("COMPOSIO_API_KEY não configurado");
    client = new Composio({ apiKey });
  }
  return client;
}

let instagramAuthConfigId: string | undefined;

/**
 * O endpoint antigo de "initiate"/"authorize" não é mais suportado para auth
 * configs gerenciados pelo Composio — é preciso usar connectedAccounts.link()
 * com um authConfigId explícito. Esta função resolve (e cacheia) o
 * authConfigId do toolkit instagram já existente no projeto Composio.
 */
export async function getInstagramAuthConfigId(composio: Composio): Promise<string> {
  if (instagramAuthConfigId) return instagramAuthConfigId;

  const configs = await composio.authConfigs.list({ toolkit: "instagram" });
  const config = configs.items.find((c) => c.status === "ENABLED") ?? configs.items[0];
  if (!config) {
    throw new Error("Nenhum auth config do Instagram encontrado no projeto Composio");
  }

  instagramAuthConfigId = config.id;
  return config.id;
}

/**
 * Resolve o ig_user_id/username da conta do usuário (via INSTAGRAM_GET_USER_INFO,
 * ig_user_id="me") e grava em instagram_connections. Usado tanto quando uma
 * conexão acabou de virar ACTIVE quanto quando reaproveitamos uma já ativa.
 */
export async function syncInstagramIdentity(
  composio: Composio,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  supabase: any,
  userId: string,
): Promise<{ igUserId: string | null; igUsername: string | null }> {
  let igUserId: string | null = null;
  let igUsername: string | null = null;
  try {
    const info = await composio.tools.execute("INSTAGRAM_GET_USER_INFO", {
      userId,
      arguments: { ig_user_id: "me" },
      dangerouslySkipVersionCheck: true,
    });
    const infoData = info.data as Record<string, unknown> | undefined;
    igUserId = (infoData?.id as string | undefined) ?? null;
    igUsername = (infoData?.username as string | undefined) ?? null;
  } catch {
    // segue sem ig_user_id; o usuário verá o erro específico ao tentar publicar.
  }

  await supabase
    .from("instagram_connections")
    .update({
      status: "active",
      ig_user_id: igUserId,
      ig_username: igUsername,
      status_reason: null,
    })
    .eq("user_id", userId);

  return { igUserId, igUsername };
}
