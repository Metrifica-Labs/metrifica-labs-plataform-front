import { createClient } from "jsr:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_TOKENS = 16000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { flow_slug, user_message, extra_context, messages: incomingMessages } = await req.json();

    const hasMessages = Array.isArray(incomingMessages) && incomingMessages.length > 0;
    if (!flow_slug || (!user_message && !hasMessages)) {
      return new Response(
        JSON.stringify({ error: "flow_slug e (user_message ou messages) são obrigatórios" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

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

    const orderedModules = flow.module_slugs
      .map((slug: string) => modules.find((m) => m.slug === slug))
      .filter(Boolean) as { slug: string; name: string; content: string }[];

    const systemPrompt = [
      "Você é o assistente operacional da Metrifica Labs.",
      "Leia os módulos de contexto abaixo e execute a solicitação do usuário rigorosamente dentro das regras e informações presentes neles.",
      "Nunca invente informações que não estejam nos módulos. Nunca ignore as restrições definidas.",
      "",
      "---",
      "",
      ...orderedModules.map((m) => `## ${m.name}\n\n${m.content}`),
    ].join("\n\n");

    type AnthropicMsg = { role: "user" | "assistant"; content: string };
    let anthropicMessages: AnthropicMsg[];

    if (hasMessages) {
      anthropicMessages = incomingMessages as AnthropicMsg[];
    } else {
      const userContent = extra_context
        ? `${user_message}\n\n**Contexto adicional:**\n${extra_context}`
        : user_message;
      anthropicMessages = [{ role: "user", content: userContent }];
    }

    const model = Deno.env.get("FLOW_LLM_MODEL") ?? "claude-opus-4-8";
    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

    const llmStream = await anthropic.messages.create({
      model,
      max_tokens: MAX_TOKENS,
      system: systemPrompt,
      messages: anthropicMessages,
      stream: true,
    }, { timeout: 115_000 });

    const encoder = new TextEncoder();

    const safeEnqueue = (controller: ReadableStreamDefaultController, data: unknown) => {
      try { controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`)); } catch { /* controller já fechado */ }
    };

    const readable = new ReadableStream({
      async start(controller) {
        safeEnqueue(controller, { type: "flow_start", flow: flow.name });

        const keepaliveId = setInterval(() => {
          try { controller.enqueue(encoder.encode(": keep-alive\n\n")); } catch { /* ignore */ }
        }, 20_000);

        try {
          for await (const event of llmStream) {
            if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
              safeEnqueue(controller, { type: "text", text: event.delta.text });
            }
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
