import { getApiBaseUrl } from "@/features/video-caption/api-base-url";
import { videoEditFromJson, type VideoEdit } from "@/features/video-caption/video-caption-models";

async function extractError(res: Response): Promise<string> {
  try {
    const json = await res.json();
    return (json.error as string) ?? res.statusText;
  } catch {
    return res.statusText;
  }
}

export async function uploadVideo(file: File): Promise<string> {
  const form = new FormData();
  form.append("video", file, file.name);
  const res = await fetch(`${getApiBaseUrl()}/api/process`, { method: "POST", body: form });
  if (!res.ok) throw new Error(await extractError(res));
  const json = await res.json();
  return json.id as string;
}

export async function fetchProcessingStatus(id: string): Promise<{ status: string; edit?: VideoEdit }> {
  const res = await fetch(`${getApiBaseUrl()}/api/status/${id}`);
  if (!res.ok) throw new Error(await extractError(res));
  const json = await res.json();
  return {
    status: json.status as string,
    edit: json.edit ? videoEditFromJson(json.edit) : undefined,
  };
}

export async function saveVideoEdit(edit: VideoEdit): Promise<void> {
  const res = await fetch(`${getApiBaseUrl()}/api/edits/${edit.id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(edit),
  });
  if (!res.ok) throw new Error(await extractError(res));
}

export async function exportFull(editId: string): Promise<Blob> {
  const res = await fetch(`${getApiBaseUrl()}/api/export-full/${editId}`, { method: "POST" });
  if (!res.ok) throw new Error(await extractError(res));
  return res.blob();
}

export async function exportSegment(editId: string, start: number, end: number): Promise<Blob> {
  const res = await fetch(`${getApiBaseUrl()}/api/export-segment/${editId}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ start, end }),
  });
  if (!res.ok) throw new Error(await extractError(res));
  return res.blob();
}
