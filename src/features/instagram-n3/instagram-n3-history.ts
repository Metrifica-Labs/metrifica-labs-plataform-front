import type { N3Post } from "@/features/instagram-n3/instagram-n3-card";

const STORAGE_KEY = "instagram_n3_history_v1";
const MAX_ENTRIES = 20;

export interface N3HistoryEntry {
  id: string;
  createdAt: string;
  briefing: string;
  post: N3Post;
}

export function loadN3History(): N3HistoryEntry[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as N3HistoryEntry[]) : [];
  } catch {
    return [];
  }
}

export function addN3HistoryEntry(briefing: string, post: N3Post): N3HistoryEntry[] {
  const entry: N3HistoryEntry = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    briefing,
    post,
  };
  const next = [entry, ...loadN3History()].slice(0, MAX_ENTRIES);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  return next;
}
