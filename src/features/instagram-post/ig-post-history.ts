import type { PostStyle, SlideContent } from "@/features/instagram-post/instagram-post-style";

const STORAGE_KEY = "ig_post_history_v1";
const MAX_ENTRIES = 15;

export interface IgPostHistoryEntry {
  id: string;
  createdAt: string;
  briefing: string;
  slides: SlideContent[];
  style: Omit<PostStyle, "avatarUrl" | "logoUrl" | "slides">;
}

function stripImageData(slides: SlideContent[]): SlideContent[] {
  return slides.map((s) => ({
    ...s,
    imageUrl: s.imageUrl?.startsWith("data:") ? null : s.imageUrl,
    coverImageUrl: s.coverImageUrl?.startsWith("data:") ? null : s.coverImageUrl,
  }));
}

export function loadIgPostHistory(): IgPostHistoryEntry[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as IgPostHistoryEntry[];
  } catch {
    return [];
  }
}

export function addIgPostHistoryEntry(briefing: string, slides: SlideContent[], style: PostStyle): IgPostHistoryEntry[] {
  const styleRest = { ...style };
  delete (styleRest as Partial<PostStyle>).avatarUrl;
  delete (styleRest as Partial<PostStyle>).logoUrl;
  delete (styleRest as Partial<PostStyle>).slides;
  const entry: IgPostHistoryEntry = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    briefing,
    slides: stripImageData(slides),
    style: styleRest,
  };
  const current = loadIgPostHistory();
  const next = [entry, ...current].slice(0, MAX_ENTRIES);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  return next;
}

export function removeIgPostHistoryEntry(id: string): IgPostHistoryEntry[] {
  const next = loadIgPostHistory().filter((e) => e.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  return next;
}
