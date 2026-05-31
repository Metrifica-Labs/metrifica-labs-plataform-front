import { createClient } from "jsr:@supabase/supabase-js@2";
import OpenAI from "npm:openai";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Mesmo teto usado pelo run-squad (_shared/llm-providers.ts). Sem isso a crof.ai
// aplica um default baixo e o reasoning_content consome o orçamento antes do
// content — a resposta "trava" no meio do pensamento.
const MAX_TOKENS = 32768;

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

    // ── 6. Chama o LLM via SDK com streaming ───────────────────────────────
    const openai = new OpenAI({
      apiKey: Deno.env.get("CROFAI_API_KEY"),
      baseURL: "https://crof.ai/v1",
    });

    const llmStream = await openai.chat.completions.create(
      {
        model: "deepseek-v4-pro",
        stream: true,
        max_tokens: MAX_TOKENS,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
      },
      { timeout: 115_000 }
    );

    // ── 7. Retorna como SSE — captura content e reasoning_content ───────────
    const encoder = new TextEncoder();

    const safeEnqueue = (controller: ReadableStreamDefaultController, data: unknown) => {
      try { controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`)); } catch { /* controller já fechado */ }
    };

    const readable = new ReadableStream({
      async start(controller) {
        safeEnqueue(controller, { type: "flow_start", flow: flow.name });

        let hasContent = false;
        let accumulatedReasoning = "";

        const keepaliveId = setInterval(() => {
          try { controller.enqueue(encoder.encode(": keep-alive\n\n")); } catch { /* ignore */ }
        }, 20_000);

        try {
          for await (const chunk of llmStream) {
            // reasoning_content é campo extra do DeepSeek, não tipado no SDK
            const delta = chunk.choices[0]?.delta as Record<string, unknown>;

            if (delta.content) {
              hasContent = true;
              safeEnqueue(controller, { type: "text", text: delta.content });
            }

            if (delta.reasoning_content) {
              const reasoning = delta.reasoning_content as string;
              accumulatedReasoning += reasoning;
              safeEnqueue(controller, { type: "thinking", text: reasoning });
            }
          }

          if (!hasContent && accumulatedReasoning.trim()) {
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
          clearInterval(keepaliveId);
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
