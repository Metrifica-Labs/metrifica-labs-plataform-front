import { cn } from "@/shared/lib/cn";

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
