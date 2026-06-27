import { History, Loader2 } from "lucide-react";
import type { MotionRunModel } from "@/core/models/motion-run";
import { useMotionRuns } from "./useMotionRuns";

interface HistoryPanelProps {
  orgId: string | null;
  activeRunId: string | null;
  onSelect: (run: MotionRunModel) => void;
}

/** Data curta e legível (ex.: "26 jun 14:32"). */
function formatWhen(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  return d.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/**
 * Histórico de runs da org ativa (Fase 4). Clicar num item restaura o MotionSpec
 * no preview, sem nova chamada à IA.
 */
export function HistoryPanel({ orgId, activeRunId, onSelect }: HistoryPanelProps) {
  const { data: runs, isLoading, isError } = useMotionRuns(orgId);

  return (
    <div className="flex flex-col">
      <div className="mb-2 flex items-center gap-2">
        <History size={15} className="text-light-onSurface/55 dark:text-dark-onSurface/55" />
        <h2 className="text-[12px] font-medium uppercase tracking-wide text-light-onSurface/55 dark:text-dark-onSurface/55">
          Histórico
        </h2>
      </div>

      {!orgId && (
        <p className="text-[12px] text-light-onSurface/45 dark:text-dark-onSurface/45">
          Selecione uma organização para ver o histórico.
        </p>
      )}

      {orgId && isLoading && (
        <div className="flex items-center gap-2 text-[12px] text-light-onSurface/45 dark:text-dark-onSurface/45">
          <Loader2 size={14} className="animate-spin" /> Carregando…
        </div>
      )}

      {orgId && isError && (
        <p className="text-[12px] text-red-500">Não foi possível carregar o histórico.</p>
      )}

      {orgId && !isLoading && !isError && (runs?.length ?? 0) === 0 && (
        <p className="text-[12px] text-light-onSurface/45 dark:text-dark-onSurface/45">
          Nenhum vídeo gerado ainda.
        </p>
      )}

      <ul className="flex flex-col gap-1.5">
        {runs?.map((run) => {
          const selected = run.id === activeRunId;
          return (
            <li key={run.id}>
              <button
                onClick={() => onSelect(run)}
                disabled={!run.motionSpec}
                className={`w-full rounded-lg border p-2.5 text-left transition-colors disabled:opacity-50 ${
                  selected
                    ? "border-primary bg-primary/10"
                    : "border-light-border hover:bg-light-onSurface/4 dark:border-dark-border dark:hover:bg-white/4"
                }`}
              >
                <p className="line-clamp-2 text-[12px] text-light-onSurface dark:text-dark-onSurface">
                  {run.input}
                </p>
                <p className="mt-1 text-[11px] text-light-onSurface/45 dark:text-dark-onSurface/45">
                  {run.format} · {formatWhen(run.createdAt)}
                </p>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
