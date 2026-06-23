import { useEffect, useRef, useState } from "react";
import { History } from "lucide-react";
import { useInstagramPost } from "@/features/instagram-post/useInstagramPost";
import { useInstagramPublish } from "@/features/instagram-post/useInstagramPublish";
import { useGeneration } from "@/features/generation/useGeneration";
import { isGenerating } from "@/features/generation/generation-types";
import { exportSlideToPng, exportAllSlidesToPng } from "@/features/instagram-post/post-export";
import {
  loadIgPostHistory,
  addIgPostHistoryEntry,
  removeIgPostHistoryEntry,
  type IgPostHistoryEntry,
} from "@/features/instagram-post/ig-post-history";
import { PageHeader } from "@/shared/components/ui/Card";
import { IconButton } from "@/shared/components/ui/Button";
import { useToast } from "@/shared/hooks/useToast";
import type { SlideLayout } from "@/features/instagram-post/instagram-post-style";
import { FLOW_SLUG, IMAGE_COVER_PROMPT_SUFFIX } from "@/features/instagram-post/post-ui-constants";
import { CanvasPreview, SlideCanvas } from "@/features/instagram-post/CanvasPreview";
import { SlideListPanel } from "@/features/instagram-post/SlideListPanel";
import { ContentGenerator } from "@/features/instagram-post/ContentGenerator";
import { StyleEditorPanel } from "@/features/instagram-post/StyleEditorPanel";
import { HistoryPanel } from "@/features/instagram-post/HistoryPanel";
import { PublishPanel } from "@/features/instagram-post/PublishPanel";

export function InstagramPostPage() {
  const post = useInstagramPost();
  const generation = useGeneration();
  const toast = useToast();
  const publish = useInstagramPublish(post.style.slides.length);
  const [briefing, setBriefing] = useState("");
  const [history, setHistory] = useState<IgPostHistoryEntry[]>(() => loadIgPostHistory());
  const [showHistory, setShowHistory] = useState(false);
  const canvasRef = useRef<HTMLDivElement>(null);
  const appliedOutputRef = useRef<string | null>(null);
  const reportedErrorRef = useRef<string | null>(null);

  const slide = post.style.slides[post.activeIndex];
  const generating = isGenerating(generation.state.status);

  useEffect(() => {
    if (
      generation.state.status === "done" &&
      generation.state.output &&
      generation.state.output !== appliedOutputRef.current
    ) {
      appliedOutputRef.current = generation.state.output;
      post.loadFromGeneration(generation.state.output);
      const nextHistory = addIgPostHistoryEntry(briefing, post.style.slides, post.style);
      setHistory(nextHistory);
      toast.success("Carrossel gerado e salvo no histórico.");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [generation.state.status, generation.state.output]);

  useEffect(() => {
    const error = generation.state.error;
    if (error && error !== reportedErrorRef.current) {
      reportedErrorRef.current = error;
      toast.error(error);
    }
    if (!error) reportedErrorRef.current = null;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [generation.state.error]);

  function handleGenerate() {
    if (!briefing.trim() || generating) return;
    const suffix = post.style.defaultLayout === "imageCover" ? IMAGE_COVER_PROMPT_SUFFIX : "";
    generation.generate(FLOW_SLUG, briefing + suffix);
  }

  async function handleExport() {
    if (!canvasRef.current) return;
    try {
      await exportSlideToPng(canvasRef.current, `slide-${post.activeIndex + 1}.png`);
      toast.success(`Slide ${post.activeIndex + 1} exportado em PNG.`);
    } catch {
      toast.error("Não foi possível exportar o slide. Tente novamente.");
    }
  }

  async function handleExportAll() {
    const nodes = publish.getNodes();
    if (nodes.length === 0) return;
    try {
      await exportAllSlidesToPng(nodes);
      toast.success(`${nodes.length} slides exportados em PNG.`);
    } catch {
      toast.error("Não foi possível exportar todos os slides. Tente novamente.");
    }
  }

  function handleReset() {
    appliedOutputRef.current = null;
    generation.clear();
    post.loadSlides([]);
  }

  function handleRestore(entry: IgPostHistoryEntry) {
    post.loadSlides(entry.slides);
    setShowHistory(false);
    toast.info("Carrossel restaurado do histórico.");
  }

  function handleDeleteHistory(id: string) {
    setHistory(removeIgPostHistoryEntry(id));
  }

  return (
    <div className="flex h-full">
      <div className="flex-1 overflow-y-auto p-6">
        <PageHeader
          eyebrow="Ferramenta"
          title="Instagram Post"
          subtitle="A IA gera o texto do carrossel; o layout é montado por código e exportado em PNG."
          actions={
            <IconButton onClick={() => setShowHistory((v) => !v)} title="Histórico">
              <History size={16} />
            </IconButton>
          }
        />

        <CanvasPreview
          style={post.style}
          slide={slide}
          index={post.activeIndex}
          total={post.style.slides.length}
          innerRef={canvasRef}
        />

        <SlideListPanel
          count={post.style.slides.length}
          activeIndex={post.activeIndex}
          onSelect={post.setActiveIndex}
          onAdd={post.addSlide}
          onExport={handleExport}
          onExportAll={handleExportAll}
          onRemove={() => post.removeSlide(post.activeIndex)}
        />

        <ContentGenerator
          briefing={briefing}
          onBriefingChange={setBriefing}
          defaultLayout={post.style.defaultLayout}
          onLayoutChange={(layout: SlideLayout) => post.updateStyle({ defaultLayout: layout })}
          generating={generating}
          status={generation.state.status}
          hasSlides={post.style.slides.length > 0}
          onGenerate={handleGenerate}
          onReset={handleReset}
        />
      </div>

      <div data-testid="style-editor-panel" className="w-[340px] shrink-0 space-y-4 overflow-y-auto border-l border-light-border bg-light-surface p-4 dark:border-dark-border dark:bg-dark-surface">
        {slide && <StyleEditorPanel post={post} slide={slide} />}
        <PublishPanel publish={publish} />
      </div>

      {/* Hidden render area — all slides rendered off-screen for export+publish */}
      <div aria-hidden style={{ position: "absolute", top: -99999, left: -99999, pointerEvents: "none" }}>
        {post.style.slides.map((s, i) => (
          <SlideCanvas
            key={i}
            layout={s.layout}
            style={post.style}
            slide={s}
            index={i}
            total={post.style.slides.length}
            innerRef={publish.setRef(i)}
          />
        ))}
      </div>

      <HistoryPanel
        open={showHistory}
        history={history}
        onClose={() => setShowHistory(false)}
        onRestore={handleRestore}
        onDelete={handleDeleteHistory}
      />
    </div>
  );
}
