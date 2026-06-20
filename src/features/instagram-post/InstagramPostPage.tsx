import { useRef, useState } from "react";
import { Plus, Trash2, Download, History } from "lucide-react";
import { useInstagramPost } from "@/features/instagram-post/useInstagramPost";
import { PostCanvas } from "@/features/instagram-post/PostCanvas";
import { PostCanvasType2 } from "@/features/instagram-post/PostCanvasType2";
import { PostCanvasType3 } from "@/features/instagram-post/PostCanvasType3";
import { PostCanvasType4 } from "@/features/instagram-post/PostCanvasType4";
import { exportSlideToPng } from "@/features/instagram-post/post-export";
import {
  AVAILABLE_FONTS,
  BACKGROUND_SWATCHES,
  type SlideLayout,
} from "@/features/instagram-post/instagram-post-style";
import {
  loadIgPostHistory,
  addIgPostHistoryEntry,
  type IgPostHistoryEntry,
} from "@/features/instagram-post/ig-post-history";

const LAYOUT_LABELS: Record<SlideLayout, string> = {
  textPost: "Tipo 1 — Texto",
  imageCover: "Tipo 2 — Capa",
  textGrid: "Tipo 3 — Grade",
  imageStack: "Tipo 4 — Empilhado",
};

function CanvasFor({
  layout,
  ...props
}: {
  layout: SlideLayout;
  style: ReturnType<typeof useInstagramPost>["style"];
  slide: ReturnType<typeof useInstagramPost>["style"]["slides"][number];
  index: number;
  total: number;
  innerRef?: React.Ref<HTMLDivElement>;
}) {
  switch (layout) {
    case "imageCover":
      return <PostCanvasType2 {...props} />;
    case "textGrid":
      return <PostCanvasType3 {...props} />;
    case "imageStack":
      return <PostCanvasType4 {...props} />;
    default:
      return <PostCanvas {...props} />;
  }
}

