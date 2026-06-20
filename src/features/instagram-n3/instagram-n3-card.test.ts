import { describe, it, expect } from "vitest";
import { parseN3Post, n3CardFromJson } from "@/features/instagram-n3/instagram-n3-card";

describe("n3CardFromJson", () => {
  it("maps fields with sane defaults", () => {
    expect(n3CardFromJson({ card: 1, objetivo: "hook", headline: "H", body: "B" })).toEqual({
      card: 1,
      objetivo: "hook",
      headline: "H",
      body: "B",
    });
  });

  it("defaults missing fields", () => {
    expect(n3CardFromJson({})).toEqual({ card: 0, objetivo: "", headline: "", body: "" });
  });
});

describe("parseN3Post", () => {
  it("parses a fenced JSON block with post_type and cards", () => {
    const output =
      '```json\n{"post_type":"2/9","cards":[{"card":1,"objetivo":"hook","headline":"H1","body":"B1"}]}\n```';
    const post = parseN3Post(output);
    expect(post.postType).toBe("post2");
    expect(post.cards).toHaveLength(1);
    expect(post.cards[0]).toMatchObject({ card: 1, headline: "H1" });
  });

  it("parses raw JSON without a fenced block", () => {
    const output = '{"post_type":"1/9","cards":[{"card":1,"objetivo":"x","headline":"y","body":"z"}]}';
    const post = parseN3Post(output);
    expect(post.postType).toBe("post1");
    expect(post.cards).toHaveLength(1);
  });

  it("falls back to the default type and empty cards on invalid JSON", () => {
    const post = parseN3Post("not json at all", "post3");
    expect(post).toEqual({ postType: "post3", cards: [] });
  });

  it("falls back to the default type when post_type label is unknown", () => {
    const output = '{"post_type":"99/9","cards":[]}';
    const post = parseN3Post(output, "post10");
    expect(post.postType).toBe("post10");
  });
});
