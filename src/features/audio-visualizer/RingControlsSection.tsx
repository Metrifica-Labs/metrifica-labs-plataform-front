import { AudioLines, Disc3, Image as ImageIcon } from "lucide-react";
import { SectionCard } from "@/shared/components/ui/Card";
import { Select } from "@/shared/components/ui/Field";
import { Stepper } from "@/shared/components/ui/Stepper";
import { Switch } from "@/shared/components/ui/Switch";
import { ColorInput } from "@/shared/components/ui/ColorInput";
import { ImagePicker } from "@/shared/components/ui/ImagePicker";
import { VIDEO_ASPECTS, type AudioVisualizerConfig } from "@/features/audio-visualizer/audio-visualizer-config";

type ConfigUpdater = (updater: (c: AudioVisualizerConfig) => AudioVisualizerConfig) => void;

export function FormatSection({
  config,
  onConfigChange,
}: {
  config: AudioVisualizerConfig;
  onConfigChange: ConfigUpdater;
}) {
  return (
    <SectionCard title="Formato" icon={<AudioLines size={14} className="text-primary" />}>
      <div className="space-y-2.5">
        <Select
          value={config.aspect}
          onChange={(e) => onConfigChange((c) => ({ ...c, aspect: e.target.value as typeof c.aspect }))}
        >
          {Object.entries(VIDEO_ASPECTS).map(([value, { label }]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </Select>
        <Stepper label="FPS" value={config.fps} min={15} max={60} onChange={(v) => onConfigChange((c) => ({ ...c, fps: v }))} />
      </div>
    </SectionCard>
  );
}

export function RingControlsSection({
  config,
  onConfigChange,
}: {
  config: AudioVisualizerConfig;
  onConfigChange: ConfigUpdater;
}) {
  return (
    <SectionCard title="Anel / Espectro" icon={<Disc3 size={14} className="text-primary" />}>
      <div className="space-y-2.5">
        <ColorInput label="Cor inicial" value={config.ringColorStart} onChange={(v) => onConfigChange((c) => ({ ...c, ringColorStart: v }))} />
        <ColorInput label="Cor final" value={config.ringColorEnd} onChange={(v) => onConfigChange((c) => ({ ...c, ringColorEnd: v }))} />
        <Stepper label="Nº de barras" value={config.barCount} min={24} max={180} step={4} onChange={(v) => onConfigChange((c) => ({ ...c, barCount: v }))} />
        <Stepper label="Raio do anel" value={config.ringRadius} min={0.15} max={0.45} step={0.01} decimals={2} onChange={(v) => onConfigChange((c) => ({ ...c, ringRadius: v }))} />
        <Stepper label="Espessura da barra" value={config.barWidth} min={2} max={16} onChange={(v) => onConfigChange((c) => ({ ...c, barWidth: v }))} />
        <Stepper label="Tamanho máx. da barra" value={config.barMaxLength} min={40} max={260} step={5} onChange={(v) => onConfigChange((c) => ({ ...c, barMaxLength: v }))} />
        <Stepper label="Sensibilidade" value={config.sensitivity} min={0.4} max={2.5} step={0.1} decimals={1} onChange={(v) => onConfigChange((c) => ({ ...c, sensitivity: v }))} />
        <Stepper label="Velocidade de rotação" value={config.rotationSpeed} min={0} max={30} onChange={(v) => onConfigChange((c) => ({ ...c, rotationSpeed: v }))} />
        <div className="flex items-center justify-between">
          <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Brilho (glow)</span>
          <Switch checked={config.glow} onChange={(v) => onConfigChange((c) => ({ ...c, glow: v }))} />
        </div>
      </div>
    </SectionCard>
  );
}

export function CenterImageSection({
  config,
  onConfigChange,
  onPickCenterImage,
  onClearCenterImage,
}: {
  config: AudioVisualizerConfig;
  onConfigChange: ConfigUpdater;
  onPickCenterImage: () => void;
  onClearCenterImage: () => void;
}) {
  return (
    <SectionCard title="Imagem central" icon={<ImageIcon size={14} className="text-primary" />}>
      <div className="space-y-2.5">
        <ImagePicker src={config.centerImageUrl} height={90} onPick={onPickCenterImage} onClear={onClearCenterImage} />
        <Stepper
          label="Escala"
          value={config.centerImageScale}
          min={0.4}
          max={1}
          step={0.05}
          decimals={2}
          onChange={(v) => onConfigChange((c) => ({ ...c, centerImageScale: v }))}
        />
        <div className="flex items-center justify-between">
          <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Circular</span>
          <Switch checked={config.centerImageCircular} onChange={(v) => onConfigChange((c) => ({ ...c, centerImageCircular: v }))} />
        </div>
        <div className="flex items-center justify-between">
          <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Pulsar com o áudio</span>
          <Switch checked={config.centerImagePulse} onChange={(v) => onConfigChange((c) => ({ ...c, centerImagePulse: v }))} />
        </div>
      </div>
    </SectionCard>
  );
}
