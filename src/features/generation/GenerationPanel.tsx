import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { History, Sparkles, ImagePlus } from "lucide-react";
import { useGeneration } from "@/features/generation/useGeneration";
import { isGenerating, extractImagePrompts } from "@/features/generation/generation-types";
import { Markdown } from "@/shared/components/Markdown";
import { addGenerationHistoryEntry } from "@/features/generation/generation-history.repository";
import { useOrgStore } from "@/core/org/org-store";
import { HistoryPanel } from "@/features/generation/HistoryPanel";
import { Button } from "@/shared/components/ui/Button";
import { Textarea, Input } from "@/shared/components/ui/Field";
import { Card } from "@/shared/components/ui/Card";

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
        <h2 className="flex items-center gap-1.5 text-[13px] font-semibold text-light-onSurface/75 dark:text-dark-onSurface/75">
          <Sparkles size={14} className="text-primary" />
          Geração de conteúdo
        </h2>
        <button
          onClick={() => setHistoryOpen(true)}
          className="flex items-center gap-1 text-xs font-medium text-primary hover:underline"
        >
          <History size={13} />
          Histórico
        </button>
      </div>

      <Textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder="Descreva o que você quer gerar..."
        rows={3}
        disabled={generating}
      />
      <Button onClick={handleGenerate} disabled={generating || !message.trim()} className="self-start">
        {generating ? "Gerando..." : "Gerar"}
      </Button>

      {generation.state.error && (
        <p className="rounded-md border border-red-500/20 bg-red-500/5 px-3 py-2 text-sm text-red-500">
          {generation.state.error}
        </p>
      )}

      {generation.state.thinking && (
        <details className="rounded-md border border-light-border p-3 text-xs text-light-onSurface/50 dark:border-dark-border dark:text-white/40">
          <summary className="cursor-pointer select-none font-medium">Raciocínio</summary>
          <p className="mt-2 whitespace-pre-wrap leading-relaxed">{generation.state.thinking}</p>
        </details>
      )}

      {generation.state.output && (
        <Card className="p-4">
          <Markdown content={generation.state.output} />
        </Card>
      )}

      {generation.state.status === "done" && generation.state.output && (
        <div className="flex flex-wrap items-center gap-2">
          <Input
            value={correction}
            onChange={(e) => setCorrection(e.target.value)}
            placeholder="Pedir ajuste/correção..."
            className="flex-1"
          />
          <Button variant="secondary" size="sm" onClick={handleRefine} disabled={!correction.trim()}>
            Refinar
          </Button>
          <Button variant="secondary" size="sm" onClick={() => saveHistory.mutate()} disabled={saveHistory.isPending}>
            Salvar
          </Button>
        </div>
      )}

      {imagePrompts.length > 0 && (
        <div className="flex items-center gap-2 rounded-md border border-dashed border-light-border-strong p-3 text-xs text-light-onSurface/50 dark:border-dark-border dark:text-white/40">
          <ImagePlus size={14} />
          {imagePrompts.length} prompt(s) de imagem detectado(s) no conteúdo.
        </div>
      )}

      {historyOpen && (
        <HistoryPanel onSelect={handleSelectHistory} onClose={() => setHistoryOpen(false)} />
      )}
    </div>
  );
}
