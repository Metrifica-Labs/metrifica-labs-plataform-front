import { useEffect, useRef, useState } from "react";
import {
  Plus,
  Trash2,
  Download,
  History,
  Sparkles,
  RotateCcw,
  X,
  User,
  Image as ImageIcon,
  Type as TypeIcon,
  Bold,
  Italic,
  Underline,
  Palette,
  SlidersHorizontal,
  TextCursorInput,
  Highlighter,
} from "lucide-react";
import { useInstagramPost } from "@/features/instagram-post/useInstagramPost";
import { useGeneration } from "@/features/generation/useGeneration";
import { isGenerating } from "@/features/generation/generation-types";
import { PostCanvas } from "@/features/instagram-post/PostCanvas";
import { PostCanvasType2 } from "@/features/instagram-post/PostCanvasType2";
import { PostCanvasType3 } from "@/features/instagram-post/PostCanvasType3";
import { PostCanvasType4 } from "@/features/instagram-post/PostCanvasType4";
import { exportSlideToPng } from "@/features/instagram-post/post-export";
import { pickImageDataUrl } from "@/features/instagram-post/pick-image";
import {
  AVAILABLE_FONTS,
  CREATOR_PRESETS,
  HIGHLIGHT_SWATCHES,
  type ImageCoverVariant,
  type SlideLayout,
} from "@/features/instagram-post/instagram-post-style";
import {
  loadIgPostHistory,
  addIgPostHistoryEntry,
  type IgPostHistoryEntry,
} from "@/features/instagram-post/ig-post-history";
import { PageHeader, Card } from "@/shared/components/ui/Card";
import { Button, IconButton } from "@/shared/components/ui/Button";
import { Textarea, Input, Select, Label } from "@/shared/components/ui/Field";
import { cn } from "@/shared/lib/cn";
import {
  SectionCard,
  Chip,
  SwatchRow,
  ColorRow,
  Stepper,
  ImagePicker,
  AlignSelector,
  MarkupHintInline,
  Toggle,
} from "@/features/instagram-post/controls";

const FLOW_SLUG = "instagram-text-post";

const LAYOUT_LABELS: Record<SlideLayout, string> = {
  textPost: "Tipo 1 — Texto",
  imageCover: "Tipo 2 — Capa",
  textGrid: "Tipo 3 — Grade",
  imageStack: "Tipo 4 — Empilhado",
};

const LAYOUT_SUBTITLES: Record<SlideLayout, string> = {
  textPost: "Texto + perfil",
  imageCover: "Imagem de fundo",
  textGrid: "Grade de textos",
  imageStack: "Pilha de imagens",
};

const COVER_VARIANT_LABELS: Record<ImageCoverVariant, string> = {
  logoMid: "Logo + título em card",
  logoTop: "Logo topo + cards",
  subtitleTop: "Subtítulo antes",
  logoTopInline: "Texto sobre imagem",
};

const STATUS_LABELS: Record<string, string> = {
  connecting: "Conectando ao modelo...",
  thinking: "Pensando...",
  streaming: "Gerando conteúdo...",
};

