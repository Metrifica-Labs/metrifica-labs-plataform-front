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

export function PostCanvasType5({
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
  const fg = resolveText(slide, style);
  const bg = resolveBg(slide, style);

  const headlineStyle: React.CSSProperties = {
    fontFamily: style.bodyFont,
    fontSize: style.bodyFontSize,
    color: resolveHeadlineColor(slide, style),
    fontWeight: style.bold ? 800 : 500,
    fontStyle: style.italic ? "italic" : "normal",
    textDecoration: style.underline ? "underline" : "none",
    lineHeight: 1.18,
    letterSpacing: -0.4,
  };

  const bodyStyle: React.CSSProperties = {
    fontFamily: style.bodyFont,
    fontSize: style.bodyFontSize * 0.5,
    color: resolveBodyColor(slide, style),
    fontWeight: style.bodyBold ? 700 : 400,
    fontStyle: style.bodyItalic ? "italic" : "normal",
    textDecoration: style.bodyUnderline ? "underline" : "none",
    lineHeight: 1.45,
  };

  return (
    <div
      ref={innerRef}
      style={{
        width: CANVAS_WIDTH,
        height: CANVAS_HEIGHT,
        backgroundColor: bg,
        padding: "30px 34px 28px 34px",
        display: "flex",
        flexDirection: "column",
        boxSizing: "border-box",
      }}
    >
      {slide.headline && (
        <div style={{ marginBottom: 16 }}>
          {renderMarkup(slide.headline, headlineStyle, style.highlightColor)}
        </div>
      )}

      <div style={{ flex: 1, display: "flex", alignItems: "center" }}>
        {slide.imageUrl ? (
          <img
            src={slide.imageUrl}
            style={{
              width: "100%",
              height: 220,
              objectFit: "cover",
              borderRadius: 14,
            }}
          />
        ) : (
          <div
            style={{
              width: "100%",
              height: 220,
              borderRadius: 14,
              backgroundColor: withAlpha(fg, 0.06),
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <ImagePlus size={36} color={withAlpha(fg, 0.2)} />
            <span
              style={{
                marginTop: 8,
                fontSize: 12,
                color: withAlpha(fg, 0.3),
                fontFamily: style.bodyFont,
              }}
            >
              Adicionar imagem
            </span>
          </div>
        )}
      </div>

      {slide.body && (
        <div style={{ marginTop: 16 }}>
          {renderMarkup(slide.body, bodyStyle, style.highlightColor)}
        </div>
      )}

      <div style={{ height: 10 }} />
      <div style={{ display: "flex", alignItems: "center" }}>
        <span
          style={{
            fontFamily: style.counterFont,
            fontSize: 13,
            color: withAlpha(fg, 0.5),
            fontWeight: 600,
            letterSpacing: 0.5,
          }}
        >
          {index + 1}/{total}
        </span>
        <div style={{ flex: 1 }} />
        {style.showArrows && index < total - 1 && (
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: "50%",
              backgroundColor: withAlpha(fg, 0.1),
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <ArrowRight size={18} color={fg} />
          </div>
        )}
      </div>
    </div>
  );
}
