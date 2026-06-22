import { cn } from "@/shared/lib/cn";

export function Tabs<T extends string>({
  value,
  onChange,
  items,
}: {
  value: T;
  onChange: (v: T) => void;
  items: { value: T; label: string }[];
}) {
  return (
    <div className="inline-flex items-center gap-1 rounded-lg border border-light-border bg-light-raised p-1 dark:border-dark-border dark:bg-dark-raised">
      {items.map((item) => (
        <button
          key={item.value}
          onClick={() => onChange(item.value)}
          className={cn(
            "rounded-md px-3 py-1.5 text-sm2 font-medium transition-colors",
            value === item.value
              ? "bg-primary text-white shadow-soft"
              : "text-light-onSurface/55 hover:text-light-onSurface dark:text-dark-onSurface/50 dark:hover:text-dark-onSurface"
          )}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}