export function InstagramPostPage() {
  const post = useInstagramPost();
  const [briefing, setBriefing] = useState("");
  const [history, setHistory] = useState<IgPostHistoryEntry[]>(() => loadIgPostHistory());
  const [showHistory, setShowHistory] = useState(false);
  const canvasRef = useRef<HTMLDivElement>(null);

  const slide = post.style.slides[post.activeIndex];

  async function handleExport() {
    if (!canvasRef.current) return;
    await exportSlideToPng(canvasRef.current, `slide-${post.activeIndex + 1}.png`);
  }

  function handleSaveToHistory() {
    const next = addIgPostHistoryEntry(briefing, post.style.slides, post.style);
    setHistory(next);
  }

  return (
    <div className="flex h-full">
      <div className="flex-1 overflow-y-auto p-6">
        <div className="mb-4 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-light-onSurface dark:text-white">
            Instagram Post
          </h1>
          <button onClick={() => setShowHistory((v) => !v)} className="text-light-onSurface/50 dark:text-white/40">
            <History size={18} />
          </button>
        </div>

        <textarea
          value={briefing}
          onChange={(e) => setBriefing(e.target.value)}
          placeholder="Cole o conteúdo gerado (JSON com slides) ou escreva diretamente..."
          rows={3}
          className="mb-2 w-full rounded-md border border-light-border-strong bg-transparent p-3 text-sm outline-none focus:border-primary dark:border-dark-border"
        />
        <button
          onClick={() => post.loadFromGeneration(briefing)}
          className="mb-6 rounded-md border border-light-border px-3 py-1.5 text-xs dark:border-dark-border"
        >
          Carregar slides do texto
        </button>

        <div className="mb-4 flex items-center justify-center rounded-xl bg-light-onSurface/5 p-6 dark:bg-white/5">
          {slide && (
            <CanvasFor
              layout={slide.layout}
              style={post.style}
              slide={slide}
              index={post.activeIndex}
              total={post.style.slides.length}
              innerRef={canvasRef}
            />
          )}
        </div>

        <div className="mb-4 flex items-center gap-2 overflow-x-auto">
          {post.style.slides.map((_, i) => (
            <button
              key={i}
              onClick={() => post.setActiveIndex(i)}
              className={`h-10 w-10 shrink-0 rounded-md border text-xs ${
                i === post.activeIndex ? "border-primary text-primary" : "border-light-border dark:border-dark-border"
              }`}
            >
              {i + 1}
            </button>
          ))}
          <button onClick={post.addSlide} className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md border border-dashed border-light-border dark:border-dark-border">
            <Plus size={16} />
          </button>
        </div>

        <div className="flex gap-2">
          <button
            onClick={handleExport}
            className="flex items-center gap-1.5 rounded-md bg-primary px-3 py-2 text-sm font-medium text-white"
          >
            <Download size={14} /> Exportar PNG
          </button>
          <button onClick={handleSaveToHistory} className="rounded-md border border-light-border px-3 py-2 text-sm dark:border-dark-border">
            Salvar no histórico
          </button>
          {post.style.slides.length > 1 && (
            <button
              onClick={() => post.removeSlide(post.activeIndex)}
              className="flex items-center gap-1.5 rounded-md border border-red-500/30 px-3 py-2 text-sm text-red-500"
            >
              <Trash2 size={14} /> Remover slide
            </button>
          )}
        </div>
      </div>

      <div className="w-72 shrink-0 overflow-y-auto border-l border-light-border bg-light-card p-4 dark:border-dark-border dark:bg-dark-card">
        <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-light-onSurface/40 dark:text-white/40">
          Slide
        </h2>
        {slide && (
          <div className="mb-6 space-y-3">
            <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
              Headline
              <textarea
                value={slide.headline}
                onChange={(e) => post.updateSlide(post.activeIndex, { headline: e.target.value })}
                rows={2}
                className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm outline-none dark:border-dark-border"
              />
            </label>
            <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
              Body
              <textarea
                value={slide.body}
                onChange={(e) => post.updateSlide(post.activeIndex, { body: e.target.value })}
                rows={3}
                className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm outline-none dark:border-dark-border"
              />
            </label>
            <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
              Layout
              <select
                value={slide.layout}
                onChange={(e) => post.updateSlide(post.activeIndex, { layout: e.target.value as SlideLayout })}
                className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm dark:border-dark-border"
              >
                {Object.entries(LAYOUT_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
            </label>
          </div>
        )}

        <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-light-onSurface/40 dark:text-white/40">
          Estilo global
        </h2>
        <div className="space-y-3">
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Nome
            <input
              value={post.style.profileName}
              onChange={(e) => post.updateStyle({ profileName: e.target.value })}
              className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm outline-none dark:border-dark-border"
            />
          </label>
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Handle
            <input
              value={post.style.handle}
              onChange={(e) => post.updateStyle({ handle: e.target.value })}
              className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm outline-none dark:border-dark-border"
            />
          </label>
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Fonte
            <select
              value={post.style.bodyFont}
              onChange={(e) => post.updateStyle({ bodyFont: e.target.value, nameFont: e.target.value, handleFont: e.target.value, counterFont: e.target.value })}
              className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm dark:border-dark-border"
            >
              {AVAILABLE_FONTS.map((font) => (
                <option key={font} value={font}>
                  {font}
                </option>
              ))}
            </select>
          </label>
          <div>
            <p className="mb-1.5 text-xs text-light-onSurface/60 dark:text-white/50">Fundo</p>
            <div className="flex flex-wrap gap-1.5">
              {BACKGROUND_SWATCHES.map((color) => (
                <button
                  key={color}
                  onClick={() => post.updateStyle({ bgColor: color })}
                  style={{ backgroundColor: color }}
                  className={`h-6 w-6 rounded-full border ${
                    post.style.bgColor === color ? "border-primary" : "border-light-border dark:border-dark-border"
                  }`}
                />
              ))}
            </div>
          </div>
        </div>
      </div>

      {showHistory && (
        <div className="fixed inset-y-0 right-0 z-50 w-80 border-l border-light-border bg-light-card p-4 shadow-lg dark:border-dark-border dark:bg-dark-card">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-sm font-medium">Histórico</h3>
            <button onClick={() => setShowHistory(false)} className="text-xs text-light-onSurface/50">
              Fechar
            </button>
          </div>
          <div className="space-y-2">
            {history.map((entry) => (
              <button
                key={entry.id}
                onClick={() => {
                  post.loadSlides(entry.slides);
                  setShowHistory(false);
                }}
                className="block w-full rounded-md border border-light-border p-2 text-left text-xs dark:border-dark-border"
              >
                <p className="truncate">{entry.briefing || "(sem briefing)"}</p>
                <p className="text-light-onSurface/40">{new Date(entry.createdAt).toLocaleString("pt-BR")}</p>
              </button>
            ))}
            {history.length === 0 && (
              <p className="text-xs text-light-onSurface/40">Sem histórico ainda.</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
