export interface FlowModel {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  moduleSlugs: string[];
  createdAt: string;
}

function parseModuleSlugs(value: unknown): string[] {
  if (Array.isArray(value)) return value as string[];
  if (typeof value === "string") {
    return value
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
}

export function flowFromRow(row: {
  id: string;
  slug: string;
  name: string;
  description?: string | null;
  module_slugs?: unknown;
  created_at: string;
}): FlowModel {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    description: row.description ?? null,
    moduleSlugs: parseModuleSlugs(row.module_slugs),
    createdAt: row.created_at,
  };
}
