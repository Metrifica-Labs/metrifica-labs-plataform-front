import { VIDEO_ASPECTS, type AudioVisualizerConfig } from "@/features/audio-visualizer/audio-visualizer-config";
import type { Captions } from "@/features/audio-visualizer/captions";

const REFERENCE_WIDTH = 1080;

export class AudioVisualizerEngine {
  private rafId: number | null = null;
  private rotation = 0;
  private lastTimestamp = 0;
  private pulse = 0;
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

    const scaleX = width / REFERENCE_WIDTH;

    this.drawBackground(ctx, config, width, height);

    const freqData = new Uint8Array(this.analyser.frequencyBinCount);
    this.analyser.getByteFrequencyData(freqData);

    const avg = freqData.reduce((a, b) => a + b, 0) / freqData.length / 255;
    const dtSeconds = deltaMs / 1000;
    this.pulse += (avg - this.pulse) * Math.min(1, dtSeconds * 8);

    this.rotation += (config.rotationSpeed * deltaMs) / 1000;
    this.drawRing(ctx, config, freqData, width, height, scaleX);
    this.drawCenterImage(ctx, config, width, height);

    if (config.captionEnabled) {
      this.drawCaptions(ctx, config, width, height, scaleX);
    }
  }

  private drawBackground(ctx: CanvasRenderingContext2D, config: AudioVisualizerConfig, width: number, height: number) {
    ctx.fillStyle = config.backgroundColor;
    ctx.fillRect(0, 0, width, height);

    if (config.backgroundType === "gradient") {
      const gradient = ctx.createLinearGradient(0, 0, width, height);
      gradient.addColorStop(0, config.backgroundColor);
      gradient.addColorStop(1, config.backgroundColor2);
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, width, height);
    } else if (config.backgroundType === "image" && this.backgroundImage?.complete) {
      drawImageCover(ctx, this.backgroundImage, 0, 0, width, height);
    }
  }

  private drawRing(
    ctx: CanvasRenderingContext2D,
    config: AudioVisualizerConfig,
    freqData: Uint8Array,
    width: number,
    height: number,
    scaleX: number
  ) {
    const cx = width / 2;
    const cy = height / 2;
    const baseRadius = Math.min(width, height) * config.ringRadius;
    const angleStep = (Math.PI * 2) / config.barCount;
    const barWidth = config.barWidth * scaleX;
    const barMaxLength = config.barMaxLength * scaleX;
    const half = Math.ceil(config.barCount / 2);

    if (config.glow) {
      ctx.shadowBlur = 16 * scaleX;
      ctx.shadowColor = config.ringColorEnd;
    } else {
      ctx.shadowBlur = 0;
    }

    for (let i = 0; i < config.barCount; i++) {
      const mirrored = i < half ? i : config.barCount - i;
      const freqIndex = Math.min(freqData.length - 1, Math.floor((mirrored / half) * freqData.length * 0.7));
      const amplitude = freqData[freqIndex] / 255;
      const barLength = Math.max(2, amplitude * barMaxLength * config.sensitivity);

      const angle = i * angleStep + (this.rotation * Math.PI) / 180;
      const t = i / config.barCount;
      const color = lerpColor(config.ringColorStart, config.ringColorEnd, t);

      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(angle);
      const gradient = ctx.createLinearGradient(0, -baseRadius, 0, -baseRadius - barLength);
      gradient.addColorStop(0, withAlphaCss(color, 0.35));
      gradient.addColorStop(1, color);
      ctx.fillStyle = gradient;
      ctx.beginPath();
      const r = barWidth / 2;
      roundRect(ctx, -r, -baseRadius - barLength, barWidth, barLength, r);
      ctx.fill();
      ctx.restore();
    }
    ctx.shadowBlur = 0;
  }

  private drawCenterImage(ctx: CanvasRenderingContext2D, config: AudioVisualizerConfig, width: number, height: number) {
    const cx = width / 2;
    const cy = height / 2;
    const innerRadius = Math.min(width, height) * config.ringRadius;
    let size = innerRadius * 2 * config.centerImageScale;

    if (config.centerImagePulse) {
      size *= 1 + this.pulse * 0.12;
    }

    if (!this.centerImage?.complete) {
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, size / 2, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(255,255,255,0.04)";
      ctx.fill();
      ctx.restore();
      return;
    }

    ctx.save();
    if (config.centerImageCircular) {
      ctx.beginPath();
      ctx.arc(cx, cy, size / 2, 0, Math.PI * 2);
      ctx.clip();
    }
    drawImageCover(ctx, this.centerImage, cx - size / 2, cy - size / 2, size, size);
    ctx.restore();
  }

  private drawCaptions(
    ctx: CanvasRenderingContext2D,
    config: AudioVisualizerConfig,
    width: number,
    height: number,
    scaleX: number
  ) {
    const captions = this.getCaptions();
    const t = this.getCurrentTime();
    const y = height - height * config.captionBottomOffset;
    const fontSize = config.captionFontSize * scaleX;
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    if (config.captionShadow) {
      ctx.shadowColor = "rgba(0,0,0,0.6)";
      ctx.shadowBlur = 8 * scaleX;
    } else {
      ctx.shadowBlur = 0;
    }
    ctx.font = `${config.captionBold ? "700" : "400"} ${fontSize}px Inter, sans-serif`;

    if (config.captionMode === "word") {
      const current = findCurrentWord(captions.words, t);
      if (current) ctx.fillText(current.word, width / 2, y, width * 0.9);
    } else if (config.captionMode === "karaoke") {
      this.drawKaraoke(ctx, config, captions, t, width, y, fontSize);
    } else {
      const segment = captions.segments.find((s) => t >= s.start && t <= s.end);
      if (segment?.text) {
        ctx.fillStyle = config.captionColor;
        drawWrappedText(ctx, segment.text, width / 2, y, width * 0.86, fontSize * 1.25);
      }
    }
    ctx.shadowBlur = 0;
  }

  private drawKaraoke(
    ctx: CanvasRenderingContext2D,
    config: AudioVisualizerConfig,
    captions: Captions,
    t: number,
    width: number,
    y: number,
    fontSize: number
  ) {
    const activeIdx = captions.words.findIndex((w) => t >= w.start && t <= w.end);
    if (activeIdx === -1) {
      const segment = captions.segments.find((s) => t >= s.start && t <= s.end);
      if (segment?.text) {
        ctx.fillStyle = config.captionColor;
        drawWrappedText(ctx, segment.text, width / 2, y, width * 0.86, fontSize * 1.25);
      }
      return;
    }

    const maxWords = Math.max(1, config.captionMaxWords);
    const groupStart = Math.floor(activeIdx / maxWords) * maxWords;
    const group = captions.words.slice(groupStart, groupStart + maxWords);
    const space = ctx.measureText(" ").width;
    const widths = group.map((w) => ctx.measureText(w.word).width);
    const totalWidth = widths.reduce((a, b) => a + b, 0) + space * (group.length - 1);

    let x = width / 2 - totalWidth / 2;
    ctx.textAlign = "left";
    for (let i = 0; i < group.length; i++) {
      const isActive = groupStart + i === activeIdx;
      ctx.fillStyle = isActive ? config.captionHighlightColor : config.captionColor;
      ctx.fillText(group[i].word, x, y);
      x += widths[i] + space;
    }
    ctx.textAlign = "center";
  }
}

