import { AlignLeft, AlignCenter, AlignRight } from "lucide-react";
import { cn } from "@/shared/lib/cn";
import { BACKGROUND_SWATCHES } from "@/features/instagram-post/instagram-post-style";
import type { TextAlignment } from "@/features/instagram-post/instagram-post-style";

export { SectionCard } from "@/shared/components/ui/Card";
export { Chip } from "@/shared/components/ui/Chip";
export { Stepper } from "@/shared/components/ui/Stepper";
export { ImagePicker } from "@/shared/components/ui/ImagePicker";
export { Switch as Toggle } from "@/shared/components/ui/Switch";
export { ColorInput } from "@/shared/components/ui/ColorInput";

export function SwatchRow({
  label,
  value,
  swatches = BACKGROUND_SWATCHES,
  onSelect,
}: {
  label: string;
  value: string;
  swatches?: string[];
  onSelect: (color: string) => void;
}) {
  return (
    <div>
      <p className="mb-1.5 text-[11px] text-light-onSurface/45 dark:text-white/35">{label}</p>
      <div className="flex flex-wrap gap-1.5">
        {swatches.map((color) => (
          <button
            key={color}
            onClick={() => onSelect(color)}
            style={{ backgroundColor: color }}
            className={cn(
              "h-6 w-6 rounded-full border-2 transition-transform hover:scale-110",
              value === color ? "border-primary" : "border-light-border dark:border-dark-border"
            )}
          />
        ))}
      </div>
    </div>
  );
}

export function ColorRow({
  label,
  value,
  isOverride,
  onSelect,
  onReset,
}: {
  label: string;
  value: string;
  isOverride: boolean;
  onSelect: (color: string) => void;
  onReset: () => void;
}) {
  return (
    <div>
      <div className="mb-1.5 flex items-center gap-2">
        <p className="text-[11px] text-light-onSurface/45 dark:text-white/35">{label}</p>
        {isOverride && (
          <button onClick={onReset} className="text-[10px] text-primary underline">
            resetar
          </button>
        )}
      </div>
      <div className="flex flex-wrap gap-1.5">
        {BACKGROUND_SWATCHES.map((color) => (
          <button
            key={color}
            onClick={() => onSelect(color)}
            style={{ backgroundColor: color }}
            className={cn(
              "h-6 w-6 rounded-full border-2 transition-transform hover:scale-110",
              value === color ? "border-primary" : "border-light-border dark:border-dark-border"
            )}
          />
        ))}
      </div>
    </div>
  );
}

const ALIGN_OPTIONS: { value: TextAlignment; icon: React.ReactNode }[] = [
  { value: "left", icon: <AlignLeft size={14} /> },
  { value: "center", icon: <AlignCenter size={14} /> },
  { value: "right", icon: <AlignRight size={14} /> },
];

export function AlignSelector({ value, onChange }: { value: TextAlignment; onChange: (v: TextAlignment) => void }) {
  return (
    <div className="flex items-center gap-1.5">
      {ALIGN_OPTIONS.map((opt) => (
        <button
          key={opt.value}
          onClick={() => onChange(opt.value)}
          className={cn(
            "flex h-7 w-7 items-center justify-center rounded-md border transition-colors",
            value === opt.value
              ? "border-primary/50 bg-primary-soft text-primary"
              : "border-light-border text-light-onSurface/45 hover:border-light-border-strong dark:border-dark-border"
          )}
        >
          {opt.icon}
        </button>
      ))}
    </div>
  );
}

export function MarkupHintInline() {
  return (
    <p className="text-[11px] text-light-onSurface/35 dark:text-white/30">
      Negrito: [b]texto[/b] · Itálico: [i]texto[/i] · Sublinhado: [u]texto[/u] · Destaque: [hl]texto[/hl]
    </p>
  );
}
