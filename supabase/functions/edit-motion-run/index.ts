import Anthropic from "npm:@anthropic-ai/sdk";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_TOKENS = 8000;

/**
 * Edição de Motion Video (Fase 5).
 *
 * Recebe o MotionSpec atual + uma instrução em linguagem natural e devolve, via
 * stream SSE, o MotionSpec COMPLETO revisado. A validação estrita (Zod) acontece
 * no cliente, onde vive o schema (`src/remotion/motion-spec.ts`) — esta function
 * só reaplica a direção de arte e faz streaming da resposta.
 *
 * Optou-se por devolver o spec inteiro (em vez de um patch RFC6902) porque o Zod
 * é client-side e o modelo lida melhor com "edite no lugar" do que com ponteiros.
 */
const SYSTEM_PROMPT = `Você é um diretor de motion design editando um vídeo existente. Recebe um MotionSpec (JSON) e uma instrução do usuário. Você devolve EXCLUSIVAMENTE o MotionSpec COMPLETO já com a alteração aplicada. Sem markdown, sem cercas de código, sem comentários, sem texto fora do JSON.

REGRAS DE EDIÇÃO (críticas):
1. Aplique SOMENTE o que o usuário pediu. Todo o resto do spec deve permanecer idêntico (mesmos ids, posições, durações, cores, animações que não foram citadas).
2. Preserve a estrutura e os ids existentes sempre que possível — não recrie cenas/elementos do zero se a instrução não exigir.
3. Mantenha o JSON válido e fiel ao mesmo vocabulário (os enums de animação: kind fade|slide|scale|slide-fade|pop|none; token instant|fast|normal|slow|crawl; easing smooth|sharp|bounce|linear; distance xs|sm|md|lg|xl; direction up|down|left|right; spring snappy|gentle|bouncy|instant|release).
4. Fontes permitidas: "Inter", "Roboto", "Montserrat", "Poppins", "Roboto Mono".
5. NUNCA defina scene.background; use meta.backgroundColor escuro. Mantenha "specVersion": 1.

Responda APENAS com o JSON do MotionSpec completo e revisado.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { instruction, currentSpec } = await req.json();

    if (!instruction || typeof instruction !== "string") {
      return new Response(
        JSON.stringify({ error: "instruction (string) é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }
    if (!currentSpec || typeof currentSpec !== "object") {
      return new Response(
        JSON.stringify({ error: "currentSpec (objeto) é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    const model =
      Deno.env.get("MOTION_LLM_MODEL") ??
      Deno.env.get("FLOW_LLM_MODEL") ??
      "claude-haiku-4-5-20251001";
    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

    const userMessage = `MotionSpec atual:\n${JSON.stringify(currentSpec)}\n\nInstrução de edição:\n${instruction}`;

    const llmStream = await anthropic.messages.create(
      {
        model,
        max_tokens: MAX_TOKENS,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: userMessage }],
        stream: true,
      },
      { timeout: 115_000 },
    );

    const encoder = new TextEncoder();

    const readable = new ReadableStream({
      async start(controller) {
        const enqueue = (data: unknown) => {
          try {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`));
          } catch {
            /* closed */
          }
        };

        const keepalive = setInterval(() => {
          try {
            controller.enqueue(encoder.encode(": keep-alive\n\n"));
          } catch {
            /* ignore */
          }
        }, 20_000);

        try {
          for await (const event of llmStream) {
            if (
              event.type === "content_block_delta" &&
              event.delta.type === "text_delta"
            ) {
              enqueue({ type: "text", text: event.delta.text });
            }
          }
        } catch (err) {
          const msg = String(err);
          enqueue({
            type: "error",
            message:
              msg.includes("timeout") || msg.includes("Abort")
                ? "Tempo limite excedido. Tente uma instrução mais simples."
                : msg,
          });
        } finally {
          clearInterval(keepalive);
          try {
            controller.enqueue(encoder.encode("data: [DONE]\n\n"));
            controller.close();
          } catch {
            /* ignore */
          }
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
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  }
});
