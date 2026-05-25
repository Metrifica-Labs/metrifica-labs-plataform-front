import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  callLLMComplete,
  callLLMStream,
  callLLMWithTools,
  LLMMessage,
  ToolCall,
} from "../_shared/llm-providers.ts";
import { executeTool } from "../_shared/tool-executor.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_ITERATIONS = 12;
const MAX_TOOL_LOOPS = 15;
const MAX_AGENT_RETRIES = 2;
const AGENT_CHUNK_TIMEOUT_MS = 45_000;
const SUPERVISOR_TIMEOUT_MS = 12_000;

interface AgentDefinition {
  slug: string;
  name: string;
  role: string;
  system_prompt: string;
  llm_provider: string;
  llm_model: string;
  tools: unknown[];
}

interface OrchestratorDecision {
  action: "call_agent" | "done";
  agent_slug?: string;
  reasoning: string;
  input_for_agent?: string;
}

interface SupervisorDecision {
  action: "accept" | "retry_agent" | "call_agent" | "abort";
  agent_slug?: string;
  reasoning: string;
  input_for_agent?: string;
}

// Extrai JSON de respostas que podem vir com markdown (```json...```) ou texto extra
function extractJson(raw: string): string {
  const trimmed = raw.trim();

  // Tenta parse direto primeiro
  try {
    JSON.parse(trimmed);
    return trimmed;
  } catch { /* continua */ }

  // Remove blocos de markdown ```json ... ``` ou ``` ... ```
  const mdMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (mdMatch) {
    try {
      JSON.parse(mdMatch[1].trim());
      return mdMatch[1].trim();
    } catch { /* continua */ }
  }

  // Extrai o primeiro objeto JSON { ... } encontrado no texto
  const braceStart = trimmed.indexOf("{");
  const braceEnd = trimmed.lastIndexOf("}");
  if (braceStart !== -1 && braceEnd > braceStart) {
    const candidate = trimmed.slice(braceStart, braceEnd + 1);
    try {
      JSON.parse(candidate);
      return candidate;
    } catch { /* continua */ }
  }

  // Nenhuma extração funcionou — retorna o original pra mostrar no erro
  return trimmed;
}

function buildOrchestratorMessages(
  orchestratorPrompt: string,
  agentDefs: AgentDefinition[],
  history: { agent: string; output: string }[],
  userMessage: string
): LLMMessage[] {
  const slugList = agentDefs.map((a) => `${a.slug} (${a.name})`).join(", ");

  const historyBlock = history.length === 0
    ? "Nenhum agente executado ainda."
    : history.map((h, i) => {
        const preview = h.output.slice(0, 600);
        const truncated = h.output.length > 600 ? "..." : "";
        return `[${i + 1}] ${h.agent}:\n${preview}${truncated}`;
      }).join("\n\n");

  const systemContent = `${orchestratorPrompt}

Agentes disponíveis: ${slugList}

Histórico do que foi produzido até agora:
${historyBlock}

TAREFA ORIGINAL: ${userMessage}

Analise o histórico. Responda APENAS com o slug do próximo agente a chamar, ou "done" se tudo estiver completo e o QA aprovou. Nenhum outro texto.`;

  return [
    { role: "system", content: systemContent },
    { role: "user", content: "Qual o próximo agente?" },
  ];
}

function looksInvalidAgentOutput(output: string): boolean {
  const clean = output.trim();
  if (clean.length < 80) return true;

  const lower = clean.toLowerCase();
  return (
    lower.includes("timeout atingido") ||
    lower.includes("resposta interrompida") ||
    lower.includes("resposta truncada") ||
    lower.includes("chunk timeout") ||
    lower.includes("limite de tool calls atingido") ||
    lower.includes("erro ao executar") ||
    lower.includes("conexão com llm falhou") ||
    lower.includes("http 5") ||
    lower.includes("http 4")
  );
}

function buildAgentAcceptanceRules(agent: AgentDefinition): string {
  const slug = agent.slug.toLowerCase();
  const role = `${agent.name} ${agent.role} ${agent.system_prompt}`.toLowerCase();

  if (slug.includes("dev") || role.includes("desenvolvedor") || role.includes("developer")) {
    return `
Regras obrigatórias para aceitar Developer:
- NÃO aceite se ele só criou o repositório.
- Só aceite se houver evidência de github_push_files bem-sucedido.
- O commit precisa conter arquivos reais de código, não apenas README.
- O commit precisa conter testes ou workflow de CI quando a tarefa pedir software completo.
- Se faltou código, mande retry_agent com instrução para continuar após criar o repo e commitar todos os arquivos.`;
  }

  if (slug.includes("qa") || role.includes("qa") || role.includes("teste")) {
    return `
Regras obrigatórias para aceitar QA:
- NÃO aceite QA que apenas diga que está tudo certo sem evidência.
- Só aceite se houver uso ou resultado de github_get_actions_status ou equivalente.
- Se não houver Actions configurado, QA deve reportar falha/risco, não aprovação.
- Se Actions ainda estiver rodando ou não existir, redirecione para Developer corrigir workflow/testes ou mande retry_agent para QA buscar logs/status.`;
  }

  return `
Regra geral:
- Não aceite resposta vazia, genérica, truncada, erro de ferramenta ou saída que não avance a tarefa.`;
}

