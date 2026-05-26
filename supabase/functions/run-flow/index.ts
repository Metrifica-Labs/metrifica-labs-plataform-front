import { createClient } from "jsr:@supabase/supabase-js@2";

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
    const { flow_slug, user_message, extra_context } = await req.json();

    if (!flow_slug || !user_message) {
      return new Response(
        JSON.stringify({ error: "flow_slug e user_message são obrigatórios" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    // ── 1. Supabase client ──────────────────────────────────────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── 2. Busca o fluxo ────────────────────────────────────────────────────
    const { data: flow, error: flowError } = await supabase
      .from("flows")
      .select("slug, name, module_slugs")
      .eq("slug", flow_slug)
      .single();

    if (flowError || !flow) {
      return new Response(
        JSON.stringify({ error: `Fluxo '${flow_slug}' não encontrado` }),
        { status: 404, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    // ── 3. Busca os módulos do fluxo ────────────────────────────────────────
    const { data: modules, error: modulesError } = await supabase
      .from("modules")
      .select("slug, name, content")
      .in("slug", flow.module_slugs);

    if (modulesError || !modules || modules.length === 0) {
      return new Response(
        JSON.stringify({ error: "Erro ao carregar módulos do fluxo" }),
        { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    // ── 4. Ordena os módulos conforme a ordem definida no fluxo ────────────
    const orderedModules = flow.module_slugs
      .map((slug: string) => modules.find((m) => m.slug === slug))
      .filter(Boolean) as { slug: string; name: string; content: string }[];

    // ── 5. Monta o system prompt ────────────────────────────────────────────
    const systemPrompt = [
      "Você é o assistente operacional da Metrifica Labs.",
      "Leia os módulos de contexto abaixo e execute a solicitação do usuário rigorosamente dentro das regras e informações presentes neles.",
      "Nunca invente informações que não estejam nos módulos. Nunca ignore as restrições definidas.",
      "",
      "---",
      "",
      ...orderedModules.map((m) => `## ${m.name}\n\n${m.content}`),
    ].join("\n\n");

    const userContent = extra_context
      ? `${user_message}\n\n**Contexto adicional:**\n${extra_context}`
      : user_message;

    // ── 6. Chama o CrofAI com streaming ────────────────────────────────────
    // AbortController manual — permite abortar tanto o fetch inicial quanto a
    // leitura do body (AbortSignal.timeout não aborta body reads de forma confiável no Deno).
    const crofAbort = new AbortController();
    // Timeout global de 115s (abaixo do hard-limit de 150s do Supabase Edge).
    const globalTimeoutId = setTimeout(() => crofAbort.abort(new Error("global timeout")), 115_000);

    const crofResponse = await fetch("https://crof.ai/v1/chat/completions", {
      method: "POST",
      signal: crofAbort.signal,
      headers: {
        "Authorization": `Bearer ${Deno.env.get("CROFAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-v3.2",
        max_tokens: 8192,
        stream: true,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
      }),
    });

    if (!crofResponse.ok || !crofResponse.body) {
      const errText = await crofResponse.text();
      return new Response(
        JSON.stringify({ error: `CrofAI error: ${crofResponse.status}`, detail: errText }),
        { status: 502, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    // ── 7. Retorna como SSE — captura content e reasoning_content ───────────
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const safeEnqueue = (controller: ReadableStreamDefaultController, data: unknown) => {
      try { controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`)); } catch { /* controller já fechado */ }
    };

    const readable = new ReadableStream({
      async start(controller) {
        safeEnqueue(controller, { type: "flow_start", flow: flow.name });

        const reader = crofResponse.body!.getReader();
        let buffer = "";
        let hasContent = false;
        let accumulatedReasoning = "";

        // Keepalive: envia comentário SSE a cada 20s para manter a conexão viva
        // em proxies/balanceadores que fecham streams ociosos.
        const keepaliveId = setInterval(() => {
          try { controller.enqueue(encoder.encode(": keep-alive\n\n")); } catch { /* ignore */ }
        }, 20_000);

        try {
          let crofError: string | null = null;

          while (true) {
            // timeout por chunk — cancela o timer se o read vencer (sem vazamento)
            let chunkTimerId: ReturnType<typeof setTimeout>;
            const timeoutPromise = new Promise<never>((_, reject) => {
              chunkTimerId = setTimeout(() => reject(new Error("chunk timeout")), 30_000);
            });

            let readResult: ReadableStreamReadResult<Uint8Array>;
            try {
              readResult = await Promise.race([reader.read(), timeoutPromise]);
            } finally {
              clearTimeout(chunkTimerId!);
            }

            if (readResult.done) break;

            buffer += decoder.decode(readResult.value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";

            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed || trimmed === "data: [DONE]") continue;
              if (!trimmed.startsWith("data: ")) continue;

              try {
                const json = JSON.parse(trimmed.slice(6));

                // CrofAI retornou erro no body SSE — registra e sai do loop
                if (json.error) {
                  const errMsg = json.error?.message ?? JSON.stringify(json.error);
                  console.error(`[run-flow] CrofAI SSE error: ${errMsg}`);
                  crofError = `CrofAI: ${errMsg}`;
                  break;
                }

                const delta = json.choices?.[0]?.delta ?? {};

                if (delta.content) {
                  hasContent = true;
                  safeEnqueue(controller, { type: "text", text: delta.content });
                }

                // reasoning_content (modelos estilo DeepSeek R1)
                if (delta.reasoning_content) {
                  accumulatedReasoning += delta.reasoning_content;
                  safeEnqueue(controller, { type: "thinking", text: delta.reasoning_content });
                }
              } catch {
                // linha malformada, ignora
              }
            }

            if (crofError) break;
          }

          if (crofError) {
            safeEnqueue(controller, { type: "error", message: crofError });
          } else if (!hasContent && accumulatedReasoning.trim()) {
            // Fallback: modelo retornou tudo em reasoning_content sem content
            safeEnqueue(controller, { type: "text", text: accumulatedReasoning });
          }

        } catch (streamErr) {
          const msg = String(streamErr);
          const isTimeout = msg.includes("timeout") || msg.includes("Abort");
          console.error(`[run-flow] stream error: ${msg}`);
          safeEnqueue(controller, {
            type: "error",
            message: isTimeout
              ? "Tempo limite excedido. Tente uma mensagem mais curta."
              : msg,
          });
        } finally {
          // Sempre fecha o stream — independente de como o try/catch terminou.
          clearInterval(keepaliveId);
          clearTimeout(globalTimeoutId);
          try { reader.cancel(); } catch { /* ignore */ }
          try {
            controller.enqueue(encoder.encode("data: [DONE]\n\n"));
            controller.close();
          } catch { /* controller já fechado */ }
        }
      },
    });

    return new Response(readable, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
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
