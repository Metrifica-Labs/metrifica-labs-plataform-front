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
      <span className="text-2xs text-light-onSurface/45 dark:text-white/35">{label}</span>
      <input
        type="color"
        value={toHexColor(value)}
        onChange={(e) => onChange(e.target.value)}
        className="h-7 w-11 cursor-pointer rounded-md border border-light-border bg-transparent dark:border-dark-border"
      />
    </div>
  );
}
