export interface ModuleModel {
  id: string;
  slug: string;
  name: string;
  content: string | null;
  moduleRef: string;
  createdAt: string;
  updatedAt: string;
}

export function moduleFromRow(row: {
  id: string;
  slug: string;
  name: string;
  content?: string | null;
  module_ref: string;
  created_at: string;
  updated_at: string;
}): ModuleModel {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    content: row.content ?? null,
    moduleRef: row.module_ref,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
