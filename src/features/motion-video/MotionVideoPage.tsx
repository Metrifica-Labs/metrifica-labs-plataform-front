import { useState } from "react";
import { Clapperboard, Loader2, Sparkles } from "lucide-react";
import type { VideoFormat } from "@/remotion/motion-spec";
import { useOrgStore } from "@/core/org/org-store";
import type { MotionRunModel } from "@/core/models/motion-run";
import { PreviewPanel } from "./PreviewPanel";
import { HistoryPanel } from "./HistoryPanel";
import { EditChatPanel } from "./EditChatPanel";
import { useMotionVideo } from "./useMotionVideo";

const FORMATS: { value: VideoFormat; label: string }[] = [
  { value: "reel", label: "Reel 9:16" },
  { value: "story", label: "Story 9:16" },
  { value: "square", label: "Quadrado 1:1" },
  { value: "feed", label: "Feed 4:5" },
  { value: "wide", label: "Wide 16:9" },
];

/**
 * Página da ferramenta Motion Video.
 *
 * Fase 3: a IA enriquece a ideia em um MotionSpec (validado por Zod) e o
 * preview ao lado reflete o resultado. Persistência (Fase 4) e chat de edição
 * (Fase 5) entram a seguir.
 */
export function MotionVideoPage() {
  const { state, generate, editSpec, loadSpec } = useMotionVideo();
  const [input, setInput] = useState("");
  const [format, setFormat] = useState<VideoFormat>("reel");
  const activeOrgId = useOrgStore((s) => s.activeOrgId);

  const busy = state.status === "connecting" || state.status === "streaming";
  const canEdit = state.status === "done" || state.runId !== null;

  function handleGenerate() {
    generate(input, format);
  }

  function handleSelectRun(run: MotionRunModel) {
    if (!run.motionSpec) return;
    setFormat(run.format);
    loadSpec(run.motionSpec, run.id);
  }

  return (
    <div className="flex h-full">
      <aside className="flex w-[340px] shrink-0 flex-col border-r border-light-border bg-light-card p-5 dark:border-dark-border dark:bg-dark-card">
        <div className="mb-4 flex items-center gap-2">
          <Clapperboard size={18} className="text-primary" />
          <h1 className="text-[15px] font-semibold text-light-onSurface dark:text-dark-onSurface">
            Motion Video
          </h1>
        </div>

        <p className="mb-4 text-[13px] leading-relaxed text-light-onSurface/55 dark:text-dark-onSurface/55">
          Descreva a ideia do vídeo e a IA monta o roteiro de motion design. O
          preview ao lado atualiza ao concluir.
        </p>

        <label className="mb-1.5 text-[12px] font-medium text-light-onSurface/70 dark:text-dark-onSurface/70">
          Formato
        </label>
        <select
          value={format}
          onChange={(e) => setFormat(e.target.value as VideoFormat)}
          disabled={busy}
          className="mb-3 w-full rounded-lg border border-light-border bg-transparent p-2 text-[13px] text-light-onSurface dark:border-dark-border dark:bg-dark-card dark:text-dark-onSurface"
        >
          {FORMATS.map((f) => (
            <option key={f.value} value={f.value}>
              {f.label}
            </option>
          ))}
        </select>

        <textarea
          value={input}
          onChange={(e) => setInput(e.target.value)}
          disabled={busy}
          placeholder="Ex.: um teaser de lançamento com a headline “Sua marca em movimento”…"
          className="h-32 w-full resize-none rounded-lg border border-light-border bg-transparent p-3 text-[13px] text-light-onSurface placeholder:text-light-onSurface/35 dark:border-dark-border dark:text-dark-onSurface"
        />

        <button
          onClick={handleGenerate}
          disabled={busy || input.trim().length === 0}
          className="mt-3 flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-[13px] font-medium text-white transition-opacity disabled:opacity-50"
        >
          {busy ? (
            <>
              <Loader2 size={15} className="animate-spin" />
              {state.status === "connecting" ? "Conectando…" : "Gerando…"}
            </>
          ) : (
            <>
              <Sparkles size={15} />
              Gerar
            </>
          )}
        </button>

        {state.error && (
          <div className="mt-3 rounded-lg border border-red-500/30 bg-red-500/10 p-3 text-[12px] text-red-600 dark:text-red-400">
            {state.error}
          </div>
        )}

        <div className="mt-4 min-h-0 flex-1 overflow-y-auto border-t border-light-border pt-4 dark:border-dark-border">
          <HistoryPanel
            orgId={activeOrgId}
            activeRunId={state.runId}
            onSelect={handleSelectRun}
          />
        </div>

        <div className="mt-4 rounded-lg bg-light-onSurface/4 p-3 text-[12px] text-light-onSurface/50 dark:bg-white/4 dark:text-dark-onSurface/50">
          Preview:{" "}
          <span className="font-medium">{state.spec.scenes.length} cena(s)</span>,
          formato <span className="font-medium">{state.spec.meta.format}</span>
          {state.runId
            ? " · salvo"
            : state.status === "idle"
              ? " · exemplo"
              : ""}
        </div>
      </aside>

      <main className="flex flex-1 bg-light-bg dark:bg-dark-bg">
        <div className="flex-1 p-6">
          <PreviewPanel spec={state.spec} />
        </div>
        <aside className="flex w-[320px] shrink-0 flex-col border-l border-light-border bg-light-card p-5 dark:border-dark-border dark:bg-dark-card">
          <EditChatPanel
            messages={state.messages}
            busy={busy}
            enabled={canEdit}
            onSend={editSpec}
          />
        </aside>
      </main>
    </div>
  );
}
