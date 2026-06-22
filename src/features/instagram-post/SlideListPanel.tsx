import { Plus, Trash2, Download } from "lucide-react";
import { Button } from "@/shared/components/ui/Button";
import { cn } from "@/shared/lib/cn";

export function SlideListPanel({
  count,
  activeIndex,
  onSelect,
  onAdd,
  onExport,
  onRemove,
}: {
  count: number;
  activeIndex: number;
  onSelect: (index: number) => void;
  onAdd: () => void;
  onExport: () => void;
  onRemove: () => void;
}) {
  if (count === 0) return null;

  return (
    <>
      <div className="mb-4 flex items-center gap-2 overflow-x-auto">
        {Array.from({ length: count }, (_, i) => (
          <button
            key={i}
            onClick={() => onSelect(i)}
            className={cn(
              "flex h-10 w-10 shrink-0 items-center justify-center rounded-md border text-xs font-medium transition-colors",
              i === activeIndex
                ? "border-primary text-primary bg-primary-soft"
                : "border-light-border text-light-onSurface/60 hover:border-light-border-strong dark:border-dark-border dark:text-white/50"
            )}
          >
            {i + 1}
          </button>
        ))}
        <button
          onClick={onAdd}
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md border border-dashed border-light-border text-light-onSurface/40 hover:border-primary/50 hover:text-primary dark:border-dark-border"
        >
          <Plus size={16} />
        </button>
      </div>

      <div className="mb-6 flex gap-2">
        <Button onClick={onExport} size="sm">
          <Download size={14} /> Exportar PNG
        </Button>
        {count > 1 && (
          <Button variant="danger" size="sm" onClick={onRemove}>
            <Trash2 size={14} /> Remover slide
          </Button>
        )}
      </div>
    </>
  );
}
