import { env } from "@/core/env";
import { parseCaptions, type Captions } from "@/features/audio-visualizer/captions";

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export async function transcribeAudio(file: File): Promise<Captions> {
  const buffer = await file.arrayBuffer();
  const audioBase64 = arrayBufferToBase64(buffer);

  const response = await fetch(`${env.supabaseUrl}/functions/v1/transcribe-audio`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.supabaseAnonKey}`,
      apikey: env.supabaseAnonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ audio_base64: audioBase64, mime_type: file.type }),
  });

  if (!response.ok) {
    throw new Error(`Erro ${response.status}: ${await response.text()}`);
  }

  return parseCaptions(await response.text());
}
