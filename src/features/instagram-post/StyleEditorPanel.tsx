import {
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
import { Textarea, Input, Select, Label } from "@/shared/components/ui/Field";
import { pickImageDataUrl } from "@/features/instagram-post/pick-image";
import {
  AVAILABLE_FONTS,
  CREATOR_PRESETS,
  HIGHLIGHT_SWATCHES,
  type ImageCoverVariant,
  type SlideLayout,
} from "@/features/instagram-post/instagram-post-style";
import { LAYOUT_LABELS, COVER_VARIANT_LABELS } from "@/features/instagram-post/post-ui-constants";
import type { useInstagramPost } from "@/features/instagram-post/useInstagramPost";
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

type Post = ReturnType<typeof useInstagramPost>;
type Slide = Post["style"]["slides"][number];

function FontRow({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex items-center gap-2">
      <span className="w-20 shrink-0 text-[11px] text-light-onSurface/45 dark:text-white/35">
        {label}
      </span>
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

export function StyleEditorPanel({ post, slide }: { post: Post; slide: Slide }) {
  const isType2 = slide.layout === "imageCover";
  const isType3 = slide.layout === "textGrid";
  const isType4 = slide.layout === "imageStack";
  const isType5 = slide.layout === "freestyle";
  const isType1 = !isType2 && !isType3 && !isType4 && !isType5;

  function patchSlide(patch: Partial<Slide>) {
    post.updateSlide(post.activeIndex, patch as never);
  }

  return (
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

        {isType5 && (
          <div className="space-y-3">
            <div>
              <Label>Imagem (no meio)</Label>
              <ImagePicker
                src={slide.imageUrl}
                onPick={async () => {
                  const url = await pickImageDataUrl();
                  if (url) patchSlide({ imageUrl: url });
                }}
                onClear={() => patchSlide({ imageUrl: null })}
              />
            </div>
          </div>
        )}

        {(isType2 || isType3 || isType4 || isType5) && (
          <div className="flex items-center justify-between">
            <span className="text-xs text-light-onSurface/65 dark:text-white/55">
              Exibir contador neste slide
            </span>
            <Toggle checked={slide.showCounter} onChange={(v) => patchSlide({ showCounter: v })} />
          </div>
        )}

        <div className="mt-3 border-t border-light-border pt-3 dark:border-dark-border" />
        <Label>Layout</Label>
        <Select data-testid="layout-select" value={slide.layout} onChange={(e) => patchSlide({ layout: e.target.value as SlideLayout })}>
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
  );
}
