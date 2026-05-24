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

// Streaming — retorna Response SSE bruta (sem tool use)
// Timeout de 60s na conexão inicial; body streaming é responsabilidade do caller
export async function callLLMStream(
  provider: string,
  model: string,
  messages: LLMMessage[],
  maxTokens = 8192
): Promise<Response> {
  const p = PROVIDERS[provider];
  if (!p) throw new Error(`Unknown LLM provider: ${provider}`);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 120_000);

  try {
    const response = await fetch(`${p.baseUrl}/chat/completions`, {
      method: "POST",
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${Deno.env.get(p.apiKeyEnvVar)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model, max_tokens: maxTokens, stream: true, messages }),
    });
    clearTimeout(timer); // conexão estabelecida — libera o timer
    return response;
  } catch (err) {
    clearTimeout(timer);
    throw err;
  }
}

// Non-streaming simples — retorna texto (para decisões do orchestrator)
// CrofAI não suporta stream:false, então internamente faz streaming e coleta os chunks
export async function callLLMComplete(
  provider: string,
  model: string,
  messages: LLMMessage[],
  jsonMode = false
): Promise<string> {
  const p = PROVIDERS[provider];
  if (!p) throw new Error(`Unknown LLM provider: ${provider}`);

  // OpenAI: non-streaming nativo com AbortController controlado
  if (provider === "openai") {
    const body: Record<string, unknown> = {
      model,
      max_tokens: 4096,
      stream: false,
      messages,
    };
    if (jsonMode) body["response_format"] = { type: "json_object" };

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 90_000);

    try {
      const res = await fetch(`${p.baseUrl}/chat/completions`, {
        method: "POST",
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${Deno.env.get(p.apiKeyEnvVar)}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      clearTimeout(timer);

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`LLM ${provider} error ${res.status}: ${errText}`);
      }

      const data = await res.json();
      return data.choices?.[0]?.message?.content ?? "";
    } finally {
      clearTimeout(timer);
    }
  }

  // CrofAI e outros: streaming interno — sem AbortSignal.timeout (causa event loop leak)
  console.log(`[callLLMComplete] provider=${provider} model=${model} msgs=${messages.length}`);

  const res = await fetch(`${p.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get(p.apiKeyEnvVar)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model, max_tokens: 4096, stream: true, messages }),
  });

  if (!res.ok) {
    const errText = await res.text();
    console.error(`[callLLMComplete] ${provider} ${res.status}: ${errText}`);
    throw new Error(`LLM ${provider} error ${res.status}: ${errText}`);
  }

  if (!res.body) throw new Error(`LLM ${provider}: no response body`);

  const decoder = new TextDecoder();
  const reader = res.body.getReader();
  let buffer = "";
  let fullText = "";
  let fullReasoning = "";

  const processLine = (line: string) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed === "data: [DONE]") return;
    if (!trimmed.startsWith("data: ")) return;
    try {
      const json = JSON.parse(trimmed.slice(6));
      const delta = json.choices?.[0]?.delta ?? {};
      if (delta.content) fullText += delta.content;
      // Deepseek reasoning models put thinking in reasoning_content; collect as fallback
      if (delta.reasoning_content) fullReasoning += delta.reasoning_content;
    } catch { /* malformed */ }
  };

  let chunkCount = 0;
  try {
    while (true) {
      const { done, value } = await Promise.race([
        reader.read(),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("chunk timeout")), 60_000)
        ),
      ]);
      if (done) {
        console.log(`[callLLMComplete] stream done. chunks=${chunkCount} textLen=${fullText.length} reasoningLen=${fullReasoning.length}`);
        break;
      }

      chunkCount++;
      const raw = decoder.decode(value, { stream: true });
      if (chunkCount <= 3) console.log(`[callLLMComplete] chunk#${chunkCount}: ${raw.slice(0, 200)}`);
      buffer += raw;
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) processLine(line);
    }

    // Flush remaining buffer (last chunk may have no trailing newline)
    if (buffer.trim()) processLine(buffer);
  } catch (err) {
    console.log(`[callLLMComplete] stream error after ${chunkCount} chunks: ${err}`);
    throw err;
  } finally {
    try { reader.cancel(); } catch { /* ignore */ }
  }

  // If content is empty but reasoning has the JSON (Deepseek R1-style), use reasoning
  if (!fullText.trim() && fullReasoning.trim()) {
    console.log(`[callLLMComplete] content empty, falling back to reasoning_content`);
    return fullReasoning;
  }

  return fullText;
}

