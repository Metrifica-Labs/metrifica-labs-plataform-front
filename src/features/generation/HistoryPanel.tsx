import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchGenerationHistory,
  removeGenerationHistoryEntry,
} from "@/features/generation/generation-history.repository";

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
    <div className="fixed inset-y-0 right-0 z-50 flex w-80 flex-col border-l border-light-border bg-light-card p-4 shadow-lg dark:border-dark-border dark:bg-dark-card">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-sm font-medium text-light-onSurface dark:text-white">Histórico</h3>
        <button onClick={onClose} className="text-xs text-light-onSurface/50 dark:text-white/50">
          Fechar
        </button>
      </div>

      {isPending && <p className="text-xs text-light-onSurface/50">Carregando...</p>}

      <div className="flex-1 space-y-2 overflow-y-auto">
        {entries?.map((entry) => (
          <div
            key={entry.id}
            className="rounded-md border border-light-border p-2 text-xs dark:border-dark-border"
          >
            <button
              onClick={() => onSelect(entry.output, entry.flowName)}
              className="block w-full text-left text-light-onSurface/80 dark:text-white/70"
            >
              <p className="font-medium">{entry.flowName ?? entry.flowSlug}</p>
              <p className="truncate text-light-onSurface/50 dark:text-white/40">
                {entry.userMessage}
              </p>
            </button>
            <button
              onClick={() => remove.mutate(entry.id)}
              className="mt-1 text-[11px] text-red-500/70"
            >
              Remover
            </button>
          </div>
        ))}
        {entries?.length === 0 && (
          <p className="text-xs text-light-onSurface/40 dark:text-white/30">Sem histórico ainda.</p>
        )}
      </div>
    </div>
  );
}
