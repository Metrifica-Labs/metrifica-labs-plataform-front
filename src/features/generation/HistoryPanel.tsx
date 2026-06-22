import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { X, Trash2, Clock } from "lucide-react";
import {
  fetchGenerationHistory,
  removeGenerationHistoryEntry,
} from "@/features/generation/generation-history.repository";
import { IconButton } from "@/shared/components/ui/Button";
import { EmptyState } from "@/shared/components/ui/Card";
import { Skeleton } from "@/shared/components/ui/Skeleton";

export function HistoryPanel({
  onSelect,
  onClose,
}: {
  onSelect: (output: string, flowName: string | null) => void;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const { data: entries, isPending } = useQuery({
    queryKey: ["generation-history"],
    queryFn: fetchGenerationHistory,
  });

  const remove = useMutation({
    mutationFn: removeGenerationHistoryEntry,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["generation-history"] }),
  });

  return (
    <>
      <div
        className="fixed inset-0 z-40 bg-black/20 backdrop-blur-[2px]"
        onClick={onClose}
        aria-hidden
      />
      <div className="fixed inset-y-0 right-0 z-50 flex w-[340px] flex-col border-l border-light-border bg-light-card shadow-floating dark:border-dark-border dark:bg-dark-card">
        <div className="flex items-center justify-between border-b border-light-border px-4 py-3 dark:border-dark-border">
          <h3 className="text-[13px] font-semibold text-light-onSurface dark:text-dark-onSurface">
            Histórico
          </h3>
          <IconButton onClick={onClose} title="Fechar">
            <X size={15} />
          </IconButton>
        </div>

        <div className="flex-1 space-y-1.5 overflow-y-auto p-3">
          {isPending && (
            <div className="space-y-1.5">
              <Skeleton className="h-14 w-full" />
              <Skeleton className="h-14 w-full" />
              <Skeleton className="h-14 w-full" />
            </div>
          )}

          {entries?.map((entry) => (
            <div
              key={entry.id}
              className="group rounded-lg border border-light-border p-2.5 transition-colors hover:border-primary/40 dark:border-dark-border"
            >
              <button onClick={() => onSelect(entry.output, entry.flowName)} className="block w-full text-left">
                <p className="truncate text-[13px] font-medium text-light-onSurface/85 dark:text-dark-onSurface/80">
                  {entry.flowName ?? entry.flowSlug}
                </p>
                <p className="mt-0.5 truncate text-xs text-light-onSurface/45 dark:text-white/35">
                  {entry.userMessage}
                </p>
              </button>
              <button
                onClick={() => remove.mutate(entry.id)}
                className="mt-1.5 flex items-center gap-1 text-[11px] text-red-500/70 opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-500"
              >
                <Trash2 size={11} /> Remover
              </button>
            </div>
          ))}

          {entries?.length === 0 && (
            <EmptyState icon={<Clock size={18} />} title="Sem histórico ainda" />
          )}
        </div>
      </div>
    </>
  );
}
