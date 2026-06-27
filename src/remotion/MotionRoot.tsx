import { type FC } from "react";
import { Composition, type CalculateMetadataFunction } from "remotion";
import { MotionVideo } from "./compositions/MotionVideo";
import {
  EXAMPLE_SPEC,
  resolveDimensions,
  totalDurationInFrames,
  type MotionSpec,
} from "./motion-spec";

type MotionVideoProps = { spec: MotionSpec };

/**
 * Deriva duração/dimensões/fps a partir do próprio spec antes de renderizar.
 * É o que permite o mesmo componente servir qualquer `MotionSpec`.
 */
const calculateMetadata: CalculateMetadataFunction<MotionVideoProps> = ({ props }) => {
  const dims = resolveDimensions(props.spec.meta);
  return {
    durationInFrames: totalDurationInFrames(props.spec),
    fps: props.spec.meta.fps,
    width: dims.width,
    height: dims.height,
  };
};

/**
 * Root de compositions consumido pelo Remotion Studio e pelo bundler de render
 * (Fase 8). O preview no app (Fase 2) usa `MotionVideo` direto via `<Player>`.
 */
export const MotionRoot: FC = () => {
  const dims = resolveDimensions(EXAMPLE_SPEC.meta);
  return (
    <Composition
      id="MotionVideo"
      component={MotionVideo}
      durationInFrames={totalDurationInFrames(EXAMPLE_SPEC)}
      fps={EXAMPLE_SPEC.meta.fps}
      width={dims.width}
      height={dims.height}
      defaultProps={{ spec: EXAMPLE_SPEC }}
      calculateMetadata={calculateMetadata}
    />
  );
};
