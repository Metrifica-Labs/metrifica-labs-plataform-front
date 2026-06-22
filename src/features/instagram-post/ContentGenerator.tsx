import { Sparkles, RotateCcw } from "lucide-react";
import { Card } from "@/shared/components/ui/Card";
import { Button } from "@/shared/components/ui/Button";
import { Textarea } from "@/shared/components/ui/Field";
import { cn } from "@/shared/lib/cn";
import type { SlideLayout } from "@/features/instagram-post/instagram-post-style";
import {
  LAYOUT_LABELS,
  LAYOUT_SUBTITLES,
  STATUS_LABELS,
} from "@/features/instagram-post/post-ui-constants";

export function ContentGenerator({
  briefing,
  onBriefingChange,
  defaultLayout,
  onLayoutChange,
  generating,
  status,
  hasSlides,
  onGenerate,
  onReset,
}: {
  briefing: string;
  onBriefingChange: (value: string) => void;
  defaultLayout: SlideLayout;
  onLayoutChange: (layout: SlideLayout) => void;
  generating: boolean;
  status: string;
  hasSlides: boolean;
  onGenerate: () => void;
  onReset: () => void;
}) {
  return (
    <Card className="p-4">
      <div className="mb-3 flex items-center gap-1.5 text-[13px] font-semibold text-light-onSurface/75 dark:text-dark-onSurface/75">
        <Sparkles size={14} className="text-primary" />
        Conteúdo (IA)
      </div>

      <p className="mb-2 text-[11px] text-light-onSurface/40 dark:text-white/30">
        Tipo de layout — define como a IA vai gerar o conteúdo
      </p>
      <div className="mb-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
        {(Object.keys(LAYOUT_LABELS) as SlideLayout[]).map((layout) => (
          <button
            key={layout}
            onClick={() => onLayoutChange(layout)}
            className={cn(
              "rounded-lg border px-3 py-2 text-left transition-colors",
              defaultLayout === layout
                ? "border-primary/50 bg-primary-soft"
                : "border-light-border hover:border-light-border-strong dark:border-dark-border"
            )}
          >
            <p
              className={cn(
                "text-xs font-semibold",
                defaultLayout === layout
                  ? "text-primary"
                  : "text-light-onSurface/70 dark:text-white/60"
              )}
            >
              {LAYOUT_LABELS[layout].split("—")[0].trim()}
            </p>
            <p className="text-[10px] text-light-onSurface/40 dark:text-white/30">
              {LAYOUT_SUBTITLES[layout]}
            </p>
          </button>
        ))}
      </div>

      <Textarea
        value={briefing}
        onChange={(e) => onBriefingChange(e.target.value)}
        placeholder="Ex: carrossel sobre os 3 erros que travam a operação de uma PME..."
        rows={3}
        disabled={generating}
        className="mb-3"
      />
      <div className="flex items-center justify-between">
        {generating ? (
          <p className="flex items-center gap-2 text-xs text-light-onSurface/50 dark:text-white/40">
            <span className="h-3 w-3 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
            {STATUS_LABELS[status] ?? "Processando..."}
          </p>
        ) : (
          <span />
        )}
        <div className="flex items-center gap-2">
          {hasSlides && (
            <Button variant="ghost" size="sm" onClick={onReset}>
              <RotateCcw size={13} /> Novo carrossel
            </Button>
          )}
          <Button onClick={onGenerate} disabled={generating || !briefing.trim()} size="sm">
            {generating ? "Gerando..." : "Gerar conteúdo"}
          </Button>
        </div>
      </div>
    </Card>
  );
}
