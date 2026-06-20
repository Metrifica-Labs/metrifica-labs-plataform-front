import { VIDEO_ASPECTS, type AudioVisualizerConfig } from "@/features/audio-visualizer/audio-visualizer-config";
import type { Captions } from "@/features/audio-visualizer/captions";

/**
 * Simplified port of the Flutter CustomPainter-based engine: draws a circular
 * frequency spectrum, optional center image and captions onto a <canvas>,
 * driven by a Web Audio AnalyserNode. Not a line-for-line port of the
 * 718-line Dart engine, but covers the same visual building blocks.
 */
export class AudioVisualizerEngine {
  private rafId: number | null = null;
  private rotation = 0;
  private lastTimestamp = 0;
  private centerImage: HTMLImageElement | null = null;
  private backgroundImage: HTMLImageElement | null = null;

  constructor(
    private canvas: HTMLCanvasElement,
    private analyser: AnalyserNode,
    private getConfig: () => AudioVisualizerConfig,
    private getCaptions: () => Captions,
    private getCurrentTime: () => number
  ) {}

  setCenterImage(url: string | null) {
    if (!url) {
      this.centerImage = null;
      return;
    }
    const img = new Image();
    img.src = url;
    this.centerImage = img;
  }

  setBackgroundImage(url: string | null) {
    if (!url) {
      this.backgroundImage = null;
      return;
    }
    const img = new Image();
    img.src = url;
    this.backgroundImage = img;
  }

  start() {
    if (this.rafId !== null) return;
    const loop = (timestamp: number) => {
      const deltaMs = this.lastTimestamp ? timestamp - this.lastTimestamp : 0;
      this.lastTimestamp = timestamp;
      this.draw(deltaMs);
      this.rafId = requestAnimationFrame(loop);
    };
    this.rafId = requestAnimationFrame(loop);
  }

  stop() {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
      this.lastTimestamp = 0;
    }
  }

  private draw(deltaMs: number) {
    const config = this.getConfig();
    const { width, height } = VIDEO_ASPECTS[config.aspect];
    if (this.canvas.width !== width) this.canvas.width = width;
    if (this.canvas.height !== height) this.canvas.height = height;

    const ctx = this.canvas.getContext("2d");
    if (!ctx) return;

    this.drawBackground(ctx, config, width, height);

    const freqData = new Uint8Array(this.analyser.frequencyBinCount);
    this.analyser.getByteFrequencyData(freqData);

    this.rotation += (config.rotationSpeed * deltaMs) / 1000;
    this.drawRing(ctx, config, freqData, width, height);
    this.drawCenterImage(ctx, config, freqData, width, height);

    if (config.captionEnabled) {
      this.drawCaptions(ctx, config, width, height);
    }
  }

  private drawBackground(ctx: CanvasRenderingContext2D, config: AudioVisualizerConfig, width: number, height: number) {
    if (config.backgroundType === "gradient") {
      const gradient = ctx.createLinearGradient(0, 0, width, height);
      gradient.addColorStop(0, config.backgroundColor);
      gradient.addColorStop(1, config.backgroundColor2);
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, width, height);
    } else if (config.backgroundType === "image" && this.backgroundImage?.complete) {
      ctx.drawImage(this.backgroundImage, 0, 0, width, height);
    } else {
      ctx.fillStyle = config.backgroundColor;
      ctx.fillRect(0, 0, width, height);
    }
  }

  private drawRing(
    ctx: CanvasRenderingContext2D,
    config: AudioVisualizerConfig,
    freqData: Uint8Array,
    width: number,
    height: number
  ) {
    const cx = width / 2;
    const cy = height / 2;
    const baseRadius = Math.min(width, height) * config.ringRadius;
    const angleStep = (Math.PI * 2) / config.barCount;

    if (config.glow) {
      ctx.shadowBlur = 18;
      ctx.shadowColor = config.ringColorEnd;
    } else {
      ctx.shadowBlur = 0;
    }

    for (let i = 0; i < config.barCount; i++) {
      const freqIndex = Math.floor((i / config.barCount) * freqData.length);
      const amplitude = freqData[freqIndex] / 255;
      const barLength = amplitude * config.barMaxLength * config.sensitivity;

      const angle = i * angleStep + (this.rotation * Math.PI) / 180;
      const x1 = cx + Math.cos(angle) * baseRadius;
      const y1 = cy + Math.sin(angle) * baseRadius;
      const x2 = cx + Math.cos(angle) * (baseRadius + barLength);
      const y2 = cy + Math.sin(angle) * (baseRadius + barLength);

      const t = i / config.barCount;
      ctx.strokeStyle = lerpColor(config.ringColorStart, config.ringColorEnd, t);
      ctx.lineWidth = config.barWidth;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    }
    ctx.shadowBlur = 0;
  }

  private drawCenterImage(
    ctx: CanvasRenderingContext2D,
    config: AudioVisualizerConfig,
    freqData: Uint8Array,
    width: number,
    height: number
  ) {
    if (!this.centerImage?.complete) return;
    const cx = width / 2;
    const cy = height / 2;
    const innerRadius = Math.min(width, height) * config.ringRadius;
    let size = innerRadius * 2 * config.centerImageScale;

    if (config.centerImagePulse) {
      const avg = freqData.reduce((a, b) => a + b, 0) / freqData.length / 255;
      size *= 1 + avg * 0.08;
    }

    ctx.save();
    if (config.centerImageCircular) {
      ctx.beginPath();
      ctx.arc(cx, cy, size / 2, 0, Math.PI * 2);
      ctx.clip();
    }
    ctx.drawImage(this.centerImage, cx - size / 2, cy - size / 2, size, size);
    ctx.restore();
  }

  private drawCaptions(ctx: CanvasRenderingContext2D, config: AudioVisualizerConfig, width: number, height: number) {
    const captions = this.getCaptions();
    const t = this.getCurrentTime();
    const y = height - height * config.captionBottomOffset;

    let text = "";
    if (config.captionMode === "word") {
      const current = captions.words.find((w) => t >= w.start && t <= w.end);
      text = current?.word ?? "";
    } else {
      const segment = captions.segments.find((s) => t >= s.start && t <= s.end);
      text = segment?.text ?? "";
    }
    if (!text) return;

    ctx.font = `${config.captionBold ? "700" : "400"} ${config.captionFontSize}px Inter, sans-serif`;
    ctx.textAlign = "center";
    ctx.fillStyle = config.captionColor;
    if (config.captionShadow) {
      ctx.shadowColor = "rgba(0,0,0,0.6)";
      ctx.shadowBlur = 8;
    }
    ctx.fillText(text, width / 2, y, width * 0.85);
    ctx.shadowBlur = 0;
  }
}

function lerpColor(a: string, b: string, t: number): string {
  const ca = hexToRgb(a);
  const cb = hexToRgb(b);
  const r = Math.round(ca.r + (cb.r - ca.r) * t);
  const g = Math.round(ca.g + (cb.g - ca.g) * t);
  const bl = Math.round(ca.b + (cb.b - ca.b) * t);
  return `rgb(${r}, ${g}, ${bl})`;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const clean = hex.replace("#", "");
  return {
    r: parseInt(clean.slice(0, 2), 16),
    g: parseInt(clean.slice(2, 4), 16),
    b: parseInt(clean.slice(4, 6), 16),
  };
}
