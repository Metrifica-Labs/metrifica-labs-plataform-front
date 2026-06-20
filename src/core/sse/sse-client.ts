import { env } from "@/core/env";

export interface SSEEvent {
  type?: string;
  [key: string]: unknown;
}

export function edgeFunctionUrl(name: string): string {
  return `${env.supabaseUrl}/functions/v1/${name}`;
}

/**
 * Returning true from onEvent stops the stream early.
 * Mirrors the Dart client's buffer/split-by-line SSE parsing exactly,
 * so a chunk that splits a JSON payload mid-line is handled the same way.
 */
export async function streamSSE(
  url: string,
  body: unknown,
  onEvent: (event: SSEEvent) => boolean | void,
  signal?: AbortSignal
): Promise<void> {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.supabaseAnonKey}`,
      apikey: env.supabaseAnonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!response.ok || !response.body) {
    const text = await response.text();
    throw new Error(`Erro ${response.status}: ${text}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";

    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (!line) continue;
      if (line === "data: [DONE]") return;
      if (!line.startsWith("data: ")) continue;

      try {
        const json = JSON.parse(line.slice(6)) as SSEEvent;
        if (onEvent(json)) return;
      } catch {
        // malformed line — same as the Dart client's silent catch
      }
    }
  }
}
