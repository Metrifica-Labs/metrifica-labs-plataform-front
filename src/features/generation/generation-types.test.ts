import { describe, it, expect } from "vitest";
import { isGenerating, extractImagePrompts } from "@/features/generation/generation-types";

describe("isGenerating", () => {
  it("is true for connecting, thinking and streaming", () => {
    expect(isGenerating("connecting")).toBe(true);
    expect(isGenerating("thinking")).toBe(true);
    expect(isGenerating("streaming")).toBe(true);
  });

  it("is false for idle, done and error", () => {
    expect(isGenerating("idle")).toBe(false);
    expect(isGenerating("done")).toBe(false);
    expect(isGenerating("error")).toBe(false);
  });
});

describe("extractImagePrompts", () => {
  it("extracts fenced code blocks as prompts", () => {
    const output = "Here is a prompt:\n```\na cat in a hat\n```\nand another:\n```\na dog\n```";
    expect(extractImagePrompts(output)).toEqual(["a cat in a hat", "a dog"]);
  });

  it("strips a leading language hint from the fence", () => {
    const output = "```text\nprompt content\n```";
    expect(extractImagePrompts(output)).toEqual(["prompt content"]);
  });

  it("returns an empty array when there are no code blocks", () => {
    expect(extractImagePrompts("just plain text")).toEqual([]);
  });

  it("ignores empty code blocks", () => {
    expect(extractImagePrompts("```\n\n```")).toEqual([]);
  });
});
