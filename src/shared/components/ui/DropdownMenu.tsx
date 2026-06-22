import { useEffect, useRef, useState, type ReactNode } from "react";
import { cn } from "@/shared/lib/cn";

export function DropdownMenu({
  trigger,
  items,
}: {
  trigger: ReactNode;
  items: { label: string; onClick: () => void; danger?: boolean }[];
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, [open]);

  return (
    <div ref={ref} className="relative inline-block">
      <button onClick={() => setOpen((o) => !o)}>{trigger}</button>
      {open && (
        <div className="absolute right-0 bottom-full z-50 mb-1.5 w-44 rounded-lg border border-light-border bg-light-card p-1 shadow-floating dark:border-dark-border dark:bg-dark-card">
          {items.map((item) => (
            <button
              key={item.label}
              onClick={() => {
                item.onClick();
                setOpen(false);
              }}
              className={cn(
                "block w-full rounded-md px-2.5 py-1.5 text-left text-sm2 font-medium transition-colors hover:bg-light-onSurface/6 dark:hover:bg-white/6",
                item.danger ? "text-danger" : "text-light-onSurface/80 dark:text-dark-onSurface/80"
              )}
            >
              {item.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
