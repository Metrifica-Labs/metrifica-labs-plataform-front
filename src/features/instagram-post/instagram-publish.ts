import { toPng } from "html-to-image";
import { supabase } from "@/core/supabase/client";
import { edgeFunctionUrl } from "@/core/sse/sse-client";
import { env } from "@/core/env";

async function authHeaders(): Promise<Record<string, string>> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token ?? env.supabaseAnonKey;
  return {
    Authorization: `Bearer ${token}`,
    apikey: env.supabaseAnonKey,
    "Content-Type": "application/json",
  };
}

async function nodeToBlob(node: HTMLElement): Promise<Blob> {
  const dataUrl = await toPng(node, { pixelRatio: 2.5 });
  const res = await fetch(dataUrl);
  return res.blob();
}

export async function uploadSlidesToBucket(
  nodes: HTMLElement[],
  userId: string
): Promise<string[]> {
  const timestamp = Date.now();
  const paths: string[] = [];

  for (let i = 0; i < nodes.length; i++) {
    const blob = await nodeToBlob(nodes[i]);
    const path = `${userId}/${timestamp}/slide-${i + 1}.png`;
    const { error } = await supabase.storage
      .from("instagram-publish-media")
      .upload(path, blob, { contentType: "image/png", upsert: true });
    if (error) throw new Error(`Upload slide ${i + 1}: ${error.message}`);
    paths.push(path);
  }

  return paths;
}

export async function publishInstagramPost(storagePaths: string[]): Promise<void> {
  const headers = await authHeaders();
  const res = await fetch(edgeFunctionUrl("publish-instagram-post"), {
    method: "POST",
    headers,
    body: JSON.stringify({ storagePaths }),
  });
  if (!res.ok) {
    const msg = await res.text().catch(() => res.status.toString());
    throw new Error(`Falha na publicação: ${msg}`);
  }
}

export async function scheduleInstagramPost(
  storagePaths: string[],
  scheduledAt: Date
): Promise<void> {
  const headers = await authHeaders();
  const res = await fetch(edgeFunctionUrl("schedule-instagram-post"), {
    method: "POST",
    headers,
    body: JSON.stringify({ storagePaths, scheduledAt: scheduledAt.toISOString() }),
  });
  if (!res.ok) {
    const msg = await res.text().catch(() => res.status.toString());
    throw new Error(`Falha no agendamento: ${msg}`);
  }
}
