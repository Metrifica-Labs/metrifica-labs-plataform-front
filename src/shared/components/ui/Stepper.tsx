import { Minus, Plus } from "lucide-react";

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
      <p className="text-2xs text-light-onSurface/45 dark:text-white/35">{label}</p>
      <div className="flex items-center gap-2">
        <button
          onClick={() => onChange(clamp(Number((value - step).toFixed(decimals))))}
          className="flex h-6 w-6 items-center justify-center rounded-md border border-light-border text-light-onSurface/50 hover:border-primary/50 hover:text-primary dark:border-dark-border"
        >
          <Minus size={12} />
        </button>
        <span className="w-10 text-center text-xs font-medium text-light-onSurface/75 dark:text-white/65">
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