// Tool use via streaming — reconstrói tool_calls dos deltas SSE
// CrofAI não suporta stream:false; usamos stream:true e reconstruímos os tool_calls
export async function callLLMWithTools(
  provider: string,
  model: string,
  messages: LLMMessage[],
  tools: unknown[],
  onThinking?: (text: string) => void
): Promise<LLMResponse> {
  const p = PROVIDERS[provider];
  if (!p) throw new Error(`Unknown LLM provider: ${provider}`);

  const res = await fetch(`${p.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get(p.apiKeyEnvVar)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model, max_tokens: 8192, stream: true, messages, tools, tool_choice: "auto" }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`LLM ${provider} error ${res.status}: ${errText}`);
  }
  if (!res.body) throw new Error(`LLM ${provider}: no response body`);

  const decoder = new TextDecoder();
  const reader = res.body.getReader();
  let buffer = "";
  let fullContent = "";
  let fullReasoning = "";
  // Reconstruct tool_calls: map from index → { id, name, arguments }
  const toolCallMap: Record<number, { id: string; name: string; arguments: string }> = {};

  try {
    outer: while (true) {
      const { done, value } = await Promise.race([
        reader.read(),
        new Promise<never>((_, reject) => setTimeout(() => reject(new Error("tool chunk timeout")), 120_000)),
      ]);
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed === "data: [DONE]") continue;
        if (trimmed.startsWith("event:")) continue;
        if (!trimmed.startsWith("data: ")) continue;
        try {
          const json = JSON.parse(trimmed.slice(6));
          if (json.error) { break outer; }
          const delta = json.choices?.[0]?.delta ?? {};
          if (delta.content) fullContent += delta.content;
          if (delta.reasoning_content) {
            fullReasoning += delta.reasoning_content;
            if (onThinking) onThinking(delta.reasoning_content);
          }
          // Reconstruct streaming tool_calls
          if (delta.tool_calls) {
            for (const tc of delta.tool_calls) {
              const idx: number = tc.index ?? 0;
              if (!toolCallMap[idx]) toolCallMap[idx] = { id: tc.id ?? "", name: "", arguments: "" };
              if (tc.id) toolCallMap[idx].id = tc.id;
              if (tc.function?.name) toolCallMap[idx].name += tc.function.name;
              if (tc.function?.arguments) toolCallMap[idx].arguments += tc.function.arguments;
            }
          }
        } catch { /* ignore malformed */ }
      }
    }
    if (buffer.trim()) {
      const t = buffer.trim();
      if (t.startsWith("data: ") && t !== "data: [DONE]") {
        try {
          const json = JSON.parse(t.slice(6));
          const delta = json.choices?.[0]?.delta ?? {};
          if (delta.content) fullContent += delta.content;
        } catch { /* ignore */ }
      }
    }
  } finally {
    try { reader.cancel(); } catch { /* ignore */ }
  }

  const toolCalls = Object.values(toolCallMap)
    .filter((tc) => tc.name)
    .map((tc, i) => ({
      id: tc.id || `call_${i}`,
      type: "function" as const,
      function: { name: tc.name, arguments: tc.arguments || "{}" },
    }));

  // Use reasoning as content fallback for non-tool responses
  const content = fullContent || (toolCalls.length === 0 ? fullReasoning : null);

  return {
    content,
    tool_calls: toolCalls.length > 0 ? toolCalls : undefined,
  };
}
