import { useRef, useState } from "react";
import {
  startSquadRun,
  queueSquadStep,
  fetchSquadSnapshot,
  type SquadSnapshot,
} from "@/features/squad/squad-run.repository";
import { initialSquadState, type AgentRunState, type SquadState } from "@/features/squad/squad-state";
import type { AgentRunModel } from "@/core/models/agent-run";
import type { SquadRunModel } from "@/core/models/squad-run";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function useSquadRun() {
  const [state, setState] = useState<SquadState>(initialSquadState);
  const cancelledRef = useRef(false);

  function applySnapshot(run: SquadRunModel, agentRuns: AgentRunModel[]) {
    const agents: AgentRunState[] = agentRuns.map((r) => ({
      agentSlug: r.agentSlug,
      agentName: r.agentName,
      step: r.stepIndex,
      status: r.status === "completed" ? "done" : r.status === "running" ? "running" : r.status === "failed" ? "error" : "pending",
      thinking:
        r.status === "running"
          ? "Executando em background. A página só acompanha o estado salvo; a geração não depende desta conexão."
          : "",
      output: r.output ?? "",
    }));

    setState((s) => ({
      ...s,
      status: run.status === "completed" ? "done" : run.status === "failed" ? "error" : "running",
      squadName: run.squadName,
      runId: run.id,
      initialPrompt: run.initialPrompt,
      agentRuns: agents,
      error: run.status === "failed" ? "Execução encerrada com erro." : null,
    }));
  }

  async function driveRun(runId: string) {
    let requestedStep = false;

    while (!cancelledRef.current) {
      let snapshot: SquadSnapshot;
      try {
        snapshot = await fetchSquadSnapshot(runId);
      } catch (e) {
        if (!cancelledRef.current) {
          setState((s) => ({ ...s, status: "error", error: e instanceof Error ? e.message : String(e) }));
        }
        return;
      }

      applySnapshot(snapshot.run, snapshot.agentRuns);

      if (snapshot.run.status === "completed" || snapshot.run.status === "failed") {
        return;
      }

      const hasRunningAgent = snapshot.agentRuns.some((a) => a.status === "running");
      if (!hasRunningAgent && !requestedStep) {
        requestedStep = true;
        try {
          await queueSquadStep(runId);
        } catch {
          // próximo loop tenta de novo
        }
      }
      if (hasRunningAgent) requestedStep = false;

      await sleep(hasRunningAgent ? 5000 : 3000);
    }
  }

  async function run(squadSlug: string, userMessage: string, organizationId?: string | null) {
    cancelledRef.current = false;
    setState({ ...initialSquadState, status: "connecting", initialPrompt: userMessage });

    try {
      const squadRun = await startSquadRun({ squadSlug, userMessage, organizationId });
      setState((s) => ({
        ...s,
        status: "running",
        squadName: squadRun.squadName,
        runId: squadRun.id,
        initialPrompt: squadRun.initialPrompt,
      }));
      await driveRun(squadRun.id);
    } catch (e) {
      if (!cancelledRef.current) {
        setState((s) => ({ ...s, status: "error", error: e instanceof Error ? e.message : String(e) }));
      }
    }
  }

  async function resume(runId: string) {
    cancelledRef.current = false;
    setState((s) => ({ ...s, status: "connecting", error: null }));
    await driveRun(runId);
  }

  function clear() {
    cancelledRef.current = true;
    setState(initialSquadState);
  }

  return { state, run, resume, clear };
}