function deterministicSupervisorDecision(
  agentDefs: AgentDefinition[],
  agent: AgentDefinition,
  agentOutput: string,
  runtimeError: string | null
): SupervisorDecision | null {
  const slug = agent.slug.toLowerCase();
  const role = `${agent.name} ${agent.role} ${agent.system_prompt}`.toLowerCase();
  const output = agentOutput.toLowerCase();
  const isDeveloper = slug.includes("dev") || role.includes("desenvolvedor") || role.includes("developer");
  const isQa = slug.includes("qa") || role.includes("qa") || role.includes("teste");

  if (runtimeError) {
    return {
      action: "retry_agent",
      agent_slug: agent.slug,
      reasoning: "Agente falhou em runtime; repetir com instrução de recuperação.",
      input_for_agent: `A execução anterior falhou: ${runtimeError}\nRetome a tarefa do ponto em que parou e entregue uma resposta completa.`,
    };
  }

  if (looksInvalidAgentOutput(agentOutput)) {
    return {
      action: "retry_agent",
      agent_slug: agent.slug,
      reasoning: "Resposta do agente parece vazia, truncada, interrompida ou inválida.",
      input_for_agent: `A resposta anterior foi considerada inválida ou interrompida. Refaça a etapa completa, de forma objetiva, sem depender do texto parcial anterior.\n\nResposta parcial rejeitada:\n${agentOutput.slice(0, 3000)}`,
    };
  }

  if (isDeveloper) {
    if (!output.includes("tool_result github_push_files")) {
      return {
        action: "retry_agent",
        agent_slug: agent.slug,
        reasoning: "Developer não commitou arquivos de código; criar repo não é entrega suficiente.",
        input_for_agent: "Você criou ou preparou o repositório, mas ainda falta desenvolver. Continue agora: gere os arquivos reais do projeto, inclua testes e workflow de CI, e use github_push_files para commitar tudo. Não pare após criar o repo.",
      };
    }

    if (output.includes("tool_result github_push_files: erro") || output.includes("tool_result github_push_files: tool 'github_push_files' não implementada")) {
      return {
        action: "retry_agent",
        agent_slug: agent.slug,
        reasoning: "Developer tentou commitar, mas github_push_files falhou.",
        input_for_agent: "A chamada github_push_files falhou. Corrija os argumentos e tente novamente. Use o repo já criado se existir. Commits devem incluir código, testes e workflow de CI.",
      };
    }

    const hasCodeFile = /\s-\s.+\.(ts|tsx|js|jsx|py|dart|go|rs|java|kt|swift|cs|php|rb|html|css|sql)/i.test(agentOutput);
    const hasTestOrCi = /\s-\s(.+test\.|.+spec\.|test\/|tests\/|__tests__\/|\.github\/workflows\/)/i.test(agentOutput);

    if (!hasCodeFile) {
      return {
        action: "retry_agent",
        agent_slug: agent.slug,
        reasoning: "Commit do Developer não evidencia arquivos reais de código.",
        input_for_agent: "O commit anterior não mostrou arquivos reais de código. Use github_push_files novamente incluindo implementação completa, não apenas documentação.",
      };
    }

    if (!hasTestOrCi) {
      return {
        action: "retry_agent",
        agent_slug: agent.slug,
        reasoning: "Commit do Developer não evidencia testes ou workflow de CI.",
        input_for_agent: "Adicione testes automatizados e/ou .github/workflows/test.yml e faça novo commit com github_push_files.",
      };
    }

    return {
      action: "accept",
      reasoning: "Developer commitou arquivos de código e evidência de testes/CI.",
    };
  }

  if (isQa) {
    if (!output.includes("tool_result github_get_actions_status")) {
      return {
        action: "retry_agent",
        agent_slug: agent.slug,
        reasoning: "QA não consultou status real dos testes/Actions.",
        input_for_agent: "Você precisa verificar evidência real. Use github_get_actions_status no repositório entregue pelo Developer. Se não houver Actions ou testes, reporte falha, não aprovação.",
      };
    }

    if (output.includes("actions: success")) {
      return {
        action: "accept",
        reasoning: "QA verificou GitHub Actions com sucesso.",
      };
    }

    if (output.includes("actions ainda rodando")) {
      return {
        action: "retry_agent",
        agent_slug: agent.slug,
        reasoning: "GitHub Actions ainda estava rodando; QA deve verificar novamente antes de aprovar.",
        input_for_agent: "Aguarde e consulte github_get_actions_status novamente. Não aprove sem conclusão de teste.",
      };
    }

    if (output.includes("actions: failure") || output.includes("nenhum actions run encontrado")) {
      const developer = agentDefs.find((a) => {
        const candidate = `${a.slug} ${a.name} ${a.role}`.toLowerCase();
        return candidate.includes("dev") || candidate.includes("developer") || candidate.includes("desenvolvedor");
      });

      return {
        action: "call_agent",
        agent_slug: developer?.slug ?? agent.slug,
        reasoning: "QA encontrou falha ou ausência de GitHub Actions; Developer precisa corrigir código/testes/workflow.",
        input_for_agent: `QA rejeitou a entrega. Corrija o projeto com base nesta evidência e faça novo commit com github_push_files:\n\n${agentOutput}`,
      };
    }
  }

  return null;
}

