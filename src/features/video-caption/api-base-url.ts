const STORAGE_KEY = "video_caption_api_base_url";
const DEFAULT_BASE_URL = "http://localhost:3002";

export function getApiBaseUrl(): string {
  return localStorage.getItem(STORAGE_KEY) ?? DEFAULT_BASE_URL;
}

export function setApiBaseUrl(url: string): void {
  localStorage.setItem(STORAGE_KEY, url);
}
