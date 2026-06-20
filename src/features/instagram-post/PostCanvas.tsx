import { ArrowRight, User } from "lucide-react";
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

export function PostCanvas({
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
  const isLast = index === total - 1;
  const fg = resolveText(slide, style);
  const bg = resolveBg(slide, style);
  const r = style.avatarRadius;

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
        fontFamily: style.bodyFont,
        boxSizing: "border-box",
      }}
    >
      <div
        style={{
          flex: 1,
          display: "flex",
          flexDirection: "column",
          justifyContent: style.centerContent ? "center" : "flex-start",
          alignItems: "flex-start",
          overflow: "hidden",
        }}
      >
        {slide.showHeader && (
          <>
            <div style={{ display: "flex", alignItems: "center", width: "100%" }}>
              <div
                style={{
                  width: r * 2,
                  height: r * 2,
                  borderRadius: "50%",
                  backgroundColor: withAlpha(fg, 0.08),
                  backgroundImage: style.avatarUrl ? `url(${style.avatarUrl})` : undefined,
                  backgroundSize: "cover",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  flexShrink: 0,
                }}
              >
                {!style.avatarUrl && <User size={r} color={withAlpha(fg, 0.35)} />}
              </div>
              <div style={{ marginLeft: 12, display: "flex", flexDirection: "column", overflow: "hidden" }}>
                <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
                  <span
                    style={{
                      fontFamily: style.nameFont,
                      fontSize: 17,
                      color: fg,
                      fontWeight: 700,
                      lineHeight: 1.1,
                      whiteSpace: "nowrap",
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                    }}
                  >
                    {style.profileName}
                  </span>
                  {style.showVerifiedBadge && <span style={{ color: "#1D9BF0", fontSize: 14 }}>✓</span>}
                </div>
                <span
                  style={{
                    fontFamily: style.handleFont,
                    fontSize: 13,
                    color: withAlpha(fg, 0.55),
                    lineHeight: 1.1,
                  }}
                >
                  {style.handle}
                </span>
              </div>
            </div>
            <div style={{ height: 24 }} />
          </>
        )}

        {slide.imageUrl && slide.imageAbove && (
          <>
            <img
              src={slide.imageUrl}
              style={{ width: CANVAS_WIDTH - 68, height: 168, objectFit: "cover", borderRadius: 14 }}
            />
            <div style={{ height: 16 }} />
          </>
        )}

        {slide.headline && <div>{renderMarkup(slide.headline, headlineStyle, style.highlightColor)}</div>}
        {slide.body && (
          <>
            <div style={{ height: slide.headline ? 16 : 0 }} />
            <div>{renderMarkup(slide.body, bodyStyle, style.highlightColor)}</div>
          </>
        )}

        {slide.imageUrl && !slide.imageAbove && (
          <>
            <div style={{ height: 16 }} />
            <img
              src={slide.imageUrl}
              style={{ width: CANVAS_WIDTH - 68, height: 168, objectFit: "cover", borderRadius: 14 }}
            />
          </>
        )}
      </div>

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
        {style.showArrows && !isLast && (
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