function buildSupervisorMessages(
  orchestratorPrompt: string,
  agentDefs: AgentDefinition[],
  history: { agent: string; output: string }[],
  userMessage: string,
  agent: AgentDefinition,
  agentInput: string,
  agentOutput: string,
  runtimeError: string | null,
  retryCount: number
): LLMMessage[] {
  const agents = agentDefs.map((a) => `${a.slug} (${a.name}: ${a.role})`).join(", ");
  const historyBlock = history.length === 0
    ? "Nenhum agente aceito ainda."
    : history.map((h, i) => `[${i + 1}] ${h.agent}:\n${h.output.slice(0, 1200)}`).join("\n\n---\n\n");

  const systemContent = `${orchestratorPrompt}

Você agora atua como SUPERVISOR/REVIEWER da execução multiagente.
Sua função é validar se o último agente entregou uma resposta utilizável para a tarefa original.

Agentes disponíveis: ${agents}

Histórico já aceito:
${historyBlock}

Tarefa original:
${userMessage}

Último agente executado: ${agent.slug} (${agent.name})
Tentativas anteriores deste agente: ${retryCount}

Input enviado ao agente:
${agentInput.slice(0, 3000)}

Erro de execução, se houver:
${runtimeError ?? "Nenhum erro runtime reportado."}

Output do agente:
${agentOutput.slice(0, 5000)}

Critérios específicos deste agente:
${buildAgentAcceptanceRules(agent)}

Decida uma ação:
- accept: saída é suficiente; o orquestrador pode seguir.
- retry_agent: o mesmo agente deve tentar novamente com instruções corrigidas.
- call_agent: outro agente deve assumir a recuperação.
- abort: não há recuperação segura.

Responda APENAS JSON válido neste formato:
{"action":"accept|retry_agent|call_agent|abort","agent_slug":"slug-opcional","reasoning":"motivo curto","input_for_agent":"instrução opcional para recuperação"}`;

  return [
    { role: "system", content: systemContent },
    { role: "user", content: "Revise a última execução e decida a próxima ação." },
  ];
}

async function reviewAgentOutput(
  squad: { orchestrator_provider: string; orchestrator_model: string; orchestrator_prompt: string },
  agentDefs: AgentDefinition[],
  history: { agent: string; output: string }[],
  userMessage: string,
  agent: AgentDefinition,
  agentInput: string,
  agentOutput: string,
  runtimeError: string | null,
  retryCount: number,
  emit: (obj: unknown) => void
): Promise<SupervisorDecision> {
  const heuristicInvalid = runtimeError !== null || looksInvalidAgentOutput(agentOutput);
  emit({
    type: "supervisor_review",
    agent_slug: agent.slug,
    invalid_hint: heuristicInvalid,
  });

  const deterministicDecision = deterministicSupervisorDecision(agentDefs, agent, agentOutput, runtimeError);
  if (deterministicDecision) return deterministicDecision;

  if (!heuristicInvalid) {
    return { action: "accept", reasoning: "Saída passou nas validações rápidas do supervisor." };
  }

  try {
    const raw = await Promise.race([
      callLLMComplete(
        squad.orchestrator_provider,
        squad.orchestrator_model,
        buildSupervisorMessages(
          squad.orchestrator_prompt,
          agentDefs,
          history,
          userMessage,
          agent,
          agentInput,
          agentOutput,
          runtimeError,
          retryCount
        ),
        true
      ),
      new Promise<string>((resolve) => setTimeout(() => resolve(""), SUPERVISOR_TIMEOUT_MS)),
    ]);

    if (!raw.trim()) {
      return heuristicInvalid
        ? { action: "retry_agent", agent_slug: agent.slug, reasoning: "Supervisor sem resposta; fallback por heurística inválida." }
        : { action: "accept", reasoning: "Supervisor sem resposta; saída parece válida pela heurística." };
    }

    const parsed = JSON.parse(extractJson(raw)) as SupervisorDecision;
    if (!["accept", "retry_agent", "call_agent", "abort"].includes(parsed.action)) {
      throw new Error(`Ação inválida do supervisor: ${parsed.action}`);
    }
    return parsed;
  } catch (err) {
    return heuristicInvalid
      ? { action: "retry_agent", agent_slug: agent.slug, reasoning: `Supervisor falhou (${err}); fallback retry.` }
      : { action: "accept", reasoning: `Supervisor falhou (${err}); fallback accept.` };
  }
}

