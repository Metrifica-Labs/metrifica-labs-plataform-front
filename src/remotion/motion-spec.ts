import { z } from "zod";

/**
 * MotionSpec — contrato central do Motion Video Generator.
 *
 * É o JSON que a IA gera (enriquecido com a skill `motion-foundations`), que o
 * chat de edição modifica via patch, que as compositions Remotion consomem e
 * que o banco persiste.
 *
 * Regra de ouro: este arquivo é React-/framework-agnostic. Importa SÓ `zod`.
 * Nada de `src/features`, `src/core`, router ou Zustand — para que a mesma
 * pasta `src/remotion/` sirva tanto ao `<Player>` (Vite) quanto ao bundler
 * próprio do Remotion (render em cloud, fase futura).
 *
 * O vocabulário de animação (`token`, `easing`, `distance`, `spring`,
 * `emphasis`) reflete LITERALMENTE os `motionTokens` e princípios da skill
 * `motion-foundations`. A tradução desses nomes para valores numéricos de
 * `interpolate`/`Easing`/`spring` vive em `motion-tokens.ts` (Fase 1.2), não
 * aqui — este arquivo só descreve e valida a forma.
 */

export const SPEC_VERSION = 1 as const;

// ── Vocabulário da skill motion-foundations ────────────────────────────────

/** Durações nomeadas — `motionTokens.duration`. */
export const DurationToken = z.enum(["instant", "fast", "normal", "slow", "crawl"]);

/** Curvas de easing — `motionTokens.easing`. */
export const EasingToken = z.enum(["smooth", "sharp", "bounce", "linear"]);

/** Distâncias de deslocamento — `motionTokens.distance`. */
export const DistanceToken = z.enum(["xs", "sm", "md", "lg", "xl"]);

/** Presets de spring — `springs`. */
export const SpringPreset = z.enum(["snappy", "gentle", "bouncy", "instant", "release"]);

/** Princípios de motion (intenção da animação) — guia a IA e o reviewer. */
export const Emphasis = z.enum([
  "guide-attention",
  "communicate-state",
  "preserve-continuity",
]);

// ── Primitivos ─────────────────────────────────────────────────────────────

/** Cor hexadecimal (#rgb, #rrggbb ou #rrggbbaa). */
const HexColor = z
  .string()
  .regex(/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/, "cor hex inválida");

/** Fontes permitidas (precisam ser carregáveis via @remotion/google-fonts). */
export const AllowedFont = z.enum([
  "Inter",
  "Roboto",
  "Montserrat",
  "Poppins",
  "Roboto Mono",
]);

/** Tipo de animação visual de entrada/saída de um elemento. */
export const AnimationKind = z.enum(["fade", "slide", "scale", "slide-fade", "pop", "none"]);

/** Direção de um slide. */
export const Direction = z.enum(["up", "down", "left", "right"]);

/**
 * Animação de um elemento. Combina o vocabulário da skill: `kind` define a
 * forma visual, `token`/`easing` o tempo e a curva, `distance`/`direction` o
 * deslocamento (para slides), `spring` um preset físico opcional.
 */
export const Animation = z.object({
  kind: AnimationKind.default("fade"),
  token: DurationToken.default("normal"),
  easing: EasingToken.default("smooth"),
  distance: DistanceToken.optional(),
  direction: Direction.optional(),
  spring: SpringPreset.optional(),
  /** Atraso (em frames) relativo ao início da cena. */
  delayInFrames: z.number().int().nonnegative().default(0),
});
export type Animation = z.infer<typeof Animation>;

/** Posição de um elemento no canvas, em % das dimensões + âncora. */
export const Position = z.object({
  /** 0–100, % da largura. */
  x: z.number().min(0).max(100).default(50),
  /** 0–100, % da altura. */
  y: z.number().min(0).max(100).default(50),
  anchor: z
    .enum([
      "center",
      "top",
      "bottom",
      "left",
      "right",
      "top-left",
      "top-right",
      "bottom-left",
      "bottom-right",
    ])
    .default("center"),
});
export type Position = z.infer<typeof Position>;

