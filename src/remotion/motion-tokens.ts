import { Easing, interpolate, spring } from "remotion";
import { z } from "zod";
import {
  DistanceToken,
  DurationToken,
  EasingToken,
  SpringPreset,
  type Animation,
} from "./motion-spec";

/**
 * Tradução do vocabulário da skill `motion-foundations` para valores concretos
 * de animação do Remotion (`interpolate`/`Easing`/`spring`).
 *
 * Mantém-se React-/framework-agnostic: importa só `remotion`, `zod` e o schema.
 */

type DurationName = z.infer<typeof DurationToken>;
type EasingName = z.infer<typeof EasingToken>;
type DistanceName = z.infer<typeof DistanceToken>;
type SpringName = z.infer<typeof SpringPreset>;

/** Durações em segundos — espelham `motionTokens.duration` da skill. */
export const DURATION_SECONDS: Record<DurationName, number> = {
  instant: 0.08,
  fast: 0.18,
  normal: 0.35,
  slow: 0.6,
  crawl: 1.0,
};

/** Curvas de Bézier — espelham `motionTokens.easing` da skill. */
export const EASING_BEZIER: Record<EasingName, readonly [number, number, number, number]> = {
  smooth: [0.22, 1, 0.36, 1],
  sharp: [0.4, 0, 0.2, 1],
  bounce: [0.34, 1.56, 0.64, 1],
  linear: [0, 0, 1, 1],
};

/** Distâncias base em px — espelham `motionTokens.distance` da skill. */
export const DISTANCE_PX: Record<DistanceName, number> = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 48,
};

/** Configs de spring — espelham o mapa `springs` da skill. */
export const SPRING_CONFIG: Record<SpringName, { stiffness: number; damping: number; mass?: number }> = {
  snappy: { stiffness: 300, damping: 30 },
  gentle: { stiffness: 120, damping: 14 },
  bouncy: { stiffness: 400, damping: 10 },
  instant: { stiffness: 600, damping: 35 },
  release: { stiffness: 200, damping: 20 },
};

/**
 * As distâncias da skill são dimensionadas para UI (4–48px). Num canvas de
 * vídeo (1080px+), o deslocamento precisa ser proporcionalmente maior para ser
 * perceptível — daí este fator multiplicador.
 */
export const MOTION_DISTANCE_SCALE = 4;

/** Converte uma duração nomeada em frames, dado o fps da composição. */
export function durationToFrames(token: DurationName, fps: number): number {
  return Math.max(1, Math.round(DURATION_SECONDS[token] * fps));
}

/** Função de easing do Remotion para um token de easing. */
export function easingFor(token: EasingName) {
  const [a, b, c, d] = EASING_BEZIER[token];
  return Easing.bezier(a, b, c, d);
}

export interface AnimatedStyle {
  opacity: number;
  transform: string;
}

function clamp01(n: number): number {
  return Math.max(0, Math.min(1, n));
}

/** Deslocamento (px) restante de um slide, conforme direção e progresso. */
function axisOffset(anim: Animation, remaining: number): { x: number; y: number } {
  const base =
    (anim.distance ? DISTANCE_PX[anim.distance] : DISTANCE_PX.md) *
    MOTION_DISTANCE_SCALE *
    remaining;
  switch (anim.direction ?? "up") {
    case "up":
      return { x: 0, y: base };
    case "down":
      return { x: 0, y: -base };
    case "left":
      return { x: base, y: 0 };
    case "right":
      return { x: -base, y: 0 };
  }
}

function styleForKind(anim: Animation, progress: number): AnimatedStyle {
  const remaining = 1 - progress;
  const transforms: string[] = [];
  let opacity = 1;

  switch (anim.kind) {
    case "none":
      break;
    case "fade":
      opacity = clamp01(progress);
      break;
    case "slide": {
      const { x, y } = axisOffset(anim, remaining);
      transforms.push(`translate(${x}px, ${y}px)`);
      break;
    }
    case "slide-fade": {
      opacity = clamp01(progress);
      const { x, y } = axisOffset(anim, remaining);
      transforms.push(`translate(${x}px, ${y}px)`);
      break;
    }
    case "scale":
      opacity = clamp01(progress);
      transforms.push(`scale(${0.85 + 0.15 * progress})`);
      break;
    case "pop":
      // Com easing `bounce` ou um spring, `progress` ultrapassa 1 → overshoot.
      opacity = clamp01(progress);
      transforms.push(`scale(${progress})`);
      break;
  }

  return { opacity, transform: transforms.length ? transforms.join(" ") : "none" };
}

/**
 * Opacidade de SAÍDA: 1 durante a cena, esmaecendo nos últimos ~0.4s. Evita
 * que elementos "sumam no corte" — dá fechamento ao movimento.
 */
export function exitFade(frame: number, sceneDuration: number, fps: number): number {
  const dur = Math.round(0.4 * fps);
  const start = sceneDuration - dur;
  if (frame < start) return 1;
  return interpolate(frame, [start, sceneDuration], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: easingFor("smooth"),
  });
}

/**
 * Flutuação contínua e sutil (px) aplicada após a entrada — dá "vida" ao quadro
 * em vez de tudo congelar. `phase` desencontra os elementos.
 */
export function idleDriftPx(frame: number, fps: number, phase = 0): number {
  return Math.sin(((frame / fps) * Math.PI * 2) / 3 + phase) * 4;
}

/**
 * Estilo de ENTRADA de um elemento no frame local da cena. Centraliza toda a
 * tradução token→Remotion: as compositions só chamam isto.
 */
export function enterStyle(anim: Animation, frame: number, fps: number): AnimatedStyle {
  const local = frame - anim.delayInFrames;

  let progress: number;
  if (anim.spring) {
    progress = spring({ frame: local, fps, config: SPRING_CONFIG[anim.spring] });
  } else {
    const dur = durationToFrames(anim.token, fps);
    progress = interpolate(local, [0, dur], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: easingFor(anim.easing),
    });
  }

  return styleForKind(anim, progress);
}
