export interface ProposalTemplateModel {
  id: string;
  slug: string;
  name: string;
  content: string | null;
  promptScaffold: string | null;
  flowSlug: string | null;
  createdAt: string;
  updatedAt: string;
}

export function proposalTemplateFromRow(row: {
  id: string;
  slug: string;
  name: string;
  content: string | null;
  prompt_scaffold: string | null;
  flow_slug: string | null;
  created_at: string;
  updated_at: string;
}): ProposalTemplateModel {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    content: row.content,
    promptScaffold: row.prompt_scaffold,
    flowSlug: row.flow_slug,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
