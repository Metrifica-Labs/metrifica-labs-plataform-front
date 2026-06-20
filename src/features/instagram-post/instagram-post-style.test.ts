import { describe, it, expect } from "vitest";
import {
  createPostStyle,
  createSlide,
  parseSlides,
  resolveBg,
  resolveText,
  resolveHeadlineColor,
  resolveBodyColor,
  withAlpha,
} from "@/features/instagram-post/instagram-post-style";

describe("withAlpha", () => {
  it("converts hex to rgba with the given alpha", () => {
    expect(withAlpha("#FF0000", 0.5)).toBe("rgba(255, 0, 0, 0.5)");
  });
});

describe("resolve* color helpers", () => {
  const style = createPostStyle();

  it("falls back to global style colors when slide has none", () => {
    const slide = createSlide({});
    expect(resolveBg(slide, style)).toBe(style.bgColor);
    expect(resolveText(slide, style)).toBe(style.textColor);
    expect(resolveHeadlineColor(slide, style)).toBe(style.textColor);
  });

  it("prefers slide-specific colors over global ones", () => {
    const slide = createSlide({ slideBgColor: "#111111", slideTextColor: "#222222" });
    expect(resolveBg(slide, style)).toBe("#111111");
    expect(resolveText(slide, style)).toBe("#222222");
    expect(resolveHeadlineColor(slide, style)).toBe("#222222");
  });

  it("applies 72% alpha to body color derived from slideTextColor", () => {
    const slide = createSlide({ slideTextColor: "#101012" });
    expect(resolveBodyColor(slide, style)).toBe(withAlpha("#101012", 0.72));
  });
});

describe("parseSlides", () => {
  it("parses a structured JSON block with slides", () => {
    const output =
      '```json\n{"slides":[{"headline":"A","body":"B"},{"headline":"C","swipeText":"swipe"}]}\n```';
    const slides = parseSlides(output);
    expect(slides).toHaveLength(2);
    expect(slides[0]).toMatchObject({ headline: "A", body: "B" });
    expect(slides[1]).toMatchObject({ headline: "C", swipeText: "swipe" });
  });

  it("supports a plain string array of slides", () => {
    const output = '```json\n{"slides":["First slide","Second slide"]}\n```';
    const slides = parseSlides(output);
    expect(slides.map((s) => s.headline)).toEqual(["First slide", "Second slide"]);
  });

  it("falls back to splitting paragraphs when there is no JSON", () => {
    const output = "# Title one\nBody one\n\nTitle two\nBody two";
    const slides = parseSlides(output);
    expect(slides).toHaveLength(2);
    expect(slides[0].headline).toBe("Title one");
    expect(slides[0].body).toBe("Body one");
    expect(slides[1].headline).toBe("Title two");
  });

  it("returns an empty array for empty output", () => {
    expect(parseSlides("   ")).toEqual([]);
  });

  it("applies the given default layout to fallback slides", () => {
    const slides = parseSlides("Just one slide", "imageCover");
    expect(slides[0].layout).toBe("imageCover");
  });
});
