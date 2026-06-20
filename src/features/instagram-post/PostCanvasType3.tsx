import { ArrowRight, ImagePlus } from "lucide-react";
import {
  CANVAS_WIDTH,
  CANVAS_HEIGHT,
  resolveBg,
  resolveText,
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

export function PostCanvasType3({
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

  function textBlock(idx: number) {
    const text = slide.gridTexts[idx] ?? "";
    if (!text) return <div style={{ flex: 1 }} />;
    const isBold = slide.gridBolds[idx];
    const textStyle: React.CSSProperties = {
      fontFamily: style.bodyFont,
      fontSize: style.bodyFontSize * 0.44,
      color: resolveBodyColor(slide, style),
      fontWeight: isBold ? 700 : 400,
      fontStyle: style.bodyItalic ? "italic" : "normal",
      lineHeight: slide.gridSpacing,
    };
    return (
      <div
        style={{
          flex: 1,
          padding: 10,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: ALIGN_MAP[slide.textAlign],
          textAlign: slide.textAlign,
        }}
      >
        {renderMarkup(text, textStyle, style.highlightColor)}
      </div>
    );
  }

  return (
    <div
      ref={innerRef}
      style={{
        width: CANVAS_WIDTH,
        height: CANVAS_HEIGHT,
        position: "relative",
        overflow: "hidden",
      }}
    >
      {slide.coverImageUrl ? (
        <img
          src={slide.coverImageUrl}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }}
        />
      ) : (
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundColor: resolveBg(slide, style),
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <ImagePlus size={48} color={withAlpha(fg, 0.15)} />
          <span style={{ marginTop: 10, fontSize: 13, color: withAlpha(fg, 0.25), fontFamily: style.bodyFont }}>
            Imagem de fundo
          </span>
        </div>
      )}

      <div
        style={{
          position: "absolute",
          inset: 0,
          padding: "20px 20px 0 20px",
          display: "flex",
          flexDirection: "column",
        }}
      >
        <div style={{ flex: 1, display: "flex" }}>
          {textBlock(0)}
          <div style={{ width: 12 }} />
          {textBlock(1)}
        </div>
        <div style={{ flex: 1, display: "flex" }}>
          {textBlock(2)}
          <div style={{ width: 12 }} />
          {textBlock(3)}
        </div>
        <div style={{ height: 8 }} />
        <div style={{ display: "flex", alignItems: "center", paddingBottom: 14 }}>
          {slide.showCounter && (
            <span
              style={{
                fontFamily: style.counterFont,
                fontSize: 12,
                color: withAlpha(fg, 0.7),
                fontWeight: 600,
                letterSpacing: 0.5,
              }}
            >
              {index + 1}/{total}
            </span>
          )}
          <div style={{ flex: 1 }} />
          {style.showArrows && index < total - 1 && (
            <div
              style={{
                width: 32,
                height: 32,
                borderRadius: "50%",
                backgroundColor: withAlpha(fg, 0.18),
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <ArrowRight size={16} color={fg} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
