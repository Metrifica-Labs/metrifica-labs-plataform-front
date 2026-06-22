import { Captions as CaptionsIcon, Download } from "lucide-react";
import { SectionCard } from "@/shared/components/ui/Card";
import { Select } from "@/shared/components/ui/Field";
import { Stepper } from "@/shared/components/ui/Stepper";
import { Switch } from "@/shared/components/ui/Switch";
import { ColorInput } from "@/shared/components/ui/ColorInput";
import type { AudioVisualizerConfig, CaptionMode } from "@/features/audio-visualizer/audio-visualizer-config";
import type { Captions } from "@/features/audio-visualizer/captions";

const CAPTION_MODE_LABELS: Record<CaptionMode, string> = {
  segment: "Frase completa",
  karaoke: "Karaoke (palavra)",
  word: "Palavra por palavra",
};

export function CaptionsSection({
  config,
  captions,
  onConfigChange,
  onExportCaptions,
}: {
  config: AudioVisualizerConfig;
  captions: Captions;
  onConfigChange: (updater: (c: AudioVisualizerConfig) => AudioVisualizerConfig) => void;
  onExportCaptions: () => void;
}) {
  return (
    <SectionCard title="Legendas" icon={<CaptionsIcon size={14} className="text-primary" />}>
      <div className="space-y-2.5">
        <div className="flex items-center justify-between">
          <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Ativadas</span>
          <Switch checked={config.captionEnabled} onChange={(v) => onConfigChange((c) => ({ ...c, captionEnabled: v }))} />
        </div>
        {config.captionEnabled && (
          <>
            <Select
              value={config.captionMode}
              onChange={(e) => onConfigChange((c) => ({ ...c, captionMode: e.target.value as CaptionMode }))}
            >
              {Object.entries(CAPTION_MODE_LABELS).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </Select>
            <Stepper
              label="Tamanho da fonte"
              value={config.captionFontSize}
              min={20}
              max={96}
              step={2}
              onChange={(v) => onConfigChange((c) => ({ ...c, captionFontSize: v }))}
            />
            <ColorInput label="Cor do texto" value={config.captionColor} onChange={(v) => onConfigChange((c) => ({ ...c, captionColor: v }))} />
            <ColorInput
              label="Cor de destaque"
              value={config.captionHighlightColor}
              onChange={(v) => onConfigChange((c) => ({ ...c, captionHighlightColor: v }))}
            />
            <Stepper
              label="Posição (da base)"
              value={config.captionBottomOffset}
              min={0.05}
              max={0.5}
              step={0.01}
              decimals={2}
              onChange={(v) => onConfigChange((c) => ({ ...c, captionBottomOffset: v }))}
            />
            {config.captionMode === "karaoke" && (
              <Stepper
                label="Palavras por bloco"
                value={config.captionMaxWords}
                min={1}
                max={10}
                onChange={(v) => onConfigChange((c) => ({ ...c, captionMaxWords: v }))}
              />
            )}
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Negrito</span>
              <Switch checked={config.captionBold} onChange={(v) => onConfigChange((c) => ({ ...c, captionBold: v }))} />
            </div>
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Sombra</span>
              <Switch checked={config.captionShadow} onChange={(v) => onConfigChange((c) => ({ ...c, captionShadow: v }))} />
            </div>
          </>
        )}
      </div>

      {captions.segments.length > 0 && (
        <button
          onClick={onExportCaptions}
          className="mt-3 flex items-center gap-1.5 text-xs text-primary hover:underline"
        >
          <Download size={12} /> Exportar legendas
        </button>
      )}
    </SectionCard>
  );
}
