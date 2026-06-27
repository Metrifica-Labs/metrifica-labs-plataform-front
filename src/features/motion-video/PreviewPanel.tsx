import { Player } from "@remotion/player";
import { MotionVideo } from "@/remotion/compositions/MotionVideo";
import {
  resolveDimensions,
  totalDurationInFrames,
  type MotionSpec,
} from "@/remotion/motion-spec";

/**
 * Preview ao vivo do `MotionSpec` via Remotion Player (roda 100% no browser).
 * Trocar o `spec` re-renderiza instantaneamente — é o que torna o chat de
 * edição (Fase 5) imediato e gratuito.
 */
export function PreviewPanel({ spec }: { spec: MotionSpec }) {
  const dims = resolveDimensions(spec.meta);
  return (
    <div className="flex h-full w-full items-center justify-center">
      <div
        className="overflow-hidden rounded-xl shadow-lg ring-1 ring-black/10 dark:ring-white/10"
        style={{
          aspectRatio: `${dims.width} / ${dims.height}`,
          height: "100%",
          maxHeight: "100%",
          maxWidth: "100%",
        }}
      >
        <Player
          component={MotionVideo}
          inputProps={{ spec }}
          durationInFrames={totalDurationInFrames(spec)}
          fps={spec.meta.fps}
          compositionWidth={dims.width}
          compositionHeight={dims.height}
          style={{ width: "100%", height: "100%" }}
          controls
          loop
        />
      </div>
    </div>
  );
}
