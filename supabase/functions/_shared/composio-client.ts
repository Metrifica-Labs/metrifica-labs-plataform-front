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
