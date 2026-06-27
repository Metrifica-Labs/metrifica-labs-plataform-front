import { type CSSProperties, type FC, type ReactNode } from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
import type {
  ImageElement,
  MotionElement,
  Position,
  ShapeElement,
  TextElement,
  Theme,
} from "../motion-spec";
import { enterStyle, exitFade, idleDriftPx } from "../motion-tokens";
import { FONT_FAMILY } from "../fonts";

/** Tamanho de fonte padrão (px) por papel, num canvas de ~1080px de largura. */
const ROLE_FONT_PX: Record<TextElement["role"], number> = {
  headline: 104,
  subtitle: 52,
  body: 38,
  caption: 30,
};

const FONT_WEIGHT: Record<TextElement["fontWeight"], number> = {
  regular: 400,
  medium: 500,
  semibold: 600,
  bold: 700,
};

/** Translate de auto-posicionamento conforme a âncora. */
function anchorTranslate(anchor: Position["anchor"]): string {
  switch (anchor) {
    case "center":
      return "translate(-50%, -50%)";
    case "top":
      return "translate(-50%, 0)";
    case "bottom":
      return "translate(-50%, -100%)";
    case "left":
      return "translate(0, -50%)";
    case "right":
      return "translate(-100%, -50%)";
    case "top-left":
      return "translate(0, 0)";
    case "top-right":
      return "translate(-100%, 0)";
    case "bottom-left":
      return "translate(0, -100%)";
    case "bottom-right":
      return "translate(-100%, -100%)";
  }
}

/** Wrapper externo: posiciona; o interno aplica opacity/transform do movimento. */
function positionStyle(pos: Position): CSSProperties {
  return {
    position: "absolute",
    left: `${pos.x}%`,
    top: `${pos.y}%`,
    transform: anchorTranslate(pos.anchor),
  };
}

/** Desencontro de fase do idle por elemento (a partir do id). */
function phaseFromId(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) % 997;
  return (h / 997) * Math.PI * 2;
}

export const ElementView: FC<{ element: MotionElement; theme: Theme }> = ({ element, theme }) => {
  const frame = useCurrentFrame();
  const { fps, width, height, durationInFrames } = useVideoConfig();

  // Movimento composto: entrada (tradução dos tokens) + flutuação contínua +
  // esmaecimento de saída no fim da cena.
  const enter = enterStyle(element.enter, frame, fps);
  const exitOpacity = exitFade(frame, durationInFrames, fps);
  const drift = idleDriftPx(frame, fps, phaseFromId(element.id));

  const motion: CSSProperties = {
    opacity: element.opacity * enter.opacity * exitOpacity,
    transform:
      enter.transform === "none"
        ? `translateY(${drift}px)`
        : `translateY(${drift}px) ${enter.transform}`,
  };

  return (
    <div style={positionStyle(element.position)}>
      {renderInner(element, theme, motion, width, height)}
    </div>
  );
};

function renderInner(
  element: MotionElement,
  theme: Theme,
  motion: CSSProperties,
  canvasW: number,
  canvasH: number,
): ReactNode {
  switch (element.type) {
    case "text":
      return <TextInner el={element} theme={theme} motion={motion} canvasW={canvasW} />;
    case "image":
      return <ImageInner el={element} motion={motion} canvasW={canvasW} canvasH={canvasH} />;
    case "shape":
      return <ShapeInner el={element} motion={motion} canvasW={canvasW} canvasH={canvasH} />;
  }
}

const TextInner: FC<{
  el: TextElement;
  theme: Theme;
  motion: CSSProperties;
  canvasW: number;
}> = ({ el, theme, motion, canvasW }) => {
  const color = el.color ?? theme.palette[0];
  const fontSize = el.fontSizePx ?? ROLE_FONT_PX[el.role];
  return (
    <p
      style={{
        ...motion,
        margin: 0,
        color,
        fontFamily: FONT_FAMILY[theme.fonts[el.fontFamily]],
        fontSize,
        fontWeight: FONT_WEIGHT[el.fontWeight],
        textAlign: el.align,
        maxWidth: (canvasW * el.maxWidthPct) / 100,
        lineHeight: 1.08,
        letterSpacing: el.role === "headline" ? "-0.02em" : "0",
        whiteSpace: "pre-wrap",
        textWrap: "balance",
      }}
    >
      {el.content}
    </p>
  );
};

const ImageInner: FC<{
  el: ImageElement;
  motion: CSSProperties;
  canvasW: number;
  canvasH: number;
}> = ({ el, motion, canvasW, canvasH }) => (
  <img
    src={el.src}
    style={{
      ...motion,
      display: "block",
      width: (canvasW * el.widthPct) / 100,
      height: el.heightPct ? (canvasH * el.heightPct) / 100 : "auto",
      objectFit: el.fit,
      borderRadius: el.borderRadiusPx,
    }}
  />
);

const ShapeInner: FC<{
  el: ShapeElement;
  motion: CSSProperties;
  canvasW: number;
  canvasH: number;
}> = ({ el, motion, canvasW, canvasH }) => {
  const w = (canvasW * el.widthPct) / 100;
  const h =
    el.shape === "line"
      ? Math.max(2, (canvasH * el.heightPct) / 100)
      : (canvasH * el.heightPct) / 100;
  const borderRadius = el.shape === "circle" ? "50%" : el.borderRadiusPx;
  return (
    <div
      style={{
        ...motion,
        width: w,
        height: h,
        backgroundColor: el.color,
        borderRadius,
      }}
    />
  );
};
