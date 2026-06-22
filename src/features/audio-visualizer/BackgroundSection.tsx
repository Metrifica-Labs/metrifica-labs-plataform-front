import { Image as ImageIcon } from "lucide-react";
import { SectionCard } from "@/shared/components/ui/Card";
import { Select } from "@/shared/components/ui/Field";
import { ColorInput } from "@/shared/components/ui/ColorInput";
import { ImagePicker } from "@/shared/components/ui/ImagePicker";
import type { AudioVisualizerConfig, BackgroundType } from "@/features/audio-visualizer/audio-visualizer-config";

const BACKGROUND_TYPE_LABELS: Record<BackgroundType, string> = {
  solid: "Cor sólida",
  gradient: "Degradê",
  image: "Imagem",
};

export function BackgroundSection({
  config,
  onConfigChange,
  onPickBackgroundImage,
  onClearBackgroundImage,
}: {
  config: AudioVisualizerConfig;
  onConfigChange: (updater: (c: AudioVisualizerConfig) => AudioVisualizerConfig) => void;
  onPickBackgroundImage: () => void;
  onClearBackgroundImage: () => void;
}) {
  return (
    <SectionCard title="Fundo" icon={<ImageIcon size={14} className="text-primary" />}>
      <div className="space-y-2.5">
        <Select
          value={config.backgroundType}
          onChange={(e) => onConfigChange((c) => ({ ...c, backgroundType: e.target.value as BackgroundType }))}
        >
          {Object.entries(BACKGROUND_TYPE_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </Select>
        <ColorInput label="Cor de fundo" value={config.backgroundColor} onChange={(v) => onConfigChange((c) => ({ ...c, backgroundColor: v }))} />
        {config.backgroundType === "gradient" && (
          <ColorInput label="Cor secundária" value={config.backgroundColor2} onChange={(v) => onConfigChange((c) => ({ ...c, backgroundColor2: v }))} />
        )}
        {config.backgroundType === "image" && (
          <ImagePicker
            src={config.backgroundImageUrl}
            height={90}
            emptyLabel="Adicionar imagem de fundo"
            onPick={onPickBackgroundImage}
            onClear={onClearBackgroundImage}
          />
        )}
      </div>
    </SectionCard>
  );
}
