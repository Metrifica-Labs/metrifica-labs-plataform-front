export interface PersonaModel {
  id: string;
  orgId: string;
  name: string;
  content: string;
  createdAt: string;
  updatedAt: string;
}

export function personaFromRow(row: {
  id: string;
  org_id: string;
  name: string;
  content: string | null;
  created_at: string;
  updated_at: string;
}): PersonaModel {
  return {
    id: row.id,
    orgId: row.org_id,
    name: row.name,
    content: row.content ?? "",
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
