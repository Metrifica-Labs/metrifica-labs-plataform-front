import type { AudioVisualizerConfig } from "@/features/audio-visualizer/audio-visualizer-config";

const STORAGE_KEY = "audio_visualizer_presets_v1";

type PresetJson = Omit<AudioVisualizerConfig, "centerImageUrl" | "backgroundImageUrl">;

function readAll(): Record<string, PresetJson> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Record<string, PresetJson>) : {};
  } catch {
    return {};
  }
}

function writeAll(all: Record<string, PresetJson>) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
}

export function listPresetNames(): string[] {
  return Object.keys(readAll()).sort();
}

export function savePreset(name: string, config: AudioVisualizerConfig): void {
  const all = readAll();
  const { centerImageUrl, backgroundImageUrl, ...rest } = config;
  void centerImageUrl;
  void backgroundImageUrl;
  all[name] = rest;
  writeAll(all);
}

export function loadPreset(name: string, base: AudioVisualizerConfig): AudioVisualizerConfig | null {
  const json = readAll()[name];
  if (!json) return null;
  return { ...base, ...json };
}

export function deletePreset(name: string): void {
  const all = readAll();
  delete all[name];
  writeAll(all);
}
