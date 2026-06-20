export type AgentRunStatus = "pending" | "running" | "completed" | "failed";

export interface AgentRunModel {
  id: string;
  squadRunId: string;
  agentSlug: string;
  agentName: string;
  stepIndex: number;
  input: string;
  output: string | null;
  status: AgentRunStatus;
  startedAt: string | null;
  completedAt: string | null;
}

export function agentRunFromRow(row: {
  id: string;
  squad_run_id: string;
  agent_slug: string;
  agent_name: string;
  step_index: number;
  input: string;
  output: string | null;
  status: AgentRunStatus;
  started_at: string | null;
  completed_at: string | null;
}): AgentRunModel {
  return {
    id: row.id,
    squadRunId: row.squad_run_id,
    agentSlug: row.agent_slug,
    agentName: row.agent_name,
    stepIndex: row.step_index,
    input: row.input,
    output: row.output,
    status: row.status,
    startedAt: row.started_at,
    completedAt: row.completed_at,
  };
}
