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

/**
 * Simplified port: replicates the "logoMid" variant (full-bleed cover +
 * bottom gradient + logo badge + headline/body cards). The other 3
 * coverVariant layouts from the Flutter version are not yet ported.
 */
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

      <div
        style={{
          position: "absolute",
          inset: 0,
          padding: "20px 22px",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          {slide.showCounter && (
            <span
              style={{
                fontFamily: style.counterFont,
                fontSize: 12,
                color: "rgba(255,255,255,0.8)",
                fontWeight: 600,
                letterSpacing: 0.5,
              }}
            >
              {index + 1}/{total}
            </span>
          )}
          {style.showArrows && index < total - 1 && (
            <div
              style={{
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

        <div>
          {style.logoUrl && (
            <img src={style.logoUrl} style={{ height: 30, maxWidth: 96, objectFit: "contain", marginBottom: 12 }} />
          )}
          {slide.headline && (
            <div
              style={{
                fontFamily: style.bodyFont,
                fontSize: style.bodyFontSize * 0.6,
                color: resolveHeadlineColor(slide, style),
                fontWeight: style.bold ? 800 : 600,
                lineHeight: 1.15,
                textShadow: "0 1px 4px rgba(0,0,0,0.5)",
              }}
            >
              {renderMarkup(slide.headline, {}, style.highlightColor)}
            </div>
          )}
          {slide.body && (
            <div
              style={{
                marginTop: 6,
                fontFamily: style.bodyFont,
                fontSize: style.bodyFontSize * 0.38,
                color: resolveBodyColor(slide, style),
                lineHeight: 1.4,
                textShadow: "0 1px 4px rgba(0,0,0,0.5)",
              }}
            >
              {renderMarkup(slide.body, {}, style.highlightColor)}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
