import type { CSSProperties, ReactNode } from "react";
import { withAlpha } from "@/features/instagram-post/instagram-post-style";

const MARKUP_PATTERN = /\[(hl(?:=#[0-9A-Fa-f]{6,8})?|i|u|b)\]([\s\S]*?)\[\/(hl|i|u|b)\]/g;

/**
 * Mirrors the Dart parseMarkup: [hl]/[hl=#RRGGBB]/[i]/[u]/[b] inline tags,
 * supporting nesting by recursing on the inner content.
 */
export function renderMarkup(text: string, baseStyle: CSSProperties, highlightColor: string): ReactNode {
  const parts: ReactNode[] = [];
  let lastEnd = 0;
  let match: RegExpExecArray | null;
  let key = 0;

  MARKUP_PATTERN.lastIndex = 0;
  while ((match = MARKUP_PATTERN.exec(text)) !== null) {
    const [full, openTag, content, closeTag] = match;
    const openBase = openTag.startsWith("hl") ? "hl" : openTag;
    if (openBase !== closeTag) continue;

    if (match.index > lastEnd) {
      parts.push(<span key={key++} style={baseStyle}>{text.slice(lastEnd, match.index)}</span>);
    }

    let spanStyle: CSSProperties = { ...baseStyle };
    switch (closeTag) {
      case "hl": {
        const hexPart = openTag.length > 3 ? openTag.slice(4) : null;
        const color = hexPart ? `#${hexPart.length === 8 ? hexPart.slice(2) : hexPart}` : highlightColor;
        spanStyle = { ...spanStyle, backgroundColor: withAlpha(color, 0.6) };
        break;
      }
      case "i":
        spanStyle = { ...spanStyle, fontStyle: "italic" };
        break;
      case "u":
        spanStyle = { ...spanStyle, textDecoration: "underline" };
        break;
      case "b":
        spanStyle = { ...spanStyle, fontWeight: 700 };
        break;
    }

    parts.push(<span key={key++} style={spanStyle}>{renderMarkup(content, spanStyle, highlightColor)}</span>);
    lastEnd = match.index + full.length;
  }

  if (lastEnd < text.length) {
    parts.push(<span key={key++} style={baseStyle}>{text.slice(lastEnd)}</span>);
  }

  return parts.length === 1 ? parts[0] : <>{parts}</>;
}
