export interface CaptionStyle {
  fontFamily: string;
  fontSize: number;
  textColor: string;
  backgroundColor: string;
  bottomOffset: number;
  maxWidthPercent: number;
}

export function createCaptionStyle(): CaptionStyle {
  return {
    fontFamily: "Syne",
    fontSize: 18,
    textColor: "#FFFFFF",
    backgroundColor: "rgba(0,0,0,0.85)",
    bottomOffset: 52,
    maxWidthPercent: 85,
  };
}

export interface Word {
  word: string;
  start: number;
  end: number;
}

export interface TranscriptSegment {
  id: number;
  start: number;
  end: number;
  text: string;
}

export interface CaptionWord {
  word: string;
  startFrame: number;
  endFrame: number;
}

export interface Cut {
  start: number;
  end: number;
  reason: string;
}

export interface Caption {
  startFrame: number;
  endFrame: number;
  text: string;
  words: CaptionWord[] | null;
}

export interface VideoEdit {
  id: string;
  videoFileName: string;
  durationSeconds: number;
  fps: number;
  transcript: TranscriptSegment[];
  cuts: Cut[];
  captions: Caption[];
  analysisNotes: string;
  rotation: number;
}

function num(v: unknown, fallback = 0): number {
  return v == null ? fallback : Number(v);
}

function int(v: unknown, fallback = 0): number {
  return v == null ? fallback : Math.round(Number(v));
}

export function videoEditFromJson(json: Record<string, unknown>): VideoEdit {
  return {
    id: (json.id as string) ?? "",
    videoFileName: (json.videoFileName as string) ?? "",
    durationSeconds: num(json.durationSeconds),
    fps: int(json.fps, 30),
    transcript: ((json.transcript as Record<string, unknown>[]) ?? []).map((t) => ({
      id: int(t.id),
      start: num(t.start),
      end: num(t.end),
      text: (t.text as string) ?? "",
    })),
    cuts: ((json.cuts as Record<string, unknown>[]) ?? []).map((c) => ({
      start: num(c.start),
      end: num(c.end),
      reason: (c.reason as string) ?? "",
    })),
    captions: ((json.captions as Record<string, unknown>[]) ?? []).map((c) => ({
      startFrame: int(c.startFrame),
      endFrame: int(c.endFrame),
      text: (c.text as string) ?? "",
      words: (c.words as Record<string, unknown>[] | undefined)?.map((w) => ({
        word: (w.word as string) ?? "",
        startFrame: int(w.startFrame),
        endFrame: int(w.endFrame),
      })) ?? null,
    })),
    analysisNotes: (json.analysisNotes as string) ?? "",
    rotation: int(json.rotation, 0),
  };
}

export interface KeepSegment {
  start: number;
  end: number;
}

/** Mirrors getKeeps() from the meal-video pipeline: gaps between cuts. */
export function computeKeepSegments(edit: VideoEdit): KeepSegment[] {
  const sorted = [...edit.cuts].sort((a, b) => a.start - b.start);
  const keeps: KeepSegment[] = [];
  let cursor = 0;
  for (const c of sorted) {
    if (c.start > cursor + 0.05) keeps.push({ start: cursor, end: c.start });
    cursor = c.end;
  }
  if (cursor < edit.durationSeconds - 0.05) {
    keeps.push({ start: cursor, end: edit.durationSeconds });
  }
  return keeps;
}

export interface CaptionGap {
  start: number;
  end: number;
}

/** Transcript ranges not covered by any caption (AI grouping skipped them). */
export function findCaptionGaps(edit: VideoEdit, minGapSeconds = 0.5): CaptionGap[] {
  if (edit.transcript.length === 0) return [];

  const capRanges = edit.captions
    .map((c): [number, number] => [c.startFrame / edit.fps, c.endFrame / edit.fps])
    .sort((a, b) => a[0] - b[0]);

  const gaps: CaptionGap[] = [];
  for (const seg of edit.transcript) {
    let cursor = seg.start;
    for (const [capStart, capEnd] of capRanges) {
      if (capEnd <= cursor) continue;
      if (capStart >= seg.end) break;
      if (capStart > cursor) {
        const gapEnd = Math.min(Math.max(capStart, cursor), seg.end);
        if (gapEnd - cursor >= minGapSeconds) gaps.push({ start: cursor, end: gapEnd });
      }
      if (capEnd > cursor) cursor = capEnd;
      if (cursor >= seg.end) break;
    }
    if (cursor < seg.end - 0.001 && seg.end - cursor >= minGapSeconds) {
      gaps.push({ start: cursor, end: seg.end });
    }
  }
  return gaps;
}

export function fmtTime(seconds: number): string {
  const t = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
  const m = Math.floor(t / 60);
  const s = t % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

export function fmtDuration(seconds: number): string {
  const t = Number.isFinite(seconds) ? Math.round(seconds) : 0;
  if (t >= 60) return `${Math.floor(t / 60)}m ${t % 60}s`;
  return `${t}s`;
}

export function parseTimeInput(raw: string): number | null {
  const str = raw.trim();
  if (str.includes(":")) {
    const parts = str.split(":");
    if (parts.length !== 2) return null;
    const m = parseFloat(parts[0]);
    const s = parseFloat(parts[1]);
    if (Number.isNaN(m) || Number.isNaN(s)) return null;
    return m * 60 + s;
  }
  const v = parseFloat(str);
  return Number.isNaN(v) ? null : v;
}
