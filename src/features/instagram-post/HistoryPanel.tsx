import { X, History as HistoryIcon, Trash2 } from "lucide-react";
import { IconButton } from "@/shared/components/ui/Button";
import { EmptyState } from "@/shared/components/ui/Card";
import type { IgPostHistoryEntry } from "@/features/instagram-post/ig-post-history";

export function HistoryPanel({
  open,
  history,
  onClose,
  onRestore,
  onDelete,
}: {
  open: boolean;
  history: IgPostHistoryEntry[];
  onClose: () => void;
  onRestore: (entry: IgPostHistoryEntry) => void;
  onDelete: (id: string) => void;
}) {
  if (!open) return null;

  return (
    <>
      <div
        className="fixed inset-0 z-40 bg-black/20 backdrop-blur-[2px]"
        onClick={onClose}
        aria-hidden
      />
      <div data-testid="history-panel" className="fixed inset-y-0 right-0 z-50 flex w-80 flex-col border-l border-light-border bg-light-card p-4 shadow-floating dark:border-dark-border dark:bg-dark-card">
        <div className="mb-4 flex items-center justify-between">
          <h3 className="text-[13px] font-semibold text-light-onSurface dark:text-dark-onSurface">
            Histórico
          </h3>
          <IconButton onClick={onClose} title="Fechar">
            <X size={15} />
          </IconButton>
        </div>
        <div className="flex-1 space-y-1.5 overflow-y-auto">
          {history.map((entry) => (
            <div
              key={entry.id}
              className="group relative flex items-start gap-2 rounded-lg border border-light-border p-2.5 text-xs transition-colors hover:border-primary/40 dark:border-dark-border"
            >
              <button
                onClick={() => onRestore(entry)}
                className="block min-w-0 flex-1 text-left"
              >
                <p className="truncate text-light-onSurface/80 dark:text-white/70">
                  {entry.briefing || "(sem briefing)"}
                </p>
                <p className="mt-0.5 text-light-onSurface/40 dark:text-white/30">
                  {new Date(entry.createdAt).toLocaleString("pt-BR")}
                </p>
              </button>
              <button
                onClick={() => onDelete(entry.id)}
                title="Remover do histórico"
                className="shrink-0 text-light-onSurface/30 opacity-0 transition-opacity hover:text-red-500 group-hover:opacity-100 dark:text-white/25"
              >
                <Trash2 size={13} />
              </button>
            </div>
          ))}
          {history.length === 0 && (
            <EmptyState
              icon={<HistoryIcon size={18} />}
              title="Sem histórico ainda"
              description="Cada carrossel gerado pela IA é salvo aqui automaticamente."
            />
          )}
        </div>
      </div>
    </>
  );
}