const AGENT_TIMEOUT_MS = 5 * 60_000; // 5 minutos por agente

// Executa um agente com tool use (loop interno de tool calls)
async function runAgentWithTools(
  agent: AgentDefinition,
  input: string,
  emit: (obj: unknown) => void
): Promise<string> {
  const messages: LLMMessage[] = [
    { role: "system", content: agent.system_prompt },
    { role: "user", content: input },
  ];

  const onThinking = (text: string) =>
    emit({ type: "thinking", text, agent_slug: agent.slug });

  const deadline = Date.now() + AGENT_TIMEOUT_MS;
  const toolTranscript: string[] = [];

  for (let loop = 0; loop < MAX_TOOL_LOOPS; loop++) {
    if (Date.now() > deadline) {
      emit({ type: "text", text: "\n\n⚠️ Tempo limite de 5 minutos atingido.", agent_slug: agent.slug });
      return "Timeout atingido.";
    }

    const heartbeat = setInterval(() => emit({ type: "heartbeat" }), 20_000);
    let response;
    try {
      response = await callLLMWithTools(
        agent.llm_provider,
        agent.llm_model,
        messages,
        agent.tools,
        onThinking
      );
    } finally {
      clearInterval(heartbeat);
    }

    if (response.tool_calls && response.tool_calls.length > 0) {
      messages.push({
        role: "assistant",
        content: response.content,
        tool_calls: response.tool_calls,
      });

      for (const tc of response.tool_calls as ToolCall[]) {
        const toolName = tc.function.name;
        let toolArgs: Record<string, unknown> = {};
        try {
          toolArgs = JSON.parse(tc.function.arguments);
        } catch {
          toolArgs = {};
        }

        emit({ type: "tool_call", tool: toolName, args: toolArgs, agent_slug: agent.slug });
        toolTranscript.push(`TOOL_CALL ${toolName}: ${JSON.stringify(toolArgs).slice(0, 2000)}`);

        let result: string;
        try {
          result = await executeTool(toolName, toolArgs);
        } catch (err) {
          result = `Erro ao executar ${toolName}: ${err}`;
        }

        emit({ type: "tool_result", tool: toolName, result, agent_slug: agent.slug });
        toolTranscript.push(`TOOL_RESULT ${toolName}: ${result.slice(0, 4000)}`);

        messages.push({ role: "tool", content: result, tool_call_id: tc.id });
      }

      continue;
    }

    // Sem tool calls — resposta final
    let finalText = response.content ?? "";

    // Se o agente fez tool calls mas não deu resumo, pede um
    if (!finalText && messages.length > 2) {
      const heartbeat2 = setInterval(() => emit({ type: "heartbeat" }), 20_000);
      try {
        const summary = await callLLMWithTools(
          agent.llm_provider, agent.llm_model,
          [...messages, { role: "user", content: "Resuma em português o que foi implementado e entregue." }],
          [], // sem tools para o resumo
          onThinking
        );
        finalText = summary.content ?? "Trabalho concluído.";
      } catch { finalText = "Trabalho concluído."; }
      finally { clearInterval(heartbeat2); }
    }

    emit({ type: "text", text: finalText, agent_slug: agent.slug });
    if (toolTranscript.length === 0) return finalText;
    return `${finalText}\n\n# Ferramentas executadas\n${toolTranscript.join("\n\n")}`;
  }

  return "Limite de tool calls atingido.";
}

