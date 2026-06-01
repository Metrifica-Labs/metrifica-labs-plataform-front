import Anthropic from "npm:@anthropic-ai/sdk";

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

const DEFAULT_MAX_TOKENS = 16000;

function getClient(): Anthropic {
  return new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
}

// Convert OpenAI-style tool definitions to Anthropic format
function toAnthropicTools(tools: unknown[]): Anthropic.Tool[] {
  return (tools as { type: string; function: { name: string; description?: string; parameters: unknown } }[]).map((t) => ({
    name: t.function.name,
    description: t.function.description ?? "",
    input_schema: t.function.parameters as Anthropic.Tool["input_schema"],
  }));
}

// Convert OpenAI-style messages to Anthropic format
function toAnthropicMessages(messages: LLMMessage[]): {
  system: string;
  messages: Anthropic.MessageParam[];
} {
  let system = "";
  const anthropicMessages: Anthropic.MessageParam[] = [];

  for (const msg of messages) {
    if (msg.role === "system") {
      system += (system ? "\n\n" : "") + (msg.content ?? "");
      continue;
    }

    if (msg.role === "tool") {
      const resultBlock: Anthropic.ToolResultBlockParam = {
        type: "tool_result",
        tool_use_id: msg.tool_call_id ?? "",
        content: msg.content ?? "",
      };
      const last = anthropicMessages[anthropicMessages.length - 1];
      if (last?.role === "user" && Array.isArray(last.content)) {
        (last.content as Anthropic.ContentBlockParam[]).push(resultBlock);
      } else {
        anthropicMessages.push({ role: "user", content: [resultBlock] });
      }
      continue;
    }

    if (msg.role === "assistant") {
      if (msg.tool_calls?.length) {
        const content: Anthropic.ContentBlockParam[] = [];
        if (msg.content) {
          content.push({ type: "text", text: msg.content });
        }
        for (const tc of msg.tool_calls) {
          let input: Record<string, unknown> = {};
          try { input = JSON.parse(tc.function.arguments); } catch { /* ignore */ }
          content.push({
            type: "tool_use",
            id: tc.id,
            name: tc.function.name,
            input,
          });
        }
        anthropicMessages.push({ role: "assistant", content });
      } else {
        anthropicMessages.push({ role: "assistant", content: msg.content ?? "" });
      }
      continue;
    }

    // user role
    anthropicMessages.push({ role: "user", content: msg.content ?? "" });
  }

  return { system, messages: anthropicMessages };
}

// Streaming — retorna Response SSE em formato OpenAI-compatível (para callers existentes)
export async function callLLMStream(
  _provider: string,
  model: string,
  messages: LLMMessage[],
  maxTokens = DEFAULT_MAX_TOKENS
): Promise<Response> {
  const client = getClient();
  const { system, messages: anthropicMessages } = toAnthropicMessages(messages);

  const stream = await client.messages.create({
    model,
    max_tokens: maxTokens,
    system: system || undefined,
    messages: anthropicMessages,
    stream: true,
  }, { timeout: 120_000 });

  const encoder = new TextEncoder();
  const readable = new ReadableStream({
    async start(controller) {
      try {
        for await (const event of stream) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            const chunk = { choices: [{ delta: { content: event.delta.text } }] };
            try { controller.enqueue(encoder.encode(`data: ${JSON.stringify(chunk)}\n\n`)); } catch { /* fechado */ }
          }
        }
        try {
          controller.enqueue(encoder.encode("data: [DONE]\n\n"));
          controller.close();
        } catch { /* ignore */ }
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
  _provider: string,
  model: string,
  messages: LLMMessage[],
  _jsonMode = false
): Promise<string> {
  const client = getClient();
  const { system, messages: anthropicMessages } = toAnthropicMessages(messages);

  const response = await client.messages.create({
    model,
    max_tokens: DEFAULT_MAX_TOKENS,
    system: system || undefined,
    messages: anthropicMessages,
  }, { timeout: 90_000 });

  const textBlock = response.content.find((b) => b.type === "text");
  return textBlock?.type === "text" ? textBlock.text : "";
}

// Tool use — non-streaming (Anthropic lida nativamente)
export async function callLLMWithTools(
  _provider: string,
  model: string,
  messages: LLMMessage[],
  tools: unknown[],
  _onThinking?: (text: string) => void
): Promise<LLMResponse> {
  const client = getClient();
  const { system, messages: anthropicMessages } = toAnthropicMessages(messages);
  const anthropicTools = toAnthropicTools(tools);

  const response = await client.messages.create({
    model,
    max_tokens: DEFAULT_MAX_TOKENS,
    system: system || undefined,
    messages: anthropicMessages,
    tools: anthropicTools.length > 0 ? anthropicTools : undefined,
    tool_choice: anthropicTools.length > 0 ? { type: "auto" } : undefined,
  }, { timeout: 120_000 });

  let content: string | null = null;
  const toolCalls: ToolCall[] = [];

  for (const block of response.content) {
    if (block.type === "text") {
      content = (content ?? "") + block.text;
    } else if (block.type === "tool_use") {
      toolCalls.push({
        id: block.id,
        type: "function",
        function: {
          name: block.name,
          arguments: JSON.stringify(block.input),
        },
      });
    }
  }

  return {
    content,
    tool_calls: toolCalls.length > 0 ? toolCalls : undefined,
  };
}
