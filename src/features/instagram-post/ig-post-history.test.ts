import { describe, it, expect, beforeEach } from "vitest";
import {
  loadIgPostHistory,
  addIgPostHistoryEntry,
  removeIgPostHistoryEntry,
} from "@/features/instagram-post/ig-post-history";
import { createPostStyle, createSlide } from "@/features/instagram-post/instagram-post-style";

beforeEach(() => {
  localStorage.clear();
});

describe("ig post history", () => {
  it("starts empty", () => {
    expect(loadIgPostHistory()).toEqual([]);
  });

  it("adds an entry and strips large data: URLs from slide images", () => {
    const style = createPostStyle();
    const slides = [createSlide({ headline: "Hi", imageUrl: "data:image/png;base64,AAAA" })];

    const entries = addIgPostHistoryEntry("a cool post", slides, style);

    expect(entries).toHaveLength(1);
    expect(entries[0].briefing).toBe("a cool post");
    expect(entries[0].slides[0].imageUrl).toBeNull();
    expect("avatarUrl" in entries[0].style).toBe(false);
    expect("slides" in entries[0].style).toBe(false);
  });

  it("keeps remote (non data:) image URLs intact", () => {
    const slides = [createSlide({ headline: "Hi", coverImageUrl: "https://cdn.example.com/img.png" })];
    const entries = addIgPostHistoryEntry("brief", slides, createPostStyle());
    expect(entries[0].slides[0].coverImageUrl).toBe("https://cdn.example.com/img.png");
  });

  it("caps history at 15 entries", () => {
    for (let i = 0; i < 20; i++) {
      addIgPostHistoryEntry(`post ${i}`, [createSlide({ headline: String(i) })], createPostStyle());
    }
    expect(loadIgPostHistory()).toHaveLength(15);
  });

  it("removes an entry by id", () => {
    const [entry] = addIgPostHistoryEntry("brief", [createSlide({})], createPostStyle());
    const remaining = removeIgPostHistoryEntry(entry.id);
    expect(remaining).toEqual([]);
    expect(loadIgPostHistory()).toEqual([]);
  });
});