// ── Elementos (união discriminada por `type`) ──────────────────────────────

const baseElement = {
  id: z.string().min(1),
  position: Position.default({}),
  opacity: z.number().min(0).max(1).default(1),
  enter: Animation.default({}),
  exit: Animation.optional(),
  emphasis: Emphasis.optional(),
};

export const TextElement = z.object({
  type: z.literal("text"),
  ...baseElement,
  content: z.string().min(1),
  role: z.enum(["headline", "subtitle", "body", "caption"]).default("body"),
  color: HexColor.optional(),
  /** Refere uma das fontes de `theme.fonts`. */
  fontFamily: z.enum(["heading", "body", "mono"]).default("body"),
  fontSizePx: z.number().int().positive().optional(),
  fontWeight: z.enum(["regular", "medium", "semibold", "bold"]).default("semibold"),
  align: z.enum(["left", "center", "right"]).default("center"),
  /** Largura máxima do bloco de texto, em % da largura do canvas. */
  maxWidthPct: z.number().min(10).max(100).default(80),
});
export type TextElement = z.infer<typeof TextElement>;

export const ImageElement = z.object({
  type: z.literal("image"),
  ...baseElement,
  src: z.string().url(),
  fit: z.enum(["cover", "contain"]).default("cover"),
  widthPct: z.number().min(1).max(100).default(60),
  heightPct: z.number().min(1).max(100).optional(),
  borderRadiusPx: z.number().nonnegative().default(0),
});
export type ImageElement = z.infer<typeof ImageElement>;

export const ShapeElement = z.object({
  type: z.literal("shape"),
  ...baseElement,
  shape: z.enum(["rect", "circle", "line"]).default("rect"),
  color: HexColor.default("#ffffff"),
  widthPct: z.number().min(0).max(100).default(20),
  heightPct: z.number().min(0).max(100).default(20),
  borderRadiusPx: z.number().nonnegative().default(0),
});
export type ShapeElement = z.infer<typeof ShapeElement>;

export const MotionElement = z.discriminatedUnion("type", [
  TextElement,
  ImageElement,
  ShapeElement,
]);
export type MotionElement = z.infer<typeof MotionElement>;

// ── Cena ───────────────────────────────────────────────────────────────────

/** Transição de entrada de uma cena (regras `transitions.md`). */
export const SceneTransition = z.enum(["fade", "slide", "wipe", "none"]);

export const Scene = z.object({
  id: z.string().min(1),
  /** Duração da cena em frames (1..900 ≈ até 30s a 30fps). */
  durationInFrames: z.number().int().positive().max(900),
  background: HexColor.optional(),
  transitionIn: SceneTransition.default("none"),
  elements: z.array(MotionElement).default([]),
});
export type Scene = z.infer<typeof Scene>;

// ── Meta / Theme / Spec ────────────────────────────────────────────────────

export const VideoFormat = z.enum(["reel", "story", "square", "feed", "wide"]);
export type VideoFormat = z.infer<typeof VideoFormat>;

/** Dimensões padrão por formato. `width`/`height` no spec sobrescrevem isto. */
export const FORMAT_DIMENSIONS: Record<VideoFormat, { width: number; height: number }> = {
  reel: { width: 1080, height: 1920 },
  story: { width: 1080, height: 1920 },
  square: { width: 1080, height: 1080 },
  feed: { width: 1080, height: 1350 },
  wide: { width: 1920, height: 1080 },
};

export const Meta = z.object({
  fps: z.union([z.literal(24), z.literal(30), z.literal(60)]).default(30),
  format: VideoFormat.default("reel"),
  /** Opcionais — quando ausentes, derivam de `FORMAT_DIMENSIONS[format]`. */
  width: z.number().int().positive().optional(),
  height: z.number().int().positive().optional(),
  backgroundColor: HexColor.default("#000000"),
});
export type Meta = z.infer<typeof Meta>;

export const Theme = z.object({
  palette: z.array(HexColor).min(1).default(["#6366f1", "#ec4899"]),
  fonts: z
    .object({
      heading: AllowedFont.default("Inter"),
      body: AllowedFont.default("Inter"),
      mono: AllowedFont.default("Roboto Mono"),
    })
    .default({}),
});
export type Theme = z.infer<typeof Theme>;

