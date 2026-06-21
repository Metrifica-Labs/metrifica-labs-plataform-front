import { ImagePlus, Repeat2, Trash2, Minus, Plus } from "lucide-react";
import { cn } from "@/shared/lib/cn";
import { Card } from "@/shared/components/ui/Card";

export function SectionCard({
  title,
  icon,
  action,
  children,
}: {
  title: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <Card className="p-4">
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-1.5 text-[13px] font-semibold text-light-onSurface/80 dark:text-dark-onSurface/80">
          {icon}
          {title}
        </div>
        {action}
      </div>
      {children}
    </Card>
  );
}

export function Chip({
  label,
  icon,
  active,
  onClick,
}: {
  label: string;
  icon?: React.ReactNode;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1.5 text-xs font-medium transition-colors",
        active
          ? "border-primary/50 bg-primary-soft text-primary"
          : "border-light-border text-light-onSurface/55 hover:border-light-border-strong dark:border-dark-border dark:text-white/50"
      )}
    >
      {icon}
      {label}
    </button>
  );
}

export function Stepper({
  label,
  value,
  min,
  max,
  step = 1,
  decimals = 0,
  onChange,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  decimals?: number;
  onChange: (v: number) => void;
}) {
  function clamp(v: number) {
    return Math.min(max, Math.max(min, v));
  }
  return (
    <div className="flex items-center justify-between">
      <p className="text-[11px] text-light-onSurface/45 dark:text-white/35">{label}</p>
      <div className="flex items-center gap-2">
        <button
          onClick={() => onChange(clamp(Number((value - step).toFixed(decimals))))}
          className="flex h-6 w-6 items-center justify-center rounded-md border border-light-border text-light-onSurface/50 hover:border-primary/50 hover:text-primary dark:border-dark-border"
        >
          <Minus size={12} />
        </button>
        <span className="w-10 text-center text-[12px] font-medium text-light-onSurface/75 dark:text-white/65">
          {value.toFixed(decimals)}
        </span>
        <button
          onClick={() => onChange(clamp(Number((value + step).toFixed(decimals))))}
          className="flex h-6 w-6 items-center justify-center rounded-md border border-light-border text-light-onSurface/50 hover:border-primary/50 hover:text-primary dark:border-dark-border"
        >
          <Plus size={12} />
        </button>
      </div>
    </div>
  );
}

export function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className={cn(
        "relative h-5 w-9 shrink-0 rounded-full transition-colors",
        checked ? "bg-primary" : "bg-light-onSurface/15 dark:bg-white/15"
      )}
    >
      <span
        className={cn(
          "absolute left-0.5 top-0.5 h-4 w-4 rounded-full bg-white shadow-sm transition-transform",
          checked && "translate-x-4"
        )}
      />
    </button>
  );
}

export function ImagePicker({
  src,
  onPick,
  onClear,
  height = 100,
  emptyLabel = "Adicionar imagem",
}: {
  src: string | null;
  onPick: () => void;
  onClear: () => void;
  height?: number;
  emptyLabel?: string;
}) {
  if (src) {
    return (
      <div className="group relative overflow-hidden rounded-lg" style={{ height }}>
        <img src={src} className="h-full w-full object-cover" />
        <div className="absolute inset-0 flex items-end justify-end gap-1.5 bg-black/0 p-2 opacity-0 transition-opacity group-hover:bg-black/20 group-hover:opacity-100">
          <button
            onClick={onPick}
            className="flex items-center gap-1 rounded-md bg-primary px-2 py-1 text-[11px] font-medium text-white"
          >
            <Repeat2 size={11} /> Trocar
          </button>
          <button
            onClick={onClear}
            className="flex items-center gap-1 rounded-md bg-black/60 px-2 py-1 text-[11px] font-medium text-white"
          >
            <Trash2 size={11} /> Remover
          </button>
        </div>
      </div>
    );
  }
  return (
    <button
      onClick={onPick}
      style={{ height }}
      className="flex w-full flex-col items-center justify-center gap-1.5 rounded-lg border-[1.5px] border-dashed border-primary/35 bg-primary-soft text-primary transition-colors hover:border-primary/60"
    >
      <ImagePlus size={24} />
      <span className="text-xs font-medium">{emptyLabel}</span>
    </button>
  );
}

function toHexColor(value: string): string {
  if (value.startsWith("#")) return value.slice(0, 7);
  const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  if (!match) return "#000000";
  const [, r, g, b] = match;
  return `#${[r, g, b].map((n) => Number(n).toString(16).padStart(2, "0")).join("")}`;
}

export function ColorInput({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">{label}</span>
      <input
        type="color"
        value={toHexColor(value)}
        onChange={(e) => onChange(e.target.value)}
        className="h-7 w-11 cursor-pointer rounded-md border border-light-border bg-transparent dark:border-dark-border"
      />
    </div>
  );
}
