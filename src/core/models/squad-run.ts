export type SquadRunStatus = "pending" | "running" | "completed" | "failed";

export interface SquadRunModel {
  id: string;
  squadSlug: string;
  squadName: string | null;
  initialPrompt: string;
  status: SquadRunStatus;
  createdAt: string | null;
  completedAt: string | null;
}

export function squadRunFromRow(row: {
  id: string;
  squad_slug: string;
  squad_name: string | null;
  initial_prompt: string;
  status: SquadRunStatus;
  created_at: string | null;
  completed_at: string | null;
}): SquadRunModel {
  return {
    id: row.id,
    squadSlug: row.squad_slug,
    squadName: row.squad_name,
    initialPrompt: row.initial_prompt,
    status: row.status,
    createdAt: row.created_at,
    completedAt: row.completed_at,
  };
}
