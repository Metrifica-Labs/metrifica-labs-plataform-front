import { supabase } from "@/core/supabase/client";
import { squadRunFromRow, type SquadRunModel } from "@/core/models/squad-run";
import { agentRunFromRow, type AgentRunModel } from "@/core/models/agent-run";
import { edgeFunctionUrl } from "@/core/sse/sse-client";
import { env } from "@/core/env";

const headers = {
  Authorization: `Bearer ${env.supabaseAnonKey}`,
  apikey: env.supabaseAnonKey,
  "Content-Type": "application/json",
};

export async function startSquadRun(params: {
  squadSlug: string;
  userMessage: string;
  organizationId?: string | null;
}): Promise<SquadRunModel> {
  const res = await fetch(edgeFunctionUrl("start-squad-run"), {
    method: "POST",
    headers,
    body: JSON.stringify({
      squad_slug: params.squadSlug,
      user_message: params.userMessage,
      ...(params.organizationId ? { organization_id: params.organizationId } : {}),
    }),
  });
  if (!res.ok) throw new Error(`Erro ${res.status}: ${await res.text()}`);
  const json = await res.json();
  return squadRunFromRow(json.run);
}

export async function queueSquadStep(runId: string): Promise<void> {
  const res = await fetch(edgeFunctionUrl("run-squad-step"), {
    method: "POST",
    headers,
    body: JSON.stringify({ run_id: runId }),
  });
  if (!res.ok) throw new Error(`Erro ao agendar etapa ${res.status}: ${await res.text()}`);
}

export interface SquadSnapshot {
  run: SquadRunModel;
  agentRuns: AgentRunModel[];
}

export async function fetchSquadSnapshot(runId: string): Promise<SquadSnapshot> {
  const { data: runRow, error: runError } = await supabase
    .from("squad_runs")
    .select("*")
    .eq("id", runId)
    .single();
  if (runError) throw runError;

  const { data: agentRows, error: agentError } = await supabase
    .from("agent_runs")
    .select("*")
    .eq("squad_run_id", runId)
    .order("step_index");
  if (agentError) throw agentError;

  return {
    run: squadRunFromRow(runRow),
    agentRuns: agentRows.map(agentRunFromRow),
  };
}