// Executa um agente em streaming (sem tools)
async function runAgentStreaming(
  agent: AgentDefinition,
  input: string,
  emit: (obj: unknown) => void
): Promise<string> {
  // Heartbeat antes do fetch — garante que Flutter recebe dados mesmo se CrofAI demorar na conexão inicial
  const heartbeat = setInterval(() => emit({ type: "heartbeat" }), 20_000);

  let llmResponse: Response;
  try {
    llmResponse = await callLLMStream(agent.llm_provider, agent.llm_model, [
      { role: "system", content: agent.system_prompt },
      { role: "user", content: input },
    ]);
  } catch (err) {
    clearInterval(heartbeat);
    throw new Error(`Conexão com LLM falhou para ${agent.name}: ${err}`);
  }

  if (!llmResponse.ok || !llmResponse.body) {
    clearInterval(heartbeat);
    throw new Error(`HTTP ${llmResponse.status} ao chamar ${agent.name}`);
  }

  const decoder = new TextDecoder();
  const reader = llmResponse.body.getReader();
  let buffer = "";
  let fullOutput = "";
  let fullThinking = "";

  let chunkTimedOut = false;
  try {
    while (true) {
      let done: boolean;
      let value: Uint8Array | undefined;
      try {
        const result = await Promise.race([
          reader.read(),
          new Promise<never>((_, reject) =>
            setTimeout(() => reject(new Error("chunk timeout")), AGENT_CHUNK_TIMEOUT_MS)
          ),
        ]);
        done = result.done;
        value = result.value;
      } catch {
        // Chunk timeout — sair graciosamente com o que foi acumulado
        chunkTimedOut = true;
        break;
      }

      if (done) break;

      buffer += decoder.decode(value!, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed === "data: [DONE]") continue;
        if (!trimmed.startsWith("data: ")) continue;

        try {
          const json = JSON.parse(trimmed.slice(6));
          const delta = json.choices?.[0]?.delta ?? {};
          if (delta.content) {
            fullOutput += delta.content;
            emit({ type: "text", text: delta.content, agent_slug: agent.slug });
          }
          if (delta.reasoning_content) {
            fullThinking += delta.reasoning_content;
            emit({ type: "thinking", text: delta.reasoning_content, agent_slug: agent.slug });
          }
        } catch { /* malformed */ }
      }
    }
  } finally {
    clearInterval(heartbeat);
    try { reader.cancel(); } catch { /* ignore */ }
  }

  if (chunkTimedOut) {
    console.log(`[runAgentStreaming] chunk timeout — output=${fullOutput.length} thinking=${fullThinking.length}`);
    emit({
      type: "agent_error",
      message: `Resposta interrompida: sem novos tokens por ${AGENT_CHUNK_TIMEOUT_MS / 1000}s.`,
      agent_slug: agent.slug,
    });
  }

  // Se output vazio mas tem reasoning, usa reasoning como fallback
  if (!fullOutput && fullThinking) {
    emit({ type: "text", text: fullThinking, agent_slug: agent.slug });
    return fullThinking;
  }

  // Se output parece truncado (muito curto ou termina no meio de uma frase),
  // faz uma chamada de continuação para completar a resposta
  const CONTINUATION_THRESHOLD = 300;
  const endsCleanly = /[.!?\n}\])]$/.test(fullOutput.trimEnd());
  if (!chunkTimedOut && fullOutput.length > 0 && fullOutput.length < CONTINUATION_THRESHOLD && !endsCleanly) {
    console.log(`[runAgentStreaming] output truncado (${fullOutput.length} chars), tentando continuação`);
    emit({ type: "thinking", text: "\n[continuando geração...]", agent_slug: agent.slug });

    const contHeartbeat = setInterval(() => emit({ type: "heartbeat" }), 20_000);
    try {
      const contResponse = await callLLMStream(agent.llm_provider, agent.llm_model, [
        { role: "system", content: agent.system_prompt },
        { role: "user", content: input },
        { role: "assistant", content: fullOutput },
        { role: "user", content: "Continue exatamente de onde parou, sem repetir o que já foi escrito." },
      ]);

      if (contResponse.ok && contResponse.body) {
        const contReader = contResponse.body.getReader();
        const contDecoder = new TextDecoder();
        let contBuffer = "";
        try {
          while (true) {
            let contDone: boolean;
            let contValue: Uint8Array | undefined;
            try {
              const r = await Promise.race([
                contReader.read(),
                new Promise<never>((_, rej) => setTimeout(() => rej(new Error("cont timeout")), AGENT_CHUNK_TIMEOUT_MS)),
              ]);
              contDone = r.done;
              contValue = r.value;
            } catch { break; }

            if (contDone) break;
            contBuffer += contDecoder.decode(contValue!, { stream: true });
            const lines = contBuffer.split("\n");
            contBuffer = lines.pop() ?? "";
            for (const line of lines) {
              const t = line.trim();
              if (!t || t === "data: [DONE]" || !t.startsWith("data: ")) continue;
              try {
                const json = JSON.parse(t.slice(6));
                const delta = json.choices?.[0]?.delta ?? {};
                if (delta.content) {
                  fullOutput += delta.content;
                  emit({ type: "text", text: delta.content, agent_slug: agent.slug });
                }
              } catch { /* ignore */ }
            }
          }
        } finally {
          try { contReader.cancel(); } catch { /* ignore */ }
        }
      }
    } catch (err) {
      console.log(`[runAgentStreaming] continuação falhou: ${err}`);
    } finally {
      clearInterval(contHeartbeat);
    }
  }

  if (chunkTimedOut) {
    return `${fullOutput}\n\n[Resposta interrompida: chunk timeout após ${AGENT_CHUNK_TIMEOUT_MS / 1000}s sem novos tokens.]`;
  }

  if (fullOutput.trim() && !/[.!?\n}\])]$/.test(fullOutput.trimEnd())) {
    return `${fullOutput}\n\n[Resposta truncada: terminou sem fechamento claro.]`;
  }

  return fullOutput;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { squad_slug, user_message, resume_run_id, max_steps } = await req.json();

    if (!squad_slug || !user_message) {
      return new Response(
        JSON.stringify({ error: "squad_slug e user_message são obrigatórios" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: squad, error: squadError } = await supabase
      .from("squad_definitions")
      .select("*")
      .eq("slug", squad_slug)
      .single();

    if (squadError || !squad) {
      return new Response(
        JSON.stringify({ error: `Squad '${squad_slug}' não encontrada` }),
        { status: 404, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    const { data: agents, error: agentsError } = await supabase
      .from("agent_definitions")
      .select("*")
      .in("slug", squad.agent_slugs);

    if (agentsError || !agents?.length) {
      return new Response(
        JSON.stringify({ error: "Erro ao carregar agentes" }),
        { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    }

    // Resume: carrega histórico do run existente; caso contrário cria um novo run
    let runId: string;
    const initialHistory: { agent: string; output: string }[] = [];

    if (resume_run_id) {
      runId = resume_run_id;
      // Restaura status e carrega agent_runs já concluídos como histórico
      await supabase.from("squad_runs")
        .update({ status: "running", completed_at: null })
        .eq("id", resume_run_id);

      const { data: prevRuns } = await supabase
        .from("agent_runs")
        .select("agent_name, output, step_index")
        .eq("squad_run_id", resume_run_id)
        .eq("status", "done")
        .order("step_index");

      for (const r of prevRuns ?? []) {
        if (r.output) initialHistory.push({ agent: r.agent_name, output: r.output });
      }
    } else {
      const { data: squadRun } = await supabase
        .from("squad_runs")
        .insert({
          squad_slug: squad.slug,
          squad_name: squad.name,
          initial_prompt: user_message,
          status: "running",
        })
        .select("id")
        .single();
      runId = squadRun?.id ?? crypto.randomUUID();
    }

    const maxStepsThisRequest = Math.max(
      1,
      Math.min(Number(max_steps ?? MAX_ITERATIONS) || MAX_ITERATIONS, MAX_ITERATIONS)
    );

    const encoder = new TextEncoder();

    const readable = new ReadableStream({
      async start(controller) {
        const emit = (obj: unknown) =>
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(obj)}\n\n`));

        emit({ type: "squad_start", squad: squad.name, run_id: runId });

        const history: { agent: string; output: string }[] = [...initialHistory];
        const loadedAgents = agents as AgentDefinition[];
        const agentDefs = (squad.agent_slugs as string[])
          .map((slug) => loadedAgents.find((a) => a.slug === slug))
          .filter(Boolean) as AgentDefinition[];
        const retryCounts: Record<string, number> = {};
        let forcedDecision: OrchestratorDecision | null = null;
        let finalRunStatus = "done";
        let shouldContinue = false;
        let completed = false;
        let acceptedStepsThisRequest = 0;
        let step = initialHistory.length;

        try {
          for (; step < MAX_ITERATIONS; step++) {
            emit({ type: "heartbeat" });
            // ── Orchestrator decide próximo passo ───────────────────────
            // ── Orchestrator: LLM com timeout + fallback sequencial ─────────────
            let decisionText = "";

            if (forcedDecision) {
              decisionText = forcedDecision.agent_slug ?? "";
            } else {
              try {
                decisionText = await Promise.race([
                  (async () => {
                    const orchResponse = await callLLMStream(
                      squad.orchestrator_provider,
                      squad.orchestrator_model,
                      buildOrchestratorMessages(
                        squad.orchestrator_prompt,
                        agentDefs,
                        history,
                        user_message
                      )
                    );

                  if (!orchResponse.ok || !orchResponse.body) {
                    return ""; // fallback
                  }

                  const decoder = new TextDecoder();
                  const reader = orchResponse.body.getReader();
                  let orchBuffer = "";
                  let orchContent = "";
                  let orchReasoning = "";

                  try {
                    outer: while (true) {
                      const { done, value } = await reader.read();
                      if (done) break;

                      orchBuffer += decoder.decode(value, { stream: true });
                      const lines = orchBuffer.split("\n");
                      orchBuffer = lines.pop() ?? "";

                      for (const line of lines) {
                        const trimmed = line.trim();
                        if (!trimmed || trimmed === "data: [DONE]") continue;
                        if (trimmed.startsWith("event:")) continue;
                        if (!trimmed.startsWith("data: ")) continue;
                        try {
                          const parsed = JSON.parse(trimmed.slice(6));
                          if (parsed.error) { break outer; } // SSE error — stop, use fallback
                          const delta = parsed.choices?.[0]?.delta ?? {};
                          if (delta.content) orchContent += delta.content;
                          if (delta.reasoning_content) {
                            orchReasoning += delta.reasoning_content;
                            emit({ type: "orchestrator_thinking", text: delta.reasoning_content });
                          }
                        } catch { /* ignore malformed */ }
                      }
                    }
                  } finally {
                    try { reader.cancel(); } catch { /* ignore */ }
                  }

                  // Extract from reasoning if content is empty
                  if (!orchContent.trim() && orchReasoning.trim()) {
                    const mentionedAgent = agentDefs.find((a) =>
                      orchReasoning.toLowerCase().includes(a.slug)
                    );
                    if (mentionedAgent) return mentionedAgent.slug;
                  }

                    return orchContent.trim();
                  })(),
                  // 10 second hard timeout — fall back to sequential on any hang
                  new Promise<string>((resolve) => setTimeout(() => resolve(""), 10_000)),
                ]);
              } catch {
                decisionText = ""; // any error → sequential fallback
              }
            }

            // Parse decision: plain slug text or JSON fallback
            let decision: OrchestratorDecision;

            // Build rich context string for the next agent (includes all prior outputs)
            const buildAgentInput = (targetSlug: string): string => {
              if (history.length === 0) return user_message;
              const ctx = history
                .map((h) => `### ${h.agent}\n${h.output}`)
                .join("\n\n---\n\n");
              return `# Solicitação original\n${user_message}\n\n# Trabalho já realizado\n${ctx}\n\n# Sua tarefa\nContinue o trabalho como ${targetSlug}.`;
            };

            if (forcedDecision) {
              decision = forcedDecision;
              forcedDecision = null;
            } else if (!decisionText) {
              // Empty response — fallback to first unexecuted agent in sequence
              const executedNames = history.map((h) => h.agent);
              const nextAgent = agentDefs.find((a) => !executedNames.includes(a.name));
              if (!nextAgent) {
                emit({ type: "squad_done", total_steps: history.length });
                completed = true;
                break;
              }
              decision = { action: "call_agent", agent_slug: nextAgent.slug, reasoning: "Fallback sequencial.", input_for_agent: buildAgentInput(nextAgent.slug) };
            } else {
              const clean = decisionText.trim().toLowerCase().replace(/[^a-z0-9-]/g, " ").trim();
              if (clean === "done" || clean.startsWith("done ")) {
                if (history.length === 0) {
                  decision = { action: "call_agent", agent_slug: agentDefs[0].slug, reasoning: "Guard: forçando primeiro agente.", input_for_agent: buildAgentInput(agentDefs[0].slug) };
                } else {
                  emit({ type: "squad_done", total_steps: history.length });
                  completed = true;
                  break;
                }
              } else {
                const matchedAgent = agentDefs.find((a) => clean.includes(a.slug));
                if (matchedAgent) {
                  decision = { action: "call_agent", agent_slug: matchedAgent.slug, reasoning: decisionText.slice(0, 200), input_for_agent: buildAgentInput(matchedAgent.slug) };
                } else {
                  try {
                    decision = JSON.parse(extractJson(decisionText));
                    if (!decision.input_for_agent && decision.agent_slug) {
                      decision.input_for_agent = buildAgentInput(decision.agent_slug);
                    }
                  } catch {
                    const executedNames = history.map((h) => h.agent);
                    const nextAgent = agentDefs.find((a) => !executedNames.includes(a.name));
                    if (!nextAgent) { emit({ type: "squad_done", total_steps: history.length }); completed = true; break; }
                    decision = { action: "call_agent", agent_slug: nextAgent.slug, reasoning: "Fallback sequencial.", input_for_agent: buildAgentInput(nextAgent.slug) };
                  }
                }
              }
            }

            emit({ type: "orchestrator_thinking", text: decision.reasoning ?? decisionText.slice(0, 200) });

            if (decision.action === "done") {
              emit({ type: "squad_done", total_steps: history.length });
              completed = true;
              break;
            }

            if (decision.action !== "call_agent" || !decision.agent_slug) continue;

            const agent = agentDefs.find((a) => a.slug === decision.agent_slug);
            if (!agent) {
              emit({ type: "error", message: `Agente '${decision.agent_slug}' não encontrado` });
              break;
            }

            emit({ type: "agent_start", agent: agent.name, agent_slug: agent.slug, step });

            const { data: agentRun } = await supabase
              .from("agent_runs")
              .insert({
                squad_run_id: runId,
                agent_slug: agent.slug,
                agent_name: agent.name,
                step_index: step,
                input: decision.input_for_agent ?? user_message,
                status: "running",
                started_at: new Date().toISOString(),
              })
              .select("id")
              .single();

            const agentInput = decision.input_for_agent ?? user_message;
            let fullOutput = "";
            let runtimeError: string | null = null;

            try {
              const hasTools = Array.isArray(agent.tools) && agent.tools.length > 0;
              const agentWork = hasTools
                ? runAgentWithTools(agent, agentInput, emit)
                : runAgentStreaming(agent, agentInput, emit);

              fullOutput = await Promise.race([
                agentWork,
                new Promise<string>((_, reject) =>
                  setTimeout(() => reject(new Error(`Agente ${agent.name} excedeu 5 minutos`)), AGENT_TIMEOUT_MS)
                ),
              ]);
            } catch (err) {
              runtimeError = `${agent.name}: ${err}`;
              fullOutput = runtimeError;
              emit({ type: "agent_error", message: runtimeError, agent_slug: agent.slug });
            }

            const supervisorDecision = await reviewAgentOutput(
              squad,
              agentDefs,
              history,
              user_message,
              agent,
              agentInput,
              fullOutput,
              runtimeError,
              retryCounts[agent.slug] ?? 0,
              emit
            );

            emit({
              type: "supervisor_decision",
              agent_slug: agent.slug,
              action: supervisorDecision.action,
              target_agent_slug: supervisorDecision.agent_slug,
              reasoning: supervisorDecision.reasoning,
            });

            if (supervisorDecision.action === "abort") {
              finalRunStatus = "error";
              if (agentRun?.id) {
                await supabase
                  .from("agent_runs")
                  .update({ output: fullOutput, status: "rejected", completed_at: new Date().toISOString() })
                  .eq("id", agentRun.id);
              }
              emit({ type: "error", message: supervisorDecision.reasoning, agent_slug: agent.slug });
              break;
            }

            if (supervisorDecision.action === "retry_agent" || supervisorDecision.action === "call_agent") {
              const targetSlug = supervisorDecision.action === "retry_agent"
                ? agent.slug
                : supervisorDecision.agent_slug;

              if (!targetSlug || !agentDefs.some((a) => a.slug === targetSlug)) {
                finalRunStatus = "error";
                emit({ type: "error", message: `Supervisor apontou agente inválido: ${targetSlug ?? "vazio"}` });
                break;
              }

              retryCounts[targetSlug] = (retryCounts[targetSlug] ?? 0) + 1;
              if (retryCounts[targetSlug] > MAX_AGENT_RETRIES) {
                finalRunStatus = "error";
                emit({ type: "error", message: `Limite de retries atingido para '${targetSlug}'` });
                break;
              }

              if (agentRun?.id) {
                await supabase
                  .from("agent_runs")
                  .update({ output: fullOutput, status: "rejected", completed_at: new Date().toISOString() })
                  .eq("id", agentRun.id);
              }

              const recoveryInput = supervisorDecision.input_for_agent
                ?? `# Solicitação original\n${user_message}\n\n# Problema detectado pelo supervisor\n${supervisorDecision.reasoning}\n\n# Saída rejeitada do agente anterior (${agent.slug})\n${fullOutput}\n\nRefaça a etapa corrigindo o problema. Seja completo e objetivo.`;

              forcedDecision = {
                action: "call_agent",
                agent_slug: targetSlug,
                reasoning: supervisorDecision.reasoning,
                input_for_agent: recoveryInput,
              };

              emit({ type: "agent_done", agent_slug: agent.slug, step, status: "rejected" });
              continue;
            }

            if (agentRun?.id) {
              await supabase
                .from("agent_runs")
                .update({ output: fullOutput, status: "done", completed_at: new Date().toISOString() })
                .eq("id", agentRun.id);
            }

            history.push({ agent: agent.name, output: fullOutput });
            emit({ type: "agent_done", agent_slug: agent.slug, step });
            acceptedStepsThisRequest++;

            if (acceptedStepsThisRequest >= maxStepsThisRequest) {
              shouldContinue = history.length < agentDefs.length && step + 1 < MAX_ITERATIONS;
              if (shouldContinue) {
                emit({ type: "squad_continue", run_id: runId, total_steps: history.length });
              }
              break;
            }
          }
        } catch (err) {
          finalRunStatus = "error";
          emit({ type: "error", message: String(err) });
        }

        if (step >= MAX_ITERATIONS && !completed && finalRunStatus !== "error") {
          finalRunStatus = "error";
          emit({ type: "error", message: "Limite máximo de iterações atingido sem conclusão." });
        }

        await supabase
          .from("squad_runs")
          .update({
            status: shouldContinue ? "running" : finalRunStatus,
            completed_at: shouldContinue ? null : new Date().toISOString(),
          })
          .eq("id", runId);

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
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Erro interno" }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    );
  }
});
