import { ImagePlus, Repeat2, Trash2 } from "lucide-react";

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
            className="flex items-center gap-1 rounded-md bg-primary px-2 py-1 text-2xs font-medium text-white"
          >
            <Repeat2 size={11} /> Trocar
          </button>
          <button
            onClick={onClear}
            className="flex items-center gap-1 rounded-md bg-black/60 px-2 py-1 text-2xs font-medium text-white"
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
