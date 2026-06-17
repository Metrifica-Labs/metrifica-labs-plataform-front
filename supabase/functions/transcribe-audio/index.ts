const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { audio_base64, mime_type = "audio/mpeg" } = await req.json();

    if (!audio_base64 || typeof audio_base64 !== "string") {
      return new Response(
        JSON.stringify({ error: "audio_base64 é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const serverUrl = Deno.env.get("WHISPER_SERVER_URL");
    const apiKey = Deno.env.get("WHISPER_API_KEY");
    if (!serverUrl || !apiKey) {
      throw new Error("WHISPER_SERVER_URL/WHISPER_API_KEY não configurados");
    }

    const audioBytes = Uint8Array.from(atob(audio_base64), (c) => c.charCodeAt(0));

    const extByMime: Record<string, string> = {
      "audio/mpeg": "mp3",
      "audio/wav": "wav",
      "audio/mp4": "m4a",
      "audio/ogg": "ogg",
      "audio/webm": "webm",
    };
    const ext = extByMime[mime_type] ?? "audio";

    const form = new FormData();
    form.append("file", new Blob([audioBytes], { type: mime_type }), `audio.${ext}`);

    const upstream = await fetch(`${serverUrl}/transcribe`, {
      method: "POST",
      signal: AbortSignal.timeout(280_000),
      headers: { "X-API-Key": apiKey },
      body: form,
    });

    const text = await upstream.text();
    if (!upstream.ok) {
      throw new Error(`Whisper server error ${upstream.status}: ${text}`);
    }

    return new Response(text, {
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Erro interno";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    );
  }
});
