import { useState } from "react";
import { useParams } from "react-router-dom";
import { Send } from "lucide-react";
import { useSquadRun } from "@/features/squad/useSquadRun";
import { isSquadRunning } from "@/features/squad/squad-state";
import { useOrgStore } from "@/core/org/org-store";
import { Markdown } from "@/shared/components/Markdown";

export function SquadPage() {
  const { slug } = useParams<{ slug: string }>();
  const squad = useSquadRun();
  const [message, setMessage] = useState("");
  const activeOrgId = useOrgStore((s) => s.activeOrgId);

  function handleRun() {
    if (!slug || !message.trim()) return;
    void squad.run(slug, message, activeOrgId);
  }

  const running = isSquadRunning(squad.state.status);

  return (
    <div className="mx-auto max-w-2xl p-6">
      <h1 className="mb-1 text-lg font-semibold text-light-onSurface dark:text-white">
        {squad.state.squadName ?? slug}
      </h1>
      <p className="mb-4 text-xs text-light-onSurface/40 dark:text-white/30">
        Orquestração multi-agente
      </p>

      <textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder="Descreva a tarefa para a squad..."
        rows={3}
        disabled={running}
        className="mb-2 w-full rounded-md border border-light-border-strong bg-transparent p-3 text-sm outline-none focus:border-primary disabled:opacity-50 dark:border-dark-border"
      />
      <button
        onClick={handleRun}
        disabled={running || !message.trim()}
        className="mb-6 flex items-center gap-1.5 rounded-md bg-primary px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        <Send size={14} /> {running ? "Executando..." : "Iniciar squad"}
      </button>

      {squad.state.error && <p className="mb-4 text-sm text-red-500">{squad.state.error}</p>}

      <div className="space-y-3">
        {squad.state.agentRuns.map((agent) => (
          <div
            key={`${agent.agentSlug}-${agent.step}`}
            className="rounded-lg border border-light-border bg-light-card p-4 dark:border-dark-border dark:bg-dark-card"
          >
            <div className="mb-2 flex items-center justify-between">
              <span className="text-sm font-medium text-light-onSurface dark:text-white">
                {agent.agentName}
              </span>
              <StatusBadge status={agent.status} />
            </div>
            {agent.thinking && (
              <p className="mb-2 text-xs italic text-light-onSurface/40 dark:text-white/30">
                {agent.thinking}
              </p>
            )}
            {agent.output && <Markdown content={agent.output} />}
          </div>
        ))}
      </div>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    pending: "#94A3B8",
    running: "#F97316",
    done: "#22C55E",
    error: "#EF4444",
  };
  const color = colors[status] ?? "#94A3B8";
  return (
    <span
      className="rounded-full px-2 py-0.5 text-[10px] font-semibold"
      style={{ color, backgroundColor: `${color}1A` }}
    >
      {status}
    </span>
  );
}
