import { useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";
import { Send, Bot } from "lucide-react";
import { useSquadRun } from "@/features/squad/useSquadRun";
import { isSquadRunning } from "@/features/squad/squad-state";
import { useOrgStore } from "@/core/org/org-store";
import { Markdown } from "@/shared/components/Markdown";
import { PageHeader, Card, Badge, EmptyState } from "@/shared/components/ui/Card";
import { Button } from "@/shared/components/ui/Button";
import { Textarea } from "@/shared/components/ui/Field";
import { useToast } from "@/shared/hooks/useToast";

export function SquadPage() {
  const { slug } = useParams<{ slug: string }>();
  const squad = useSquadRun();
  const [message, setMessage] = useState("");
  const activeOrgId = useOrgStore((s) => s.activeOrgId);
  const toast = useToast();
  const lastError = useRef<string | null>(null);

  useEffect(() => {
    if (squad.state.error && squad.state.error !== lastError.current) {
      lastError.current = squad.state.error;
      toast.error(squad.state.error);
    }
  }, [squad.state.error, toast]);

  function handleRun() {
    if (!slug || !message.trim()) return;
    void squad.run(slug, message, activeOrgId);
  }

  const running = isSquadRunning(squad.state.status);

  return (
    <div className="mx-auto max-w-2xl p-6">
      <PageHeader eyebrow="Squad" title={squad.state.squadName ?? slug ?? ""} subtitle="Orquestração multi-agente" />

      <Textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder="Descreva a tarefa para a squad..."
        rows={3}
        disabled={running}
        className="mb-3"
      />
      <Button onClick={handleRun} disabled={running || !message.trim()} className="mb-6">
        <Send size={14} /> {running ? "Executando..." : "Iniciar squad"}
      </Button>

      {squad.state.error && (
        <p className="mb-4 rounded-md border border-red-500/20 bg-red-500/5 px-3 py-2 text-sm text-red-500">
          {squad.state.error}
        </p>
      )}

      {squad.state.agentRuns.length === 0 ? (
        <EmptyState
          icon={<Bot size={20} />}
          title="Nenhuma execução ainda"
          description="Descreva uma tarefa acima para acionar a squad."
        />
      ) : (
        <div className="space-y-3">
          {squad.state.agentRuns.map((agent) => (
            <Card key={`${agent.agentSlug}-${agent.step}`} className="p-4">
              <div className="mb-2 flex items-center justify-between">
                <span className="text-sm font-medium text-light-onSurface dark:text-dark-onSurface">
                  {agent.agentName}
                </span>
                <Badge status={agent.status}>{agent.status}</Badge>
              </div>
              {agent.thinking && (
                <p className="mb-2 text-xs italic text-light-onSurface/40 dark:text-white/30">
                  {agent.thinking}
                </p>
              )}
              {agent.output && <Markdown content={agent.output} />}
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
