import { describe, it, expect } from "vitest";
import {
  videoEditFromJson,
  computeKeepSegments,
  findCaptionGaps,
  fmtTime,
  fmtDuration,
  parseTimeInput,
  type VideoEdit,
} from "@/features/video-caption/video-caption-models";

function makeEdit(overrides: Partial<VideoEdit> = {}): VideoEdit {
  return {
    id: "edit-1",
    videoFileName: "video.mp4",
    durationSeconds: 100,
    fps: 30,
    transcript: [],
    cuts: [],
    captions: [],
    analysisNotes: "",
    rotation: 0,
    ...overrides,
  };
}

describe("videoEditFromJson", () => {
  it("maps nested arrays and defaults missing fields", () => {
    const edit = videoEditFromJson({
      id: "e1",
      videoFileName: "v.mp4",
      durationSeconds: 12.5,
      fps: 24,
      transcript: [{ id: 1, start: 0, end: 1, text: "hi" }],
      cuts: [{ start: 1, end: 2, reason: "silence" }],
      captions: [{ startFrame: 0, endFrame: 30, text: "hi" }],
      analysisNotes: "looks good",
    });
    expect(edit.fps).toBe(24);
    expect(edit.transcript).toEqual([{ id: 1, start: 0, end: 1, text: "hi" }]);
    expect(edit.cuts).toEqual([{ start: 1, end: 2, reason: "silence" }]);
    expect(edit.captions[0]).toMatchObject({ startFrame: 0, endFrame: 30, text: "hi", words: null });
    expect(edit.rotation).toBe(0);
  });
});

describe("computeKeepSegments", () => {
  it("returns the full duration as one keep segment when there are no cuts", () => {
    const edit = makeEdit({ durationSeconds: 10, cuts: [] });
    expect(computeKeepSegments(edit)).toEqual([{ start: 0, end: 10 }]);
  });

  it("computes gaps between sorted cuts", () => {
    const edit = makeEdit({
      durationSeconds: 10,
      cuts: [
        { start: 5, end: 6, reason: "" },
        { start: 1, end: 2, reason: "" },
      ],
    });
    expect(computeKeepSegments(edit)).toEqual([
      { start: 0, end: 1 },
      { start: 2, end: 5 },
      { start: 6, end: 10 },
    ]);
  });

  it("omits the trailing keep when a cut reaches the end", () => {
    const edit = makeEdit({ durationSeconds: 10, cuts: [{ start: 0, end: 10, reason: "" }] });
    expect(computeKeepSegments(edit)).toEqual([]);
  });
});

describe("findCaptionGaps", () => {
  it("returns no gaps when there is no transcript", () => {
    expect(findCaptionGaps(makeEdit({ transcript: [] }))).toEqual([]);
  });

  it("finds a gap when a transcript segment is not covered by any caption", () => {
    const edit = makeEdit({
      transcript: [{ id: 1, start: 0, end: 5, text: "spoken" }],
      captions: [],
    });
    expect(findCaptionGaps(edit)).toEqual([{ start: 0, end: 5 }]);
  });

  it("excludes the portion of the transcript covered by a caption", () => {
    const edit = makeEdit({
      fps: 10,
      transcript: [{ id: 1, start: 0, end: 5, text: "spoken" }],
      captions: [{ startFrame: 0, endFrame: 30, text: "spoken", words: null }],
    });
    expect(findCaptionGaps(edit)).toEqual([{ start: 3, end: 5 }]);
  });

  it("ignores gaps smaller than minGapSeconds", () => {
    const edit = makeEdit({
      fps: 10,
      transcript: [{ id: 1, start: 0, end: 3.2, text: "spoken" }],
      captions: [{ startFrame: 0, endFrame: 30, text: "spoken", words: null }],
    });
    expect(findCaptionGaps(edit, 0.5)).toEqual([]);
  });
});

describe("fmtTime", () => {
  it("formats seconds as m:ss", () => {
    expect(fmtTime(65)).toBe("1:05");
    expect(fmtTime(5)).toBe("0:05");
  });

  it("clamps non-finite or negative values to 0", () => {
    expect(fmtTime(-10)).toBe("0:00");
    expect(fmtTime(NaN)).toBe("0:00");
  });
});

describe("fmtDuration", () => {
  it("shows minutes and seconds past one minute", () => {
    expect(fmtDuration(125)).toBe("2m 5s");
  });

  it("shows only seconds under one minute", () => {
    expect(fmtDuration(45)).toBe("45s");
  });
});

describe("parseTimeInput", () => {
  it("parses mm:ss into total seconds", () => {
    expect(parseTimeInput("1:30")).toBe(90);
  });

  it("parses a plain number of seconds", () => {
    expect(parseTimeInput("42.5")).toBe(42.5);
  });

  it("returns null for malformed input", () => {
    expect(parseTimeInput("not-a-time")).toBeNull();
    expect(parseTimeInput("1:2:3")).toBeNull();
  });
});
