export interface SquadDefinitionModel {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  agentSlugs: string[];
  createdAt: string;
}

export function squadDefinitionFromRow(row: {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  agent_slugs: string[] | null;
  created_at: string;
}): SquadDefinitionModel {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    description: row.description,
    agentSlugs: row.agent_slugs ?? [],
    createdAt: row.created_at,
  };
}
