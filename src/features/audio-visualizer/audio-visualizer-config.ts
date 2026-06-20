export type VideoAspect = "square" | "portrait" | "story" | "landscape";

export const VIDEO_ASPECTS: Record<VideoAspect, { label: string; width: number; height: number }> = {
  square: { label: "Quadrado (1080x1080)", width: 1080, height: 1080 },
  portrait: { label: "Vertical (1080x1920)", width: 1080, height: 1920 },
  story: { label: "Story (1080x1920)", width: 1080, height: 1920 },
  landscape: { label: "Horizontal (1920x1080)", width: 1920, height: 1080 },
};

export type BackgroundType = "solid" | "gradient" | "image";
export type CaptionMode = "segment" | "karaoke" | "word";

export interface AudioVisualizerConfig {
  aspect: VideoAspect;
  fps: number;
  ringColorStart: string;
  ringColorEnd: string;
  barCount: number;
  ringRadius: number;
  barWidth: number;
  barMaxLength: number;
  sensitivity: number;
  rotationSpeed: number;
  glow: boolean;
  centerImageUrl: string | null;
  centerImageScale: number;
  centerImageCircular: boolean;
  centerImagePulse: boolean;
  backgroundType: BackgroundType;
  backgroundColor: string;
  backgroundColor2: string;
  backgroundImageUrl: string | null;
  captionEnabled: boolean;
  captionMode: CaptionMode;
  captionFontSize: number;
  captionColor: string;
  captionHighlightColor: string;
  captionBottomOffset: number;
  captionMaxWords: number;
  captionShadow: boolean;
  captionBold: boolean;
}

export function createAudioVisualizerConfig(): AudioVisualizerConfig {
  return {
    aspect: "square",
    fps: 30,
    ringColorStart: "#EC4899",
    ringColorEnd: "#6366F1",
    barCount: 96,
    ringRadius: 0.3,
    barWidth: 5,
    barMaxLength: 120,
    sensitivity: 1.0,
    rotationSpeed: 6,
    glow: true,
    centerImageUrl: null,
    centerImageScale: 0.85,
    centerImageCircular: true,
    centerImagePulse: true,
    backgroundType: "solid",
    backgroundColor: "#05050A",
    backgroundColor2: "#1A1033",
    backgroundImageUrl: null,
    captionEnabled: true,
    captionMode: "karaoke",
    captionFontSize: 48,
    captionColor: "rgba(255,255,255,0.8)",
    captionHighlightColor: "#FFFFFF",
    captionBottomOffset: 0.16,
    captionMaxWords: 5,
    captionShadow: true,
    captionBold: true,
  };
}
