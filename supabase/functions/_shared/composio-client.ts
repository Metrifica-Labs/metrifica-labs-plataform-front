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

export async function getInstagramAuthConfigId(composio: Composio): Promise<string> {
  if (instagramAuthConfigId) return instagramAuthConfigId;
  const configs = await composio.authConfigs.list({ toolkit: "instagram" });
  const config = configs.items.find((c) => c.status === "ENABLED") ?? configs.items[0];
  if (!config) throw new Error("Nenhum auth config do Instagram encontrado no Composio");
  instagramAuthConfigId = config.id;
  return config.id;
}

/**
 * Resolve o username da conta Instagram do usuário e atualiza instagram_connections.
 * Schema desta branch: instagram_handle (TEXT), sem ig_user_id.
 */
export async function syncInstagramHandle(
  composio: Composio,
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
): Promise<string | null> {
  let igHandle: string | null = null;
  try {
    const info = await composio.tools.execute("INSTAGRAM_GET_USER_INFO", {
      userId,
      arguments: { ig_user_id: "me" },
      dangerouslySkipVersionCheck: true,
    });
    const data = info.data as Record<string, unknown> | undefined;
    igHandle = (data?.username as string | undefined) ?? null;
  } catch {
    // segue sem handle; erro aparece ao tentar publicar
  }

  await supabase
    .from("instagram_connections")
    .update({ status: "active", instagram_handle: igHandle, error_message: null })
    .eq("user_id", userId);

  return igHandle;
}