export const MotionSpec = z.object({
  specVersion: z.literal(SPEC_VERSION),
  meta: Meta.default({}),
  theme: Theme.default({}),
  scenes: z.array(Scene).min(1, "o vídeo precisa de ao menos 1 cena"),
});

/** Saída validada (com defaults aplicados) — use em todo o app/render. */
export type MotionSpec = z.infer<typeof MotionSpec>;
/** Entrada bruta aceita (defaults opcionais) — útil para o output cru da IA. */
export type MotionSpecInput = z.input<typeof MotionSpec>;

// ── Helpers ──────────────────────────────────────────────────────────────--

/** Validação não-lançante — use na fronteira com a IA (padrão safeParse). */
export function validateMotionSpec(
  data: unknown,
): z.SafeParseReturnType<MotionSpecInput, MotionSpec> {
  return MotionSpec.safeParse(data);
}

/** Validação lançante — use quando o dado já deveria estar correto. */
export function parseMotionSpec(data: unknown): MotionSpec {
  return MotionSpec.parse(data);
}

/** Resolve as dimensões efetivas (explícitas no meta ou derivadas do formato). */
export function resolveDimensions(meta: Meta): { width: number; height: number } {
  const preset = FORMAT_DIMENSIONS[meta.format];
  return {
    width: meta.width ?? preset.width,
    height: meta.height ?? preset.height,
  };
}

/** Duração total do vídeo (soma das cenas) — alimenta `calculateMetadata`. */
export function totalDurationInFrames(spec: MotionSpec): number {
  return spec.scenes.reduce((sum, scene) => sum + scene.durationInFrames, 0);
}

// ── Fixture ─────────────────────────────────────────────────────────────---

/**
 * Exemplo canônico usado no preview de dev e nos testes. É passado por
 * `MotionSpec.parse`, então qualquer divergência do schema quebra no import —
 * mantendo o fixture sempre válido.
 */
export const EXAMPLE_SPEC: MotionSpec = MotionSpec.parse({
  specVersion: SPEC_VERSION,
  meta: { format: "reel", fps: 30, backgroundColor: "#0b0b12" },
  theme: {
    palette: ["#6366f1", "#ec4899", "#f8fafc"],
    fonts: { heading: "Poppins", body: "Inter" },
  },
  scenes: [
    {
      id: "intro",
      durationInFrames: 60,
      transitionIn: "none",
      elements: [
        {
          type: "text",
          id: "kicker",
          content: "EM BREVE",
          role: "caption",
          color: "#ec4899",
          fontFamily: "heading",
          fontWeight: "bold",
          position: { x: 50, y: 38, anchor: "center" },
          enter: { kind: "fade", token: "fast", easing: "smooth", delayInFrames: 6 },
          emphasis: "communicate-state",
        },
        {
          type: "text",
          id: "headline",
          content: "Sua marca em movimento",
          role: "headline",
          color: "#f8fafc",
          fontFamily: "heading",
          fontWeight: "bold",
          fontSizePx: 96,
          position: { x: 50, y: 50, anchor: "center" },
          enter: {
            kind: "slide-fade",
            token: "slow",
            easing: "smooth",
            distance: "lg",
            direction: "up",
            delayInFrames: 12,
          },
          emphasis: "guide-attention",
        },
      ],
    },
    {
      id: "payoff",
      durationInFrames: 75,
      transitionIn: "fade",
      elements: [
        {
          type: "text",
          id: "subtitle",
          content: "Crie vídeos de motion design com um prompt.",
          role: "subtitle",
          color: "#f8fafc",
          fontFamily: "body",
          fontWeight: "medium",
          maxWidthPct: 70,
          position: { x: 50, y: 50, anchor: "center" },
          enter: {
            kind: "slide-fade",
            token: "normal",
            easing: "smooth",
            distance: "md",
            direction: "up",
          },
          emphasis: "guide-attention",
        },
      ],
    },
  ],
});
