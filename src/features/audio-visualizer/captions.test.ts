import { describe, it, expect } from "vitest";
import { parseCaptions, EMPTY_CAPTIONS } from "@/features/audio-visualizer/captions";

describe("parseCaptions", () => {
  it("returns empty captions for blank input", () => {
    expect(parseCaptions("   ")).toEqual(EMPTY_CAPTIONS);
  });

  it("parses segments with word-level timestamps from JSON", () => {
    const json = JSON.stringify({
      segments: [
        {
          start: 0,
          end: 1.5,
          text: "hello world",
          words: [
            { word: "hello", start: 0, end: 0.7 },
            { word: "world", start: 0.8, end: 1.5 },
          ],
        },
      ],
    });
    const captions = parseCaptions(json);
    expect(captions.segments).toHaveLength(1);
    expect(captions.segments[0]).toMatchObject({ start: 0, end: 1.5, text: "hello world" });
    expect(captions.words).toHaveLength(2);
    expect(captions.words[1]).toEqual({ word: "world", start: 0.8, end: 1.5 });
  });

  it("falls back to a flat words list when there are no segments", () => {
    const json = JSON.stringify({ words: [{ word: "solo", start: 0, end: 0.3 }] });
    const captions = parseCaptions(json);
    expect(captions.segments).toEqual([]);
    expect(captions.words).toEqual([{ word: "solo", start: 0, end: 0.3 }]);
  });

  it("parses SRT content into segments and synthetic words", () => {
    const srt = "1\n00:00:01,000 --> 00:00:02,500\nHello there\n\n2\n00:00:03,000 --> 00:00:04,000\nSecond line\n";
    const captions = parseCaptions(srt);
    expect(captions.segments).toHaveLength(2);
    expect(captions.segments[0]).toMatchObject({ start: 1, end: 2.5, text: "Hello there" });
    expect(captions.segments[1]).toMatchObject({ start: 3, end: 4, text: "Second line" });
  });

  it("ignores WEBVTT header and cue numbers when parsing VTT-style content", () => {
    const vtt = "WEBVTT\n\n1\n00:00:00,000 --> 00:00:01,000\nIntro";
    const captions = parseCaptions(vtt);
    expect(captions.segments).toHaveLength(1);
    expect(captions.segments[0].text).toBe("Intro");
  });
});
