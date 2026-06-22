import type { HTMLAttributes } from "react";
import { cn } from "@/shared/lib/cn";

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "rounded-xl border border-light-border bg-light-card shadow-soft dark:border-dark-border dark:bg-dark-card",
        className
      )}
      {...props}
    />
  );
}

export function PageHeader({
  title,
  subtitle,
  eyebrow,
  actions,
}: {
  title: string;
  subtitle?: string | null;
  eyebrow?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-6 flex items-start justify-between gap-4">
      <div>
        {eyebrow && (
          <p className="mb-1 font-mono text-[11px] uppercase tracking-wider text-primary">
            {eyebrow}
          </p>
        )}
        <h1 className="text-xl font-semibold tracking-tight text-light-onSurface dark:text-dark-onSurface">
          {title}
        </h1>
        {subtitle && (
          <p className="mt-1 text-sm text-light-onSurface/55 dark:text-dark-onSurface/50">
            {subtitle}
          </p>
        )}
      </div>
      {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  description,
}: {
  icon?: React.ReactNode;
  title: string;
  description?: string;
}) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 p-10 text-center">
      {icon && (
        <div className="flex h-12 w-12 items-center justify-center rounded-xl border border-light-border bg-light-card text-light-onSurface/40 dark:border-dark-border dark:bg-dark-card dark:text-dark-onSurface/40">
          {icon}
        </div>
      )}
      <p className="text-sm font-medium text-light-onSurface/70 dark:text-dark-onSurface/70">
        {title}
      </p>
      {description && (
        <p className="max-w-xs text-[13px] text-light-onSurface/45 dark:text-dark-onSurface/40">
          {description}
        </p>
      )}
    </div>
  );
}

const badgeColors: Record<string, string> = {
  pending: "#9499A6",
  running: "#F59E0B",
  done: "#16A34A",
  error: "#EF4444",
};

export function Badge({
  status,
  color: colorOverride,
  children,
}: {
  status?: string;
  /** Override the built-in status→color map (e.g. with a domain-specific color table). */
  color?: string;
  children: React.ReactNode;
}) {
  const color = colorOverride ?? (status && badgeColors[status]) ?? "#5B5FEF";
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 font-mono text-[10px] font-medium uppercase tracking-wide"
      style={{ color, backgroundColor: `${color}1A` }}
    >
      {status === "running" && (
        <span className="h-1.5 w-1.5 animate-pulse rounded-full" style={{ backgroundColor: color }} />
      )}
      {children}
    </span>
  );
}