const IMAGE_COVER_PROMPT_SUFFIX = `

---
TIPO DE LAYOUT SELECIONADO: Tipo 2 — Image Cover (imagem de fundo full-bleed)
Adapte os slides para este formato:
- "headline": título curto e impactante (máximo 7 palavras) — aparece em card sobre a imagem
- "body": subtítulo breve e opcional (máximo 20 palavras, pode ser string vazia "")
- "swipeText": texto de swipe opcional em português (ex: "Arraste para o lado →", ou "" para omitir)
O JSON de cada slide deve ter os três campos: headline, body, swipeText.`;

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
  const generation = useGeneration();
  const [briefing, setBriefing] = useState("");
  const [history, setHistory] = useState<IgPostHistoryEntry[]>(() => loadIgPostHistory());
  const [showHistory, setShowHistory] = useState(false);
  const canvasRef = useRef<HTMLDivElement>(null);
  const appliedOutputRef = useRef<string | null>(null);

  const slide = post.style.slides[post.activeIndex];
  const generating = isGenerating(generation.state.status);
  const isType2 = slide?.layout === "imageCover";
  const isType3 = slide?.layout === "textGrid";
  const isType4 = slide?.layout === "imageStack";
  const isType1 = slide && !isType2 && !isType3 && !isType4;

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
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [generation.state.status, generation.state.output]);

  function handleGenerate() {
    if (!briefing.trim() || generating) return;
    const suffix = post.style.defaultLayout === "imageCover" ? IMAGE_COVER_PROMPT_SUFFIX : "";
    generation.generate(FLOW_SLUG, briefing + suffix);
  }

  async function handleExport() {
    if (!canvasRef.current) return;
    await exportSlideToPng(canvasRef.current, `slide-${post.activeIndex + 1}.png`);
  }

  function patchSlide(patch: Partial<typeof slide>) {
    post.updateSlide(post.activeIndex, patch as never);
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

        <div className="mb-4 flex items-center justify-center rounded-xl bg-light-onSurface/5 p-6 dark:bg-white/5">
          {slide ? (
            <CanvasFor
              layout={slide.layout}
              style={post.style}
              slide={slide}
              index={post.activeIndex}
              total={post.style.slides.length}
              innerRef={canvasRef}
            />
          ) : (
            <div className="flex h-[480px] w-full max-w-[380px] items-center justify-center rounded-xl border border-dashed border-light-border text-center text-[13px] text-light-onSurface/35 dark:border-dark-border dark:text-white/30">
              O preview aparece após gerar o conteúdo.
            </div>
          )}
        </div>

        {post.style.slides.length > 0 && (
          <>
            <div className="mb-4 flex items-center gap-2 overflow-x-auto">
              {post.style.slides.map((_, i) => (
                <button
                  key={i}
                  onClick={() => post.setActiveIndex(i)}
                  className={cn(
                    "flex h-10 w-10 shrink-0 items-center justify-center rounded-md border text-xs font-medium transition-colors",
                    i === post.activeIndex
                      ? "border-primary text-primary bg-primary-soft"
                      : "border-light-border text-light-onSurface/60 hover:border-light-border-strong dark:border-dark-border dark:text-white/50"
                  )}
                >
                  {i + 1}
                </button>
              ))}
              <button
                onClick={post.addSlide}
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md border border-dashed border-light-border text-light-onSurface/40 hover:border-primary/50 hover:text-primary dark:border-dark-border"
              >
                <Plus size={16} />
              </button>
            </div>

            <div className="mb-6 flex gap-2">
              <Button onClick={handleExport} size="sm">
                <Download size={14} /> Exportar PNG
              </Button>
              {post.style.slides.length > 1 && (
                <Button variant="danger" size="sm" onClick={() => post.removeSlide(post.activeIndex)}>
                  <Trash2 size={14} /> Remover slide
                </Button>
              )}
            </div>
          </>
        )}

        <Card className="p-4">
          <div className="mb-3 flex items-center gap-1.5 text-[13px] font-semibold text-light-onSurface/75 dark:text-dark-onSurface/75">
            <Sparkles size={14} className="text-primary" />
            Conteúdo (IA)
          </div>

          <p className="mb-2 text-[11px] text-light-onSurface/40 dark:text-white/30">
            Tipo de layout — define como a IA vai gerar o conteúdo
          </p>
          <div className="mb-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
            {(Object.keys(LAYOUT_LABELS) as SlideLayout[]).map((layout) => (
              <button
                key={layout}
                onClick={() => post.updateStyle({ defaultLayout: layout })}
                className={cn(
                  "rounded-lg border px-3 py-2 text-left transition-colors",
                  post.style.defaultLayout === layout
                    ? "border-primary/50 bg-primary-soft"
                    : "border-light-border hover:border-light-border-strong dark:border-dark-border"
                )}
              >
                <p
                  className={cn(
                    "text-xs font-semibold",
                    post.style.defaultLayout === layout
                      ? "text-primary"
                      : "text-light-onSurface/70 dark:text-white/60"
                  )}
                >
                  {LAYOUT_LABELS[layout].split("—")[0].trim()}
                </p>
                <p className="text-[10px] text-light-onSurface/40 dark:text-white/30">
                  {LAYOUT_SUBTITLES[layout]}
                </p>
              </button>
            ))}
          </div>

          <Textarea
            value={briefing}
            onChange={(e) => setBriefing(e.target.value)}
            placeholder="Ex: carrossel sobre os 3 erros que travam a operação de uma PME..."
            rows={3}
            disabled={generating}
            className="mb-3"
          />
          <div className="flex items-center justify-between">
            {generating ? (
              <p className="flex items-center gap-2 text-xs text-light-onSurface/50 dark:text-white/40">
                <span className="h-3 w-3 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
                {STATUS_LABELS[generation.state.status] ?? "Processando..."}
              </p>
            ) : (
              <span />
            )}
            <div className="flex items-center gap-2">
              {post.style.slides.length > 0 && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    appliedOutputRef.current = null;
                    generation.clear();
                    post.loadSlides([]);
                  }}
                >
                  <RotateCcw size={13} /> Novo carrossel
                </Button>
              )}
              <Button onClick={handleGenerate} disabled={generating || !briefing.trim()} size="sm">
                {generating ? "Gerando..." : "Gerar conteúdo"}
              </Button>
            </div>
          </div>
          {generation.state.error && (
            <p className="mt-3 rounded-md border border-red-500/20 bg-red-500/5 px-3 py-2 text-[13px] text-red-500">
              {generation.state.error}
            </p>
          )}
        </Card>
      </div>

      <div className="w-[340px] shrink-0 space-y-4 overflow-y-auto border-l border-light-border bg-light-surface p-4 dark:border-dark-border dark:bg-dark-surface">
        {slide && (
          <>
            {/* ── Editor de texto do slide ── */}
            <SectionCard title="Texto dos slides" icon={<TextCursorInput size={14} className="text-primary" />}>
              <div className="space-y-3">
                <div>
                  <Label>Headline {isType4 && "(card 1, opcional)"}</Label>
                  <Textarea
                    value={slide.headline}
                    onChange={(e) => patchSlide({ headline: e.target.value })}
                    rows={2}
                  />
                </div>
                <div>
                  <Label>{isType4 ? "Body (card 2, opcional)" : "Texto de apoio"}</Label>
                  <Textarea value={slide.body} onChange={(e) => patchSlide({ body: e.target.value })} rows={3} />
                </div>
                <MarkupHintInline />
              </div>

              <div className="mt-4 border-t border-light-border pt-3 dark:border-dark-border" />

              {isType1 && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-light-onSurface/65 dark:text-white/55">
                      Mostrar perfil neste slide
                    </span>
                    <Toggle checked={slide.showHeader} onChange={(v) => patchSlide({ showHeader: v })} />
                  </div>
                  <div>
                    <Label>Imagem do slide</Label>
                    <ImagePicker
                      src={slide.imageUrl}
                      onPick={async () => {
                        const url = await pickImageDataUrl();
                        if (url) patchSlide({ imageUrl: url });
                      }}
                      onClear={() => patchSlide({ imageUrl: null })}
                    />
                    {slide.imageUrl && (
                      <div className="mt-2 flex items-center gap-2">
                        <Chip label="Acima" active={slide.imageAbove} onClick={() => patchSlide({ imageAbove: true })} />
                        <Chip label="Abaixo" active={!slide.imageAbove} onClick={() => patchSlide({ imageAbove: false })} />
                      </div>
                    )}
                  </div>
                </div>
              )}

              {(isType2 || isType3 || isType4) && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-light-onSurface/65 dark:text-white/55">
                    Exibir contador neste slide
                  </span>
                  <Toggle checked={slide.showCounter} onChange={(v) => patchSlide({ showCounter: v })} />
                </div>
              )}

              <div className="mt-3 border-t border-light-border pt-3 dark:border-dark-border" />
              <Label>Layout</Label>
              <Select
                value={slide.layout}
                onChange={(e) => patchSlide({ layout: e.target.value as SlideLayout })}
              >
                {Object.entries(LAYOUT_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </Select>

              {isType2 && (
                <div className="mt-3 space-y-3">
                  <Label>Imagem de capa</Label>
                  <ImagePicker
                    src={slide.coverImageUrl}
                    height={120}
                    emptyLabel="Adicionar imagem de fundo"
                    onPick={async () => {
                      const url = await pickImageDataUrl();
                      if (url) patchSlide({ coverImageUrl: url });
                    }}
                    onClear={() => patchSlide({ coverImageUrl: null })}
                  />
                  <div>
                    <p className="mb-1.5 text-[11px] text-light-onSurface/45 dark:text-white/35">
                      Variante do layout
                    </p>
                    <div className="flex flex-wrap gap-1.5">
                      {Object.entries(COVER_VARIANT_LABELS).map(([value, label]) => (
                        <Chip
                          key={value}
                          label={label}
                          active={slide.coverVariant === value}
                          onClick={() => patchSlide({ coverVariant: value as ImageCoverVariant })}
                        />
                      ))}
                    </div>
                  </div>
                  <div>
                    <Label>Texto de swipe (opcional)</Label>
                    <Input value={slide.swipeText} onChange={(e) => patchSlide({ swipeText: e.target.value })} />
                  </div>
                </div>
              )}

              {isType3 && (
                <div className="mt-3 space-y-3">
                  <div className="flex items-center justify-between">
                    <Label className="mb-0">Alinhamento</Label>
                    <AlignSelector value={slide.textAlign} onChange={(v) => patchSlide({ textAlign: v })} />
                  </div>
                  <Stepper
                    label="Espaço entre linhas (×)"
                    value={slide.gridSpacing}
                    min={1}
                    max={4}
                    step={0.1}
                    decimals={1}
                    onChange={(v) => patchSlide({ gridSpacing: v })}
                  />
                  <ImagePicker
                    src={slide.coverImageUrl}
                    height={100}
                    emptyLabel="Imagem de fundo"
                    onPick={async () => {
                      const url = await pickImageDataUrl();
                      if (url) patchSlide({ coverImageUrl: url });
                    }}
                    onClear={() => patchSlide({ coverImageUrl: null })}
                  />
                  {(["Topo esquerdo", "Topo direito", "Base esquerdo", "Base direito"] as const).map(
                    (label, idx) => (
                      <div key={idx}>
                        <div className="mb-1 flex items-center justify-between">
                          <p className="text-[11px] text-light-onSurface/45 dark:text-white/35">{label}</p>
                          <Chip
                            label="Negrito"
                            icon={<Bold size={11} />}
                            active={slide.gridBolds[idx]}
                            onClick={() => post.updateGridBold(post.activeIndex, idx, !slide.gridBolds[idx])}
                          />
                        </div>
                        <Textarea
                          value={slide.gridTexts[idx]}
                          onChange={(e) => post.updateGridText(post.activeIndex, idx, e.target.value)}
                          rows={2}
                          placeholder="Texto (opcional)"
                        />
                      </div>
                    )
                  )}
                </div>
              )}

              {isType4 && (
                <div className="mt-3 space-y-3">
                  <div className="flex items-center justify-between">
                    <Label className="mb-0">Alinhamento</Label>
                    <AlignSelector value={slide.textAlign} onChange={(v) => patchSlide({ textAlign: v })} />
                  </div>
                  <div>
                    <Label>Imagem 1</Label>
                    <ImagePicker
                      src={slide.imageUrl}
                      onPick={async () => {
                        const url = await pickImageDataUrl();
                        if (url) patchSlide({ imageUrl: url });
                      }}
                      onClear={() => patchSlide({ imageUrl: null })}
                    />
                  </div>
                  <div>
                    <Label>Imagem 2</Label>
                    <ImagePicker
                      src={slide.coverImageUrl}
                      onPick={async () => {
                        const url = await pickImageDataUrl();
                        if (url) patchSlide({ coverImageUrl: url });
                      }}
                      onClear={() => patchSlide({ coverImageUrl: null })}
                    />
                  </div>
                </div>
              )}
            </SectionCard>

            {/* ── Perfil (apenas Tipo 1) ── */}
            {isType1 && (
              <SectionCard title="Perfil" icon={<User size={14} className="text-primary" />}>
                <div className="space-y-3">
                  <div className="flex gap-3">
                    <button
                      onClick={async () => {
                        const url = await pickImageDataUrl();
                        if (url) post.updateStyle({ avatarUrl: url });
                      }}
                      className="h-12 w-12 shrink-0 overflow-hidden rounded-full border border-light-border bg-light-card dark:border-dark-border dark:bg-dark-card"
                    >
                      {post.style.avatarUrl ? (
                        <img src={post.style.avatarUrl} className="h-full w-full object-cover" />
                      ) : (
                        <User size={18} className="m-auto text-light-onSurface/30" />
                      )}
                    </button>
                    <div className="flex-1 space-y-2">
                      <Input
                        value={post.style.profileName}
                        onChange={(e) => post.updateStyle({ profileName: e.target.value })}
                        placeholder="Nome"
                      />
                      <Input
                        value={post.style.handle}
                        onChange={(e) => post.updateStyle({ handle: e.target.value })}
                        placeholder="@perfil"
                      />
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    <Chip
                      label="Verificado"
                      active={post.style.showVerifiedBadge}
                      onClick={() => post.updateStyle({ showVerifiedBadge: !post.style.showVerifiedBadge })}
                    />
                    <Chip
                      label="Centralizar conteúdo"
                      active={post.style.centerContent}
                      onClick={() => post.updateStyle({ centerContent: !post.style.centerContent })}
                    />
                  </div>
                  <div>
                    <Label>Logo</Label>
                    <ImagePicker
                      src={post.style.logoUrl}
                      height={64}
                      emptyLabel="Adicionar logo"
                      onPick={async () => {
                        const url = await pickImageDataUrl("image/*,.svg");
                        if (url) post.updateStyle({ logoUrl: url });
                      }}
                      onClear={() => post.updateStyle({ logoUrl: null })}
                    />
                  </div>
                </div>
              </SectionCard>
            )}

            {/* ── Logo (Tipo 2) ── */}
            {isType2 && (
              <SectionCard title="Logo" icon={<ImageIcon size={14} className="text-primary" />}>
                <ImagePicker
                  src={post.style.logoUrl}
                  height={64}
                  emptyLabel="Adicionar logo"
                  onPick={async () => {
                    const url = await pickImageDataUrl("image/*,.svg");
                    if (url) post.updateStyle({ logoUrl: url });
                  }}
                  onClear={() => post.updateStyle({ logoUrl: null })}
                />
              </SectionCard>
            )}

            {/* ── Estilo do criador (Tipo 1) ── */}
            {isType1 && (
              <SectionCard title="Estilo do criador" icon={<Palette size={14} className="text-primary" />}>
                <div className="flex flex-wrap gap-1.5">
                  {CREATOR_PRESETS.map((preset) => (
                    <Chip
                      key={preset.name}
                      label={preset.name}
                      icon={
                        <span
                          className="h-3 w-3 rounded-full border border-light-border dark:border-dark-border"
                          style={{ backgroundColor: preset.bgColor }}
                        />
                      }
                      active={post.style.bgColor === preset.bgColor && post.style.textColor === preset.textColor}
                      onClick={() =>
                        post.updateStyle({
                          bgColor: preset.bgColor,
                          textColor: preset.textColor,
                          nameFont: preset.nameFont,
                          handleFont: preset.handleFont,
                          bodyFont: preset.bodyFont,
                          counterFont: preset.counterFont,
                        })
                      }
                    />
                  ))}
                </div>
              </SectionCard>
            )}

            {/* ── Fontes ── */}
            <SectionCard title="Fontes" icon={<TypeIcon size={14} className="text-primary" />}>
              <div className="space-y-2.5">
                {isType1 && (
                  <FontRow
                    label="Nome"
                    value={post.style.nameFont}
                    onChange={(v) => post.updateStyle({ nameFont: v })}
                  />
                )}
                {isType1 && (
                  <FontRow
                    label="@ do perfil"
                    value={post.style.handleFont}
                    onChange={(v) => post.updateStyle({ handleFont: v })}
                  />
                )}
                <FontRow
                  label="Conteúdo"
                  value={post.style.bodyFont}
                  onChange={(v) => post.updateStyle({ bodyFont: v })}
                />
                <FontRow
                  label="Contagem (1/N)"
                  value={post.style.counterFont}
                  onChange={(v) => post.updateStyle({ counterFont: v })}
                />
              </div>
            </SectionCard>

            {/* ── Headline / Body / Extras ── */}
            <SectionCard title="Headline" icon={<Bold size={14} className="text-primary" />}>
              <div className="mb-3 flex flex-wrap gap-1.5">
                <Chip
                  label="Negrito"
                  icon={<Bold size={11} />}
                  active={post.style.bold}
                  onClick={() => post.updateStyle({ bold: !post.style.bold })}
                />
                <Chip
                  label="Itálico"
                  icon={<Italic size={11} />}
                  active={post.style.italic}
                  onClick={() => post.updateStyle({ italic: !post.style.italic })}
                />
                <Chip
                  label="Sublinhado"
                  icon={<Underline size={11} />}
                  active={post.style.underline}
                  onClick={() => post.updateStyle({ underline: !post.style.underline })}
                />
              </div>
              <Stepper
                label="Tamanho"
                value={post.style.bodyFontSize}
                min={20}
                max={44}
                onChange={(v) => post.updateStyle({ bodyFontSize: v })}
              />
            </SectionCard>

            <SectionCard title="Texto de apoio" icon={<Italic size={14} className="text-primary" />}>
              <div className="flex flex-wrap gap-1.5">
                <Chip
                  label="Negrito"
                  icon={<Bold size={11} />}
                  active={post.style.bodyBold}
                  onClick={() => post.updateStyle({ bodyBold: !post.style.bodyBold })}
                />
                <Chip
                  label="Itálico"
                  icon={<Italic size={11} />}
                  active={post.style.bodyItalic}
                  onClick={() => post.updateStyle({ bodyItalic: !post.style.bodyItalic })}
                />
                <Chip
                  label="Sublinhado"
                  icon={<Underline size={11} />}
                  active={post.style.bodyUnderline}
                  onClick={() => post.updateStyle({ bodyUnderline: !post.style.bodyUnderline })}
                />
              </div>
            </SectionCard>

            {/* ── Destaque [hl] ── */}
            <SectionCard title="Destaque" icon={<Highlighter size={14} className="text-primary" />}>
              <p className="mb-3 text-[11px] text-light-onSurface/40 dark:text-white/30">
                Cor usada pelo marcador <code>[hl]texto[/hl]</code> no headline e no texto de apoio.
              </p>
              <SwatchRow
                label="Cor padrão"
                value={post.style.highlightColor}
                swatches={HIGHLIGHT_SWATCHES}
                onSelect={(c) => post.updateStyle({ highlightColor: c })}
              />
            </SectionCard>

            {/* ── Cores ── */}
            <SectionCard title={isType1 ? "Cores Geral" : "Cores"} icon={<Palette size={14} className="text-primary" />}>
              <div className="space-y-3">
                <SwatchRow
                  label={isType2 ? "Fundo dos cards" : "Fundo"}
                  value={post.style.bgColor}
                  onSelect={(c) => post.updateStyle({ bgColor: c })}
                />
                <ColorRow
                  label="Headline"
                  value={post.style.headlineColor ?? post.style.textColor}
                  isOverride={post.style.headlineColor != null}
                  onSelect={(c) => post.updateStyle({ headlineColor: c })}
                  onReset={() => post.updateStyle({ headlineColor: null })}
                />
                <ColorRow
                  label="Texto de apoio"
                  value={post.style.bodyColor ?? post.style.textColor}
                  isOverride={post.style.bodyColor != null}
                  onSelect={(c) => post.updateStyle({ bodyColor: c })}
                  onReset={() => post.updateStyle({ bodyColor: null })}
                />
              </div>
            </SectionCard>

            {/* ── Extras ── */}
            <SectionCard title="Extras" icon={<SlidersHorizontal size={14} className="text-primary" />}>
              <div className="flex items-center justify-between">
                <span className="text-xs text-light-onSurface/65 dark:text-white/55">Setas de navegação</span>
                <Toggle checked={post.style.showArrows} onChange={(v) => post.updateStyle({ showArrows: v })} />
              </div>
            </SectionCard>

            {/* ── Cores do slide (overrides) ── */}
            <SectionCard
              title="Cores do slide"
              icon={<Palette size={14} className="text-primary" />}
              action={
                <button
                  onClick={() =>
                    patchSlide({
                      slideBgColor: null,
                      slideTextColor: null,
                      slideHeadlineColor: null,
                      slideBodyColor: null,
                      swipeTextColor: null,
                    })
                  }
                  className="text-[11px] text-light-onSurface/40 hover:text-primary dark:text-white/30"
                >
                  Limpar
                </button>
              }
            >
              <p className="mb-3 text-[11px] text-light-onSurface/40 dark:text-white/30">
                Vazio = usa a cor global definida acima.
              </p>
              <div className="space-y-3">
                <ColorRow
                  label="Fundo"
                  value={slide.slideBgColor ?? post.style.bgColor}
                  isOverride={slide.slideBgColor != null}
                  onSelect={(c) => patchSlide({ slideBgColor: c })}
                  onReset={() => patchSlide({ slideBgColor: null })}
                />
                <ColorRow
                  label="Texto"
                  value={slide.slideTextColor ?? post.style.textColor}
                  isOverride={slide.slideTextColor != null}
                  onSelect={(c) => patchSlide({ slideTextColor: c })}
                  onReset={() => patchSlide({ slideTextColor: null })}
                />
                <ColorRow
                  label="Headline"
                  value={slide.slideHeadlineColor ?? post.style.headlineColor ?? post.style.textColor}
                  isOverride={slide.slideHeadlineColor != null}
                  onSelect={(c) => patchSlide({ slideHeadlineColor: c })}
                  onReset={() => patchSlide({ slideHeadlineColor: null })}
                />
                <ColorRow
                  label="Texto de apoio"
                  value={slide.slideBodyColor ?? post.style.bodyColor ?? post.style.textColor}
                  isOverride={slide.slideBodyColor != null}
                  onSelect={(c) => patchSlide({ slideBodyColor: c })}
                  onReset={() => patchSlide({ slideBodyColor: null })}
                />
                {isType2 && (
                  <ColorRow
                    label="Texto de swipe"
                    value={slide.swipeTextColor ?? post.style.textColor}
                    isOverride={slide.swipeTextColor != null}
                    onSelect={(c) => patchSlide({ swipeTextColor: c })}
                    onReset={() => patchSlide({ swipeTextColor: null })}
                  />
                )}
              </div>
            </SectionCard>
          </>
        )}
      </div>

      {showHistory && (
        <>
          <div
            className="fixed inset-0 z-40 bg-black/20 backdrop-blur-[2px]"
            onClick={() => setShowHistory(false)}
            aria-hidden
          />
          <div className="fixed inset-y-0 right-0 z-50 flex w-80 flex-col border-l border-light-border bg-light-card p-4 shadow-floating dark:border-dark-border dark:bg-dark-card">
            <div className="mb-4 flex items-center justify-between">
              <h3 className="text-[13px] font-semibold text-light-onSurface dark:text-dark-onSurface">
                Histórico
              </h3>
              <IconButton onClick={() => setShowHistory(false)} title="Fechar">
                <X size={15} />
              </IconButton>
            </div>
            <div className="flex-1 space-y-1.5 overflow-y-auto">
              {history.map((entry) => (
                <button
                  key={entry.id}
                  onClick={() => {
                    post.loadSlides(entry.slides);
                    setShowHistory(false);
                  }}
                  className="block w-full rounded-lg border border-light-border p-2.5 text-left text-xs transition-colors hover:border-primary/40 dark:border-dark-border"
                >
                  <p className="truncate text-light-onSurface/80 dark:text-white/70">
                    {entry.briefing || "(sem briefing)"}
                  </p>
                  <p className="mt-0.5 text-light-onSurface/40 dark:text-white/30">
                    {new Date(entry.createdAt).toLocaleString("pt-BR")}
                  </p>
                </button>
              ))}
              {history.length === 0 && (
                <p className="text-xs text-light-onSurface/40 dark:text-white/30">Sem histórico ainda.</p>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function FontRow({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  return (
    <div className="flex items-center gap-2">
      <span className="w-20 shrink-0 text-[11px] text-light-onSurface/45 dark:text-white/35">{label}</span>
      <Select value={value} onChange={(e) => onChange(e.target.value)} className="py-1.5 text-xs">
        {AVAILABLE_FONTS.map((font) => (
          <option key={font} value={font}>
            {font}
          </option>
        ))}
      </Select>
    </div>
  );
}
