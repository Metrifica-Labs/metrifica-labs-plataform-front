import { ArrowRight, ImagePlus } from "lucide-react";
import {
  CANVAS_WIDTH,
  CANVAS_HEIGHT,
  resolveBg,
  resolveText,
  resolveHeadlineColor,
  resolveBodyColor,
  withAlpha,
  type PostStyle,
  type SlideContent,
} from "@/features/instagram-post/instagram-post-style";
import { renderMarkup } from "@/features/instagram-post/markup";

const ALIGN_MAP: Record<SlideContent["textAlign"], React.CSSProperties["alignItems"]> = {
  left: "flex-start",
  center: "center",
  right: "flex-end",
};

const TEXT_SHADOW = "0 1px 4px rgba(0,0,0,0.5)";

export function PostCanvasType4({
  style,
  slide,
  index,
  total,
  innerRef,
}: {
  style: PostStyle;
  slide: SlideContent;
  index: number;
  total: number;
  innerRef?: React.Ref<HTMLDivElement>;
}) {
  const half = CANVAS_HEIGHT / 2;

  function half_(imgUrl: string | null, text: string, isBottom: boolean) {
    const fg = resolveText(slide, style);
    const [title, ...subParts] = text.split("\n\n");
    const sub = subParts.join("\n\n").trim();

    return (
      <div style={{ position: "relative", width: "100%", height: half + 1, overflow: "hidden" }}>
        {imgUrl ? (
          <img src={imgUrl} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        ) : (
          <div
            style={{
              width: "100%",
              height: "100%",
              backgroundColor: withAlpha(resolveBg(slide, style), 0.9),
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <ImagePlus size={32} color={withAlpha(fg, 0.2)} />
            <span style={{ marginTop: 6, fontSize: 11, color: withAlpha(fg, 0.28), fontFamily: style.bodyFont }}>
              Adicionar imagem
            </span>
          </div>
        )}

        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "linear-gradient(to bottom, transparent 40%, rgba(0,0,0,0.65) 100%)",
          }}
        />

        {text && (
          <div
            style={{
              position: "absolute",
              left: 16,
              right: 16,
              bottom: isBottom ? 20 : 14,
              display: "flex",
              flexDirection: "column",
              alignItems: ALIGN_MAP[slide.textAlign],
              textAlign: slide.textAlign,
            }}
          >
            <div
              style={{
                fontFamily: style.bodyFont,
                fontSize: style.bodyFontSize * 0.52,
                color: resolveHeadlineColor(slide, style),
                fontWeight: style.bold ? 800 : 600,
                fontStyle: style.italic ? "italic" : "normal",
                lineHeight: 1.15,
                letterSpacing: -0.3,
                textShadow: TEXT_SHADOW,
              }}
            >
              {renderMarkup(title.trim(), {}, style.highlightColor)}
            </div>
            {sub && (
              <div
                style={{
                  marginTop: 4,
                  fontFamily: style.bodyFont,
                  fontSize: style.bodyFontSize * 0.36,
                  color: resolveBodyColor(slide, style),
                  fontWeight: style.bodyBold ? 600 : 400,
                  fontStyle: style.bodyItalic ? "italic" : "normal",
                  lineHeight: 1.4,
                  textShadow: TEXT_SHADOW,
                }}
              >
                {renderMarkup(sub, {}, style.highlightColor)}
              </div>
            )}
          </div>
        )}

        {!isBottom && slide.showCounter && (
          <span
            style={{
              position: "absolute",
              top: 14,
              left: 16,
              fontFamily: style.counterFont,
              fontSize: 12,
              color: "rgba(255,255,255,0.75)",
              fontWeight: 600,
              letterSpacing: 0.5,
              textShadow: "0 1px 3px rgba(0,0,0,0.4)",
            }}
          >
            {index + 1}/{total}
          </span>
        )}

        {!isBottom && style.showArrows && index < total - 1 && (
          <div
            style={{
              position: "absolute",
              top: 10,
              right: 14,
              width: 30,
              height: 30,
              borderRadius: "50%",
              backgroundColor: "rgba(255,255,255,0.18)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <ArrowRight size={15} color="white" />
          </div>
        )}
      </div>
    );
  }

  return (
    <div ref={innerRef} style={{ width: CANVAS_WIDTH, height: CANVAS_HEIGHT, position: "relative" }}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0 }}>
        {half_(slide.imageUrl, slide.headline, false)}
      </div>
      <div style={{ position: "absolute", top: half - 1, left: 0, right: 0 }}>
        {half_(slide.coverImageUrl, slide.body, true)}
      </div>
    </div>
  );
}
