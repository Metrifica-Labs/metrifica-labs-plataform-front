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

const TEXT_SHADOW = "0 1px 4px rgba(0,0,0,0.4)";

export function PostCanvasType2({
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

  function logoBadge() {
    if (style.logoUrl) {
      return <img src={style.logoUrl} style={{ height: 30, maxWidth: 96, objectFit: "contain" }} />;
    }
    return (
      <span
        style={{
          height: 30,
          display: "flex",
          alignItems: "center",
          fontFamily: style.handleFont,
          fontSize: 11,
          fontWeight: 600,
          color: fg,
        }}
      >
        {style.handle}
      </span>
    );
  }

  function titleCard(centered: boolean) {
    if (!slide.headline) return null;
    return (
      <div
        style={{
          fontFamily: style.bodyFont,
          fontSize: style.bodyFontSize * 0.82,
          color: resolveHeadlineColor(slide, style),
          fontWeight: style.bold ? 800 : 600,
          fontStyle: style.italic ? "italic" : "normal",
          lineHeight: 1.2,
          letterSpacing: -0.3,
          textAlign: centered ? "center" : "left",
        }}
      >
        {renderMarkup(slide.headline, {}, style.highlightColor)}
      </div>
    );
  }

  function subtitleCard(centered: boolean) {
    if (!slide.body) return null;
    return (
      <div
        style={{
          marginTop: 6,
          fontFamily: style.bodyFont,
          fontSize: style.bodyFontSize * 0.44,
          color: resolveBodyColor(slide, style),
          fontWeight: style.bodyBold ? 600 : 400,
          fontStyle: style.bodyItalic ? "italic" : "normal",
          lineHeight: 1.4,
          textAlign: centered ? "center" : "left",
        }}
      >
        {renderMarkup(slide.body, {}, style.highlightColor)}
      </div>
    );
  }

  function titleInline() {
    if (!slide.headline) return null;
    return (
      <div
        style={{
          fontFamily: style.bodyFont,
          fontSize: style.bodyFontSize * 0.9,
          color: "#fff",
          fontWeight: style.bold ? 800 : 600,
          fontStyle: style.italic ? "italic" : "normal",
          lineHeight: 1.15,
          letterSpacing: -0.4,
          textShadow: TEXT_SHADOW,
        }}
      >
        {renderMarkup(slide.headline, {}, style.highlightColor)}
      </div>
    );
  }

  function subtitleInline() {
    if (!slide.body) return null;
    return (
      <div
        style={{
          marginTop: 8,
          fontFamily: style.bodyFont,
          fontSize: style.bodyFontSize * 0.46,
          color: "rgba(255,255,255,0.85)",
          fontWeight: style.bodyBold ? 600 : 400,
          fontStyle: style.bodyItalic ? "italic" : "normal",
          lineHeight: 1.4,
          textShadow: TEXT_SHADOW,
        }}
      >
        {renderMarkup(slide.body, {}, style.highlightColor)}
      </div>
    );
  }

  function swipeHint(centered: boolean) {
    if (!slide.swipeText) return null;
    return (
      <div
        style={{
          marginTop: 14,
          fontFamily: style.counterFont,
          fontSize: 11,
          color: slide.swipeTextColor ?? resolveBodyColor(slide, style),
          fontWeight: style.bodyBold ? 600 : 400,
          fontStyle: style.bodyItalic ? "italic" : "normal",
          letterSpacing: 0.3,
          textAlign: centered ? "center" : "left",
        }}
      >
        {slide.swipeText}
      </div>
    );
  }

  function footer() {
    return (
      <div style={{ display: "flex", alignItems: "center", padding: "8px 20px 16px 20px" }}>
        {slide.showCounter && (
          <span
            style={{
              fontFamily: style.counterFont,
              fontSize: 12,
              color: withAlpha(resolveBg(slide, style), 0.7),
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
              backgroundColor: withAlpha(resolveBg(slide, style), 0.18),
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <ArrowRight size={16} color={resolveBg(slide, style)} />
          </div>
        )}
      </div>
    );
  }

  function content() {
    switch (slide.coverVariant) {
      case "logoTop":
        return (
          <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
            <div style={{ height: 20 }} />
            <div style={{ padding: "0 20px" }}>{logoBadge()}</div>
            <div style={{ flex: 1 }} />
            <div style={{ padding: "0 20px" }}>
              {titleCard(true)}
              {subtitleCard(true)}
              {swipeHint(true)}
            </div>
            {footer()}
          </div>
        );
      case "subtitleTop":
        return (
          <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
            <div style={{ height: 20 }} />
            <div style={{ padding: "0 20px" }}>{logoBadge()}</div>
            <div style={{ flex: 1 }} />
            <div style={{ padding: "0 20px" }}>
              {subtitleCard(true)}
              {slide.headline && <div style={{ height: 6 }} />}
              {titleCard(true)}
              {swipeHint(true)}
            </div>
            {footer()}
          </div>
        );
      case "logoTopInline":
        return (
          <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
            <div style={{ padding: "20px 20px 0 20px" }}>{logoBadge()}</div>
            <div style={{ flex: 1 }} />
            <div style={{ padding: "0 20px" }}>
              {titleInline()}
              {subtitleInline()}
              {swipeHint(false)}
            </div>
            {footer()}
          </div>
        );
      default:
        return (
          <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
            <div style={{ flex: 1 }} />
            <div style={{ padding: "0 20px", display: "flex", justifyContent: "center" }}>{logoBadge()}</div>
            <div style={{ padding: "0 20px" }}>
              {titleCard(true)}
              {subtitleCard(true)}
              {swipeHint(true)}
            </div>
            {footer()}
          </div>
        );
    }
  }

  return (
    <div ref={innerRef} style={{ width: CANVAS_WIDTH, height: CANVAS_HEIGHT, position: "relative", overflow: "hidden" }}>
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
            backgroundColor: withAlpha(resolveBg(slide, style), 0.85),
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <ImagePlus size={48} color={withAlpha(fg, 0.2)} />
          <span style={{ marginTop: 10, fontSize: 13, color: withAlpha(fg, 0.3), fontFamily: style.bodyFont }}>
            Imagem de capa
          </span>
        </div>
      )}

      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "linear-gradient(to bottom, transparent 35%, rgba(0,0,0,0.75) 100%)",
        }}
      />

      <div style={{ position: "absolute", inset: 0 }}>{content()}</div>
    </div>
  );
}
