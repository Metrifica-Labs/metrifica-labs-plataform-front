export type SquadStatus = "idle" | "connecting" | "running" | "done" | "error";
export type AgentRunStatus = "pending" | "running" | "done" | "error";

export interface AgentRunState {
  agentSlug: string;
  agentName: string;
  step: number;
  status: AgentRunStatus;
  thinking: string;
  output: string;
}

export interface SquadState {
  status: SquadStatus;
  squadName: string | null;
  runId: string | null;
  initialPrompt: string | null;
  agentRuns: AgentRunState[];
  error: string | null;
}

export const initialSquadState: SquadState = {
  status: "idle",
  squadName: null,
  runId: null,
  initialPrompt: null,
  agentRuns: [],
  error: null,
};

export function isSquadRunning(status: SquadStatus): boolean {
  return status === "connecting" || status === "running";
}
