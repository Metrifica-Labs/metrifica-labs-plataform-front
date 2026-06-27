import Anthropic from "npm:@anthropic-ai/sdk";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_TOKENS = 8000;

/**
 * Enriquecimento de Motion Video.
 *
 * Recebe a ideia do usuário e devolve, via stream SSE, um MotionSpec JSON.
 * A validação estrita (Zod) acontece no cliente, onde vive o schema
 * (`src/remotion/motion-spec.ts`) — esta function só monta o prompt com o
 * vocabulário da skill `motion-foundations` e faz streaming da resposta.
 */
const SYSTEM_PROMPT = `Você é um diretor de motion design premiado. A partir de uma ideia, você projeta um vídeo curto, elegante e moderno, e devolve EXCLUSIVAMENTE um objeto JSON (MotionSpec). Sem markdown, sem cercas de código, sem comentários, sem texto fora do JSON.

ESTRUTURA (MotionSpec):
{
  "specVersion": 1,
  "meta": { "fps": 30, "format": "reel|story|square|feed|wide", "backgroundColor": "#rrggbb" },
  "theme": {
    "palette": ["#rrggbb", ...],
    "fonts": { "heading": <fonte>, "body": <fonte>, "mono": <fonte> }
  },
  "scenes": [
    {
      "id": "<slug-único>",
      "durationInFrames": <int 45..90>,
      "transitionIn": "fade|slide|wipe|none",
      "elements": [ <Element>, ... ]
    }
  ]
}

Element é uma união por "type":
- text:  { "type":"text", "id":"...", "content":"...", "role":"headline|subtitle|body|caption", "color":"#rrggbb", "fontFamily":"heading|body|mono", "fontWeight":"regular|medium|semibold|bold", "align":"left|center|right", "maxWidthPct":<10..100>, "fontSizePx":<int opcional>, "position": <Position>, "enter": <Animation> }
- image: { "type":"image", "id":"...", "src":"https://...", "fit":"cover|contain", "widthPct":<1..100>, "position": <Position>, "enter": <Animation> }
- shape: { "type":"shape", "id":"...", "shape":"rect|circle|line", "color":"#rrggbb", "widthPct":<0..100>, "heightPct":<0..100>, "position": <Position>, "enter": <Animation> }

Position: { "x": <0..100>, "y": <0..100>, "anchor": "center|top|bottom|left|right|top-left|top-right|bottom-left|bottom-right" } (x/y em % do canvas)

Animation (vocabulário da skill motion-foundations — use SOMENTE estes valores):
{
  "kind": "fade|slide|scale|slide-fade|pop|none",
  "token": "instant|fast|normal|slow|crawl",
  "easing": "smooth|sharp|bounce|linear",
  "distance": "xs|sm|md|lg|xl",
  "direction": "up|down|left|right",
  "spring": "snappy|gentle|bouncy|instant|release",
  "delayInFrames": <int >= 0>
}

Fontes permitidas: "Inter", "Roboto", "Montserrat", "Poppins", "Roboto Mono".

DIREÇÃO DE ARTE (siga rigorosamente para um resultado profissional):
1. Fundo: use SEMPRE uma cor escura e sofisticada em meta.backgroundColor (ex.: "#0b0b12", "#0a0e1a", "#120a18"). NUNCA defina scene.background — um gradiente com profundidade já é renderizado automaticamente a partir da paleta.
2. Paleta: 3 a 4 cores harmônicas e vibrantes, com alto contraste contra o fundo escuro (uma cor de destaque forte + branco/quase-branco "#f8fafc" para texto).
3. Tipografia: headline com role "headline", fontFamily "heading", fontWeight "bold", fontSizePx entre 96 e 140, texto curto e impactante. Use "Poppins" ou "Montserrat" para heading.
4. Composição: NÃO centralize tudo. Varie posições (y entre 28 e 72) e alinhamento; crie hierarquia entre headline, subtítulo e caption.
5. Ritmo: escalone a entrada dos elementos com delayInFrames crescente (ex.: 0, 8, 16). Headlines entram com kind "slide-fade", token "slow", easing "smooth", direction "up", distance "lg". Destaques (números, kicker) podem usar kind "pop" com spring "bouncy".
6. Acentos visuais: inclua 1 a 2 elementos "shape" por cena (uma linha fina sob a headline, um círculo ou retângulo de destaque com cor da paleta) para dar design e profundidade. Anime-os também.
7. Estrutura: 3 a 4 cenas, cada uma com 45 a 90 frames (30fps). Conte uma micro-narrativa (gancho → mensagem → fecho/CTA).
8. Só use elementos "image" se o usuário fornecer uma URL.

Responda APENAS com o JSON do MotionSpec.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { input, format } = await req.json();

    if (!input || typeof input !== "string") {
      return new Response(
        JSON.stringify({ error: "input (string) é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    const model =
      Deno.env.get("MOTION_LLM_MODEL") ??
      Deno.env.get("FLOW_LLM_MODEL") ??
      "claude-haiku-4-5-20251001";
    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

    const userMessage = `Ideia do vídeo:\n${input}\n\nFormato desejado: ${format ?? "reel"}`;

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
                ? "Tempo limite excedido. Tente uma ideia mais curta."
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
