export interface CaptionWord {
  word: string;
  start: number;
  end: number;
}

export interface CaptionSegment {
  start: number;
  end: number;
  text: string;
  words: CaptionWord[];
}

export interface Captions {
  segments: CaptionSegment[];
  words: CaptionWord[];
}

export const EMPTY_CAPTIONS: Captions = { segments: [], words: [] };

function toNumber(v: unknown): number {
  if (typeof v === "number") return v;
  if (typeof v === "string") return parseFloat(v) || 0;
  return 0;
}

export function parseCaptions(content: string): Captions {
  const trimmed = content.trim();
  if (!trimmed) return EMPTY_CAPTIONS;
  if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
    return parseJsonCaptions(trimmed);
  }
  return parseSrtCaptions(trimmed);
}

function parseJsonCaptions(content: string): Captions {
  const decoded = JSON.parse(content) as {
    segments?: { start?: unknown; end?: unknown; text?: unknown; words?: { word?: unknown; start?: unknown; end?: unknown }[] }[];
    words?: { word?: unknown; start?: unknown; end?: unknown }[];
  };

  const segments: CaptionSegment[] = [];
  const words: CaptionWord[] = [];

  for (const s of decoded.segments ?? []) {
    const segWords: CaptionWord[] = [];
    for (const w of s.words ?? []) {
      const word = String(w.word ?? "").trim();
      if (!word) continue;
      const captionWord: CaptionWord = { word, start: toNumber(w.start), end: toNumber(w.end) };
      segWords.push(captionWord);
      words.push(captionWord);
    }
    segments.push({
      start: toNumber(s.start),
      end: toNumber(s.end),
      text: String(s.text ?? "").trim(),
      words: segWords,
    });
  }

  if (words.length === 0) {
    for (const w of decoded.words ?? []) {
      const word = String(w.word ?? "").trim();
      if (!word) continue;
      words.push({ word, start: toNumber(w.start), end: toNumber(w.end) });
    }
  }

  return { segments, words };
}

const SRT_TIME = /(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})/;

function srtToSeconds(m: RegExpMatchArray, offset: number): number {
  const h = parseInt(m[offset], 10);
  const min = parseInt(m[offset + 1], 10);
  const s = parseInt(m[offset + 2], 10);
  const ms = parseInt(m[offset + 3].padEnd(3, "0"), 10);
  return h * 3600 + min * 60 + s + ms / 1000;
}

function parseSrtCaptions(content: string): Captions {
  const segments: CaptionSegment[] = [];
  const words: CaptionWord[] = [];
  const blocks = content.replace(/\r\n/g, "\n").split(/\n\s*\n/);

  for (const block of blocks) {
    const match = block.match(SRT_TIME);
    if (!match) continue;
    const start = srtToSeconds(match, 1);
    const end = srtToSeconds(match, 5);
    const textLines = block
      .split("\n")
      .filter((line) => !SRT_TIME.test(line) && !/^\d+$/.test(line.trim()) && line.trim().toUpperCase() !== "WEBVTT" && line.trim());
    const text = textLines.join(" ").trim();
    if (!text) continue;
    segments.push({ start, end, text, words: [] });
    words.push({ word: text, start, end });
  }

  return { segments, words };
}