function findCurrentWord<T extends { start: number; end: number }>(words: T[], t: number): T | null {
  let current: T | null = null;
  for (const w of words) {
    if (w.start <= t) current = w;
    else break;
  }
  if (current && t > current.end + 1.5) return null;
  return current;
}

function drawWrappedText(
  ctx: CanvasRenderingContext2D,
  text: string,
  cx: number,
  baseY: number,
  maxWidth: number,
  lineHeight: number
) {
  const words = text.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (ctx.measureText(candidate).width > maxWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) lines.push(line);

  const startY = baseY - ((lines.length - 1) * lineHeight) / 2;
  lines.forEach((l, i) => ctx.fillText(l, cx, startY + i * lineHeight));
}

function drawImageCover(
  ctx: CanvasRenderingContext2D,
  img: HTMLImageElement,
  dx: number,
  dy: number,
  dw: number,
  dh: number
) {
  const imgRatio = img.naturalWidth / img.naturalHeight;
  const boxRatio = dw / dh;
  let sx = 0;
  let sy = 0;
  let sw = img.naturalWidth;
  let sh = img.naturalHeight;

  if (imgRatio > boxRatio) {
    sw = img.naturalHeight * boxRatio;
    sx = (img.naturalWidth - sw) / 2;
  } else {
    sh = img.naturalWidth / boxRatio;
    sy = (img.naturalHeight - sh) / 2;
  }
  ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
}

function lerpColor(a: string, b: string, t: number): string {
  const ca = hexToRgb(a);
  const cb = hexToRgb(b);
  const r = Math.round(ca.r + (cb.r - ca.r) * t);
  const g = Math.round(ca.g + (cb.g - ca.g) * t);
  const bl = Math.round(ca.b + (cb.b - ca.b) * t);
  return `rgb(${r}, ${g}, ${bl})`;
}

function withAlphaCss(rgb: string, alpha: number): string {
  const match = rgb.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
  if (!match) return rgb;
  return `rgba(${match[1]}, ${match[2]}, ${match[3]}, ${alpha})`;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const clean = hex.replace("#", "");
  return {
    r: parseInt(clean.slice(0, 2), 16),
    g: parseInt(clean.slice(2, 4), 16),
    b: parseInt(clean.slice(4, 6), 16),
  };
}
