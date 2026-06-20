export interface N3Card {
  card: number;
  objetivo: string;
  headline: string;
  body: string;
}

export function n3CardFromJson(json: Record<string, unknown>): N3Card {
  return {
    card: (json.card as number) ?? 0,
    objetivo: (json.objetivo as string) ?? "",
    headline: (json.headline as string) ?? "",
    body: (json.body as string) ?? "",
  };
}

export type N3PostType = "post1" | "post2" | "post3" | "post10";

export const N3_POST_TYPES: Record<N3PostType, { label: string; name: string }> = {
  post1: { label: "1/9", name: "O Método" },
  post2: { label: "2/9", name: "A Vida Após" },
  post3: { label: "3/9", name: "O Contraponto" },
  post10: { label: "10/9", name: "Aplicação Real" },
};

export interface N3Post {
  postType: N3PostType;
  cards: N3Card[];
}

export function parseN3Post(output: string, defaultType: N3PostType = "post1"): N3Post {
  try {
    const match = output.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
    const jsonStr = match?.[1] ?? output.trim();
    const decoded = JSON.parse(jsonStr) as { post_type?: string; cards?: Record<string, unknown>[] };

    const postTypeStr = decoded.post_type ?? N3_POST_TYPES[defaultType].label;
    const postType =
      (Object.entries(N3_POST_TYPES).find(([, v]) => v.label === postTypeStr)?.[0] as N3PostType) ?? defaultType;

    const cards = (decoded.cards ?? []).map(n3CardFromJson);
    return { postType, cards };
  } catch {
    return { postType: defaultType, cards: [] };
  }
}
