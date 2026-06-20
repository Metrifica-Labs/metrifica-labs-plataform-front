import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useGeneration } from "@/features/generation/useGeneration";
import { isGenerating, extractImagePrompts } from "@/features/generation/generation-types";
import { Markdown } from "@/shared/components/Markdown";
import { addGenerationHistoryEntry } from "@/features/generation/generation-history.repository";
import { useOrgStore } from "@/core/org/org-store";
import { HistoryPanel } from "@/features/generation/HistoryPanel";

export function GenerationPanel({
  flowSlug,
  flowName,
  extraContext,
}: {
  flowSlug: string;
  flowName?: string | null;
  extraContext?: string;
}) {
  const [message, setMessage] = useState("");
  const [correction, setCorrection] = useState("");
  const [historyOpen, setHistoryOpen] = useState(false);
  const generation = useGeneration();
  const activeOrgId = useOrgStore((s) => s.activeOrgId);
  const queryClient = useQueryClient();

  const saveHistory = useMutation({
    mutationFn: () =>
      addGenerationHistoryEntry({
        flowSlug,
        flowName,
        userMessage: generation.state.currentUserMessage,
        output: generation.state.output,
        organizationId: activeOrgId,
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["generation-history"] }),
  });

  const generating = isGenerating(generation.state.status);
  const imagePrompts = extractImagePrompts(generation.state.output);

  function handleGenerate() {
    if (!message.trim()) return;
    generation.generate(flowSlug, message, extraContext);
    setMessage("");
  }

  function handleRefine() {
    if (!correction.trim()) return;
    generation.refine(flowSlug, correction);
    setCorrection("");
  }

  function handleSelectHistory(output: string, name: string | null) {
    generation.restoreFromHistory(output, name);
    setHistoryOpen(false);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-medium text-light-onSurface/70 dark:text-white/70">
          Geração de conteúdo
        </h2>
        <button
          onClick={() => setHistoryOpen(true)}
          className="text-xs text-primary hover:underline"
        >
          Histórico
        </button>
      </div>

      <textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder="Descreva o que você quer gerar..."
        rows={3}
        disabled={generating}
        className="w-full rounded-md border border-light-border-strong bg-transparent p-3 text-sm outline-none focus:border-primary disabled:opacity-50 dark:border-dark-border"
      />
      <button
        onClick={handleGenerate}
        disabled={generating || !message.trim()}
        className="self-start rounded-md bg-primary px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {generating ? "Gerando..." : "Gerar"}
      </button>

      {generation.state.error && (
        <p className="text-sm text-red-500">{generation.state.error}</p>
      )}

      {generation.state.thinking && (
        <details className="rounded-md border border-light-border p-3 text-xs text-light-onSurface/50 dark:border-dark-border dark:text-white/40">
          <summary className="cursor-pointer">Raciocínio</summary>
          <p className="mt-2 whitespace-pre-wrap">{generation.state.thinking}</p>
        </details>
      )}

      {generation.state.output && (
        <div className="rounded-md border border-light-border bg-light-card p-4 dark:border-dark-border dark:bg-dark-card">
          <Markdown content={generation.state.output} />
        </div>
      )}

      {generation.state.status === "done" && generation.state.output && (
        <div className="flex flex-wrap items-center gap-2">
          <input
            value={correction}
            onChange={(e) => setCorrection(e.target.value)}
            placeholder="Pedir ajuste/correção..."
            className="flex-1 rounded-md border border-light-border-strong bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-dark-border"
          />
          <button
            onClick={handleRefine}
            disabled={!correction.trim()}
            className="rounded-md border border-light-border px-3 py-2 text-sm dark:border-dark-border"
          >
            Refinar
          </button>
          <button
            onClick={() => saveHistory.mutate()}
            disabled={saveHistory.isPending}
            className="rounded-md border border-light-border px-3 py-2 text-sm dark:border-dark-border"
          >
            Salvar
          </button>
        </div>
      )}

      {imagePrompts.length > 0 && (
        <div className="rounded-md border border-dashed border-light-border p-3 text-xs text-light-onSurface/50 dark:border-dark-border dark:text-white/40">
          {imagePrompts.length} prompt(s) de imagem detectado(s) no conteúdo.
        </div>
      )}

      {historyOpen && (
        <HistoryPanel onSelect={handleSelectHistory} onClose={() => setHistoryOpen(false)} />
      )}
    </div>
  );
}
