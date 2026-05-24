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

    // ── 6. Chama o CrofAI (kimi-k2.6) com streaming ────────────────────────
    const crofResponse = await fetch("https://crof.ai/v1/chat/completions", {
      method: "POST",
      signal: AbortSignal.timeout(100_000), // 100s — abaixo do limite do Supabase
      headers: {
        "Authorization": `Bearer ${Deno.env.get("CROFAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-v4-pro",
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
    // Kimi K2.6 é um modelo de reasoning: envia reasoning_content antes do
    // content final. Ambos são repassados como eventos distintos ao frontend.
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const readable = new ReadableStream({
      async start(controller) {
        controller.enqueue(
          encoder.encode(
            `data: ${JSON.stringify({ type: "flow_start", flow: flow.name })}\n\n`
          )
        );

        const reader = crofResponse.body!.getReader();
        let buffer = "";

        try {
          while (true) {
            // timeout por chunk — se ficar 30s sem nenhum byte, aborta
            const readPromise = reader.read();
            const timeoutPromise = new Promise<never>((_, reject) =>
              setTimeout(() => reject(new Error("chunk timeout")), 30_000)
            );

            const { done, value } = await Promise.race([readPromise, timeoutPromise]);
            if (done) break;

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";

            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed || trimmed === "data: [DONE]") continue;
              if (!trimmed.startsWith("data: ")) continue;

              try {
                const json = JSON.parse(trimmed.slice(6));
                const delta = json.choices?.[0]?.delta ?? {};

                // conteúdo final
                if (delta.content) {
                  controller.enqueue(
                    encoder.encode(
                      `data: ${JSON.stringify({ type: "text", text: delta.content })}\n\n`
                    )
                  );
                }

                // raciocínio interno (thinking) — opcional para o frontend
                if (delta.reasoning_content) {
                  controller.enqueue(
                    encoder.encode(
                      `data: ${JSON.stringify({ type: "thinking", text: delta.reasoning_content })}\n\n`
                    )
                  );
                }
              } catch {
                // ignora linhas malformadas
              }
            }
          }
        } catch (streamErr) {
          const isTimeout = String(streamErr).includes("timeout");
          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify({
                type: "error",
                message: isTimeout
                  ? "Tempo limite excedido. Tente uma mensagem mais curta."
                  : String(streamErr),
              })}\n\n`
            )
          );
        } finally {
          try { reader.cancel(); } catch { /* ignore */ }
        }

        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
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
