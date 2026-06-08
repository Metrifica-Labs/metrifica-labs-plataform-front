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
    const { agent_slug, messages, persona_context } = await req.json();

    if (!agent_slug || !Array.isArray(messages)) {
      return new Response(
        JSON.stringify({ error: "agent_slug e messages são obrigatórios" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: agent, error: agentError } = await supabase
      .from("agent_definitions")
      .select("slug, name, system_prompt, llm_model")
      .eq("slug", agent_slug)
      .single();

    if (agentError || !agent) {
      return new Response(
        JSON.stringify({ error: `Agente '${agent_slug}' não encontrado` }),
        { status: 404, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const model = agent.llm_model ?? Deno.env.get("FLOW_LLM_MODEL") ?? "claude-haiku-4-5-20251001";
    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

    type Msg = { role: "user" | "assistant"; content: string };
    const anthropicMessages: Msg[] = (messages as Msg[]).filter(
      (m) => m.role === "user" || m.role === "assistant"
    );

    const systemPrompt = persona_context
      ? `PERFIL DO PERSONAGEM/AVATAR:\n${persona_context}\n\n---\n\n${agent.system_prompt}`
      : agent.system_prompt;

    const llmStream = await anthropic.messages.create({
      model,
      max_tokens: MAX_TOKENS,
      system: systemPrompt,
      messages: anthropicMessages,
      stream: true,
    }, { timeout: 115_000 });

    const encoder = new TextEncoder();

    const readable = new ReadableStream({
      async start(controller) {
        const enqueue = (data: unknown) => {
          try { controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`)); } catch { /* closed */ }
        };

        const keepalive = setInterval(() => {
          try { controller.enqueue(encoder.encode(": keep-alive\n\n")); } catch { /* ignore */ }
        }, 20_000);

        try {
          for await (const event of llmStream) {
            if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
              enqueue({ type: "text", text: event.delta.text });
            }
          }
        } catch (err) {
          const msg = String(err);
          enqueue({
            type: "error",
            message: msg.includes("timeout") || msg.includes("Abort")
              ? "Tempo limite excedido. Tente uma mensagem mais curta."
              : msg,
          });
        } finally {
          clearInterval(keepalive);
          try {
            controller.enqueue(encoder.encode("data: [DONE]\n\n"));
            controller.close();
          } catch { /* ignore */ }
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
