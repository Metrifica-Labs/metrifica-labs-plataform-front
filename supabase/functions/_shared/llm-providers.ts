import OpenAI from "npm:openai";

export interface LLMMessage {
  role: "system" | "user" | "assistant" | "tool";
  content: string | null;
  tool_calls?: ToolCall[];
  tool_call_id?: string;
}

export interface ToolCall {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
}

export interface LLMResponse {
  content: string | null;
  tool_calls?: ToolCall[];
}

const PROVIDERS: Record<string, { baseUrl: string; apiKeyEnvVar: string }> = {
  crofai: { baseUrl: "https://crof.ai/v1", apiKeyEnvVar: "CROFAI_API_KEY" },
  openai: {
    baseUrl: "https://api.openai.com/v1",
    apiKeyEnvVar: "OPENAI_API_KEY",
  },
};

const DEFAULT_MAX_TOKENS = 32768;

function getClient(provider: string): OpenAI {
  const p = PROVIDERS[provider];
  if (!p) throw new Error(`Unknown LLM provider: ${provider}`);
  return new OpenAI({
    apiKey: Deno.env.get(p.apiKeyEnvVar),
    baseURL: p.baseUrl,
  });
}

// Streaming — retorna Response SSE bruta (sem tool use)
export async function callLLMStream(
  provider: string,
  model: string,
  messages: LLMMessage[],
  maxTokens = DEFAULT_MAX_TOKENS
): Promise<Response> {
  const client = getClient(provider);

  const stream = await client.chat.completions.create(
    {
      model,
      max_tokens: maxTokens,
      stream: true,
      messages: messages as OpenAI.Chat.ChatCompletionMessageParam[],
    },
    { timeout: 120_000 }
  );

  const encoder = new TextEncoder();
  const readable = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of stream) {
          try {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify(chunk)}\n\n`));
          } catch { /* controller já fechado */ }
        }
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      } catch (err) {
        try { controller.error(err); } catch { /* ignore */ }
      }
    },
  });

  return new Response(readable, {
    headers: { "Content-Type": "text/event-stream" },
  });
}

// Non-streaming — retorna texto completo
export async function callLLMComplete(
  provider: string,
  model: string,
  messages: LLMMessage[],
  jsonMode = false
): Promise<string> {
  const client = getClient(provider);

  // OpenAI: non-streaming nativo
  if (provider === "openai") {
    const params: OpenAI.Chat.ChatCompletionCreateParamsNonStreaming = {
      model,
      max_tokens: DEFAULT_MAX_TOKENS,
      stream: false,
      messages: messages as OpenAI.Chat.ChatCompletionMessageParam[],
    };
    if (jsonMode) params.response_format = { type: "json_object" };

    const res = await client.chat.completions.create(params, { timeout: 90_000 });
    return res.choices[0]?.message?.content ?? "";
  }

  // CrofAI: streaming interno (não suporta stream:false)
  console.log(`[callLLMComplete] provider=${provider} model=${model} msgs=${messages.length}`);

  const stream = await client.chat.completions.create(
    {
      model,
      max_tokens: DEFAULT_MAX_TOKENS,
      stream: true,
      messages: messages as OpenAI.Chat.ChatCompletionMessageParam[],
    },
    { timeout: 90_000 }
  );

  let fullText = "";
  let fullReasoning = "";
  let chunkCount = 0;

  for await (const chunk of stream) {
    chunkCount++;
    // reasoning_content é campo extra do DeepSeek, não tipado no SDK
    const delta = chunk.choices[0]?.delta as Record<string, unknown>;
    if (delta.content) fullText += delta.content as string;
    if (delta.reasoning_content) fullReasoning += delta.reasoning_content as string;
  }

  console.log(`[callLLMComplete] stream done. chunks=${chunkCount} textLen=${fullText.length} reasoningLen=${fullReasoning.length}`);

  if (!fullText.trim() && fullReasoning.trim()) {
    console.log(`[callLLMComplete] content empty, falling back to reasoning_content`);
    return fullReasoning;
  }

  return fullText;
}

// Tool use via streaming — reconstrói tool_calls dos deltas
export async function callLLMWithTools(
  provider: string,
  model: string,
  messages: LLMMessage[],
  tools: unknown[],
  onThinking?: (text: string) => void
): Promise<LLMResponse> {
  const client = getClient(provider);

  const stream = await client.chat.completions.create(
    {
      model,
      max_tokens: DEFAULT_MAX_TOKENS,
      stream: true,
      messages: messages as OpenAI.Chat.ChatCompletionMessageParam[],
      tools: tools as OpenAI.Chat.ChatCompletionTool[],
      tool_choice: "auto",
    },
    { timeout: 120_000 }
  );

  let fullContent = "";
  let fullReasoning = "";
  const toolCallMap: Record<number, { id: string; name: string; arguments: string }> = {};

  for await (const chunk of stream) {
    const delta = chunk.choices[0]?.delta as Record<string, unknown>;

    if (delta.content) fullContent += delta.content as string;

    if (delta.reasoning_content) {
      const reasoning = delta.reasoning_content as string;
      fullReasoning += reasoning;
      if (onThinking) onThinking(reasoning);
    }

    if (delta.tool_calls) {
      for (const tc of delta.tool_calls as OpenAI.Chat.ChatCompletionChunk.Choice.Delta.ToolCall[]) {
        const idx = tc.index ?? 0;
        if (!toolCallMap[idx]) toolCallMap[idx] = { id: tc.id ?? "", name: "", arguments: "" };
        if (tc.id) toolCallMap[idx].id = tc.id;
        if (tc.function?.name) toolCallMap[idx].name += tc.function.name;
        if (tc.function?.arguments) toolCallMap[idx].arguments += tc.function.arguments;
      }
    }
  }

  const toolCalls = Object.values(toolCallMap)
    .filter((tc) => tc.name)
    .map((tc, i) => ({
      id: tc.id || `call_${i}`,
      type: "function" as const,
      function: { name: tc.name, arguments: tc.arguments || "{}" },
    }));

  const content = fullContent || (toolCalls.length === 0 ? fullReasoning : null);

  return {
    content,
    tool_calls: toolCalls.length > 0 ? toolCalls : undefined,
  };
}
