import { type FC } from "react";
import {
  AbsoluteFill,
  interpolate,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import type { MotionSpec, Scene, Theme } from "../motion-spec";
import { ElementView } from "./ElementView";

/** Converte #rgb/#rrggbb em rgba() com alpha. */
function rgba(hex: string, alpha: number): string {
  const h = hex.replace("#", "");
  const f = h.length === 3 ? h.split("").map((c) => c + c).join("") : h;
  const r = parseInt(f.slice(0, 2), 16);
  const g = parseInt(f.slice(2, 4), 16);
  const b = parseInt(f.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/** Fundo com profundidade: cor base + dois halos radiais da paleta. */
function backgroundFor(bg: string, palette: string[]): string {
  const a = palette[0] ?? "#6366f1";
  const b = palette[1] ?? palette[0] ?? "#ec4899";
  return [
    `radial-gradient(120% 90% at 22% 12%, ${rgba(a, 0.22)} 0%, transparent 55%)`,
    `radial-gradient(120% 90% at 85% 92%, ${rgba(b, 0.18)} 0%, transparent 52%)`,
    bg,
  ].join(", ");
}

/** Manchas grandes desfocadas que derivam lentamente — dão movimento de fundo. */
const AccentBlobs: FC<{ palette: string[] }> = ({ palette }) => {
  const frame = useCurrentFrame();
  const { width, height, fps } = useVideoConfig();
  const t = frame / fps;
  const dx = Math.sin(t * 0.5) * 60;
  const dy = Math.cos(t * 0.4) * 60;
  const size = width * 0.7;
  return (
    <>
      <div
        style={{
          position: "absolute",
          width: size,
          height: size,
          left: -width * 0.15 + dx,
          top: -height * 0.04 + dy,
          borderRadius: "50%",
          background: palette[0] ?? "#6366f1",
          filter: "blur(130px)",
          opacity: 0.22,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: size,
          height: size,
          right: -width * 0.15 - dx,
          bottom: -height * 0.04 - dy,
          borderRadius: "50%",
          background: palette[1] ?? palette[0] ?? "#ec4899",
          filter: "blur(130px)",
          opacity: 0.2,
        }}
      />
    </>
  );
};

/**
 * Componente raiz de render: consome um `MotionSpec` e desenha as cenas em
 * sequência sobre um fundo com profundidade. É o componente passado tanto ao
 * `<Player>` (Fase 2) quanto à `<Composition>` (`MotionRoot`, render futuro).
 */
export const MotionVideo: FC<{ spec: MotionSpec }> = ({ spec }) => {
  let from = 0;
  return (
    <AbsoluteFill
      style={{ background: backgroundFor(spec.meta.backgroundColor, spec.theme.palette) }}
    >
      <AccentBlobs palette={spec.theme.palette} />
      {spec.scenes.map((scene) => {
        const node = (
          <Sequence
            key={scene.id}
            from={from}
            durationInFrames={scene.durationInFrames}
            name={scene.id}
          >
            <SceneView scene={scene} theme={spec.theme} />
          </Sequence>
        );
        from += scene.durationInFrames;
        return node;
      })}
    </AbsoluteFill>
  );
};

const SceneView: FC<{ scene: Scene; theme: Theme }> = ({ scene, theme }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Transição de entrada da cena. Fase 1: qualquer valor != "none" é tratado
  // como fade (slide/wipe ficam para uma fase posterior de transições).
  const opacity =
    scene.transitionIn === "none"
      ? 1
      : interpolate(frame, [0, Math.round(fps * 0.25)], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });

  return (
    <AbsoluteFill style={{ opacity, backgroundColor: scene.background }}>
      {scene.elements.map((element) => (
        <ElementView key={element.id} element={element} theme={theme} />
      ))}
    </AbsoluteFill>
  );
};
