const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const HF_BASE = "https://platform.higgsfield.ai";

// Aspect ratio → Soul width_and_height (valores exatos aceitos pela API)
const ASPECT_TO_SIZE: Record<string, string> = {
  "1:1":  "1536x1536",
  "4:5":  "1152x1536",
  "9:16": "1152x2048",
  "16:9": "2048x1152",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { prompt, aspect_ratio = "1:1" } = await req.json();

    if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "prompt é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const credentials = Deno.env.get("HIGGSFIELD_CREDENTIALS");
    if (!credentials) throw new Error("HIGGSFIELD_CREDENTIALS não configurado");

    const width_and_height = ASPECT_TO_SIZE[aspect_ratio] ?? "1024x1024";

    // ── 1. Submete geração ao Higgsfield Soul ──────────────────────────────
    const submitRes = await fetch(`${HF_BASE}/v1/text2image/soul`, {
      method: "POST",
      signal: AbortSignal.timeout(30_000),
      headers: {
        "Authorization": `Key ${credentials}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        params: {
          prompt: prompt.trim(),
          width_and_height,
          quality: "720p",
          batch_size: 1,
          enhance_prompt: false,
        },
      }),
    });

    if (!submitRes.ok) {
      const err = await submitRes.text();
      throw new Error(`Higgsfield submit error ${submitRes.status}: ${err}`);
    }

    const { request_id } = await submitRes.json();
    if (!request_id) throw new Error("Higgsfield não retornou request_id");

    // ── 2. Streaming SSE com polling ───────────────────────────────────────
    const encoder = new TextEncoder();

    const readable = new ReadableStream({
      async start(controller) {
        const send = (obj: unknown) =>
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(obj)}\n\n`));

        send({ type: "queued", request_id });

        const MAX_WAIT_MS = 120_000;
        const POLL_INTERVAL_MS = 3_000;
        const started = Date.now();

        while (Date.now() - started < MAX_WAIT_MS) {
          await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));

          let statusRes: Response;
          try {
            statusRes = await fetch(
              `${HF_BASE}/requests/${request_id}/status`,
              {
                signal: AbortSignal.timeout(15_000),
                headers: { "Authorization": `Key ${credentials}` },
              }
            );
          } catch (fetchErr) {
            send({ type: "error", message: `Polling falhou: ${fetchErr}` });
            controller.close();
            return;
          }

          if (!statusRes.ok) {
            const errText = await statusRes.text();
            send({ type: "error", message: `Higgsfield status ${statusRes.status}: ${errText}` });
            controller.close();
            return;
          }

          const data = await statusRes.json();

          // JobSet completo
          if (data.isCompleted) {
            const job = data.jobs?.[0];
            const url = job?.results?.raw?.url ?? job?.results?.min?.url;
            if (url) {
              send({ type: "image_url", url });
            } else {
              send({ type: "error", message: "Geração concluída mas sem URL de imagem" });
            }
            break;
          }

          if (data.isFailed) {
            send({ type: "error", message: "Higgsfield: geração falhou" });
            break;
          }

          if (data.isNsfw) {
            send({ type: "error", message: "Conteúdo rejeitado pelo sistema de moderação" });
            break;
          }

          // Ainda processando — emite progresso
          const status: string = data.isInProgress ? "in_progress" : "queued";
          send({ type: "progress", status });
        }

        if (Date.now() - started >= MAX_WAIT_MS) {
          send({ type: "error", message: "Tempo limite de 120s excedido" });
        }

        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      },
    });

    return new Response(readable, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        ...CORS_HEADERS,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Erro interno";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    );
  }
});
