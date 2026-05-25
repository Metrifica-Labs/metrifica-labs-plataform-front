import { createClient } from "jsr:@supabase/supabase-js@2";
import { callLLMComplete, callLLMWithTools, LLMMessage, ToolCall } from "../_shared/llm-providers.ts";
import { executeTool } from "../_shared/tool-executor.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_ITERATIONS = 12;
const MAX_TOOL_LOOPS = 20;
const MAX_AGENT_RETRIES = 2;
const STALE_RUNNING_MS = 6 * 60_000;

interface AgentDefinition {
  slug: string;
  name: string;
  role: string;
  system_prompt: string;
  llm_provider: string;
  llm_model: string;
  tools: unknown[];
}

interface SquadDefinition {
  slug: string;
  name: string;
  orchestrator_provider: string;
  orchestrator_model: string;
  orchestrator_prompt: string;
  agent_slugs: string[];
}

interface SupervisorDecision {
  action: "accept" | "retry_agent" | "call_agent" | "abort";
  agent_slug?: string;
  reasoning: string;
  input_for_agent?: string;
}

function extractJson(raw: string): string {
  const trimmed = raw.trim();
  try { JSON.parse(trimmed); return trimmed; } catch { /* continue */ }
  const mdMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (mdMatch) {
    try { JSON.parse(mdMatch[1].trim()); return mdMatch[1].trim(); } catch { /* continue */ }
  }
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start !== -1 && end > start) return trimmed.slice(start, end + 1);
  return trimmed;
}

function buildAgentInput(
  userMessage: string,
  history: { agent: string; output: string }[],
  targetSlug: string,
  recoveryInstruction?: string,
): string {
  const recovery = recoveryInstruction
    ? `\n\n# Instrução de recuperação\n${recoveryInstruction}`
    : "";
  if (history.length === 0) return `${userMessage}${recovery}`;
  const ctx = history.map((h) => `### ${h.agent}\n${h.output}`).join("\n\n---\n\n");
  return `# Solicitação original\n${userMessage}\n\n# Trabalho já realizado\n${ctx}${recovery}\n\n# Sua tarefa\nContinue o trabalho como ${targetSlug}.`;
}

function looksInvalid(output: string): boolean {
  const clean = output.trim();
  if (clean.length < 80) return true;
  const lower = clean.toLowerCase();
  return lower.includes("timeout") || lower.includes("erro ao executar") || lower.includes("limite de tool calls");
}

function deterministicReview(agentDefs: AgentDefinition[], agent: AgentDefinition, output: string, runtimeError: string | null): SupervisorDecision | null {
  if (runtimeError) {
    return { action: "retry_agent", agent_slug: agent.slug, reasoning: "Agente falhou em runtime.", input_for_agent: `A execução anterior falhou: ${runtimeError}\nRefaça a etapa completa.` };
  }
  if (looksInvalid(output)) {
    return { action: "retry_agent", agent_slug: agent.slug, reasoning: "Resposta vazia, curta ou inválida.", input_for_agent: `A resposta anterior foi inválida. Refaça a etapa completa.\n\nResposta rejeitada:\n${output.slice(0, 3000)}` };
  }

  const role = `${agent.slug} ${agent.name} ${agent.role} ${agent.system_prompt}`.toLowerCase();
  const lower = output.toLowerCase();
  const isDev = role.includes("dev") || role.includes("developer") || role.includes("desenvolvedor");
  const isQa = role.includes("qa") || role.includes("teste");

  if (isDev) {
    if (!lower.includes("tool_result github_push_files")) {
      return { action: "retry_agent", agent_slug: agent.slug, reasoning: "Developer não commitou arquivos.", input_for_agent: "Continue o desenvolvimento: gere arquivos reais, testes/workflow e use github_push_files. Não pare após criar repo." };
    }
    const hasCode = /\s-\s.+\.(ts|tsx|js|jsx|py|dart|go|rs|java|kt|swift|cs|php|rb|html|css|sql)/i.test(output);
    const hasTestOrCi = /\s-\s(.+test\.|.+spec\.|test\/|tests\/|__tests__\/|\.github\/workflows\/)/i.test(output);
    if (!hasCode) return { action: "retry_agent", agent_slug: agent.slug, reasoning: "Commit sem evidência de código real.", input_for_agent: "Faça novo commit com implementação real usando github_push_files." };
    if (!hasTestOrCi) return { action: "retry_agent", agent_slug: agent.slug, reasoning: "Commit sem testes ou CI.", input_for_agent: "Adicione testes e/ou .github/workflows/test.yml e faça novo commit." };
    return { action: "accept", reasoning: "Developer entregou código e testes/CI." };
  }

  if (isQa) {
    if (!lower.includes("tool_result github_get_actions_status")) {
      return { action: "retry_agent", agent_slug: agent.slug, reasoning: "QA não consultou status real dos testes.", input_for_agent: "Use github_get_actions_status no repo entregue. Não aprove sem evidência." };
    }
    if (lower.includes("actions: success")) return { action: "accept", reasoning: "QA verificou Actions com sucesso." };
    const developer = agentDefs.find((a) => `${a.slug} ${a.name} ${a.role}`.toLowerCase().includes("dev"));
    return { action: "call_agent", agent_slug: developer?.slug ?? agent.slug, reasoning: "QA não confirmou sucesso; Developer deve corrigir.", input_for_agent: `QA rejeitou ou não confirmou sucesso. Corrija e faça novo commit:\n\n${output}` };
  }

  return { action: "accept", reasoning: "Saída aceita pelas validações rápidas." };
}

function buildOrchestratorPrompt(squad: SquadDefinition, agents: AgentDefinition[], history: { agent: string; output: string }[], userMessage: string): LLMMessage[] {
  const slugList = agents.map((a) => `${a.slug} (${a.name})`).join(", ");
  const historyBlock = history.length === 0
    ? "Nenhum agente executado ainda."
    : history.map((h, i) => `[${i + 1}] ${h.agent}:\n${h.output.slice(0, 1200)}`).join("\n\n---\n\n");
  return [
    { role: "system", content: `${squad.orchestrator_prompt}\n\nAgentes disponíveis: ${slugList}\n\nHistórico:\n${historyBlock}\n\nTarefa original:\n${userMessage}\n\nResponda APENAS com o slug do próximo agente ou done.` },
    { role: "user", content: "Qual é o próximo agente?" },
  ];
}

async function runAgent(
  agent: AgentDefinition,
  input: string,
  onProgress?: (output: string) => Promise<void>,
): Promise<string> {
  const messages: LLMMessage[] = [
    { role: "system", content: agent.system_prompt },
    { role: "user", content: input },
  ];

  if (!Array.isArray(agent.tools) || agent.tools.length === 0) {
    return await callLLMComplete(agent.llm_provider, agent.llm_model, messages);
  }

  const toolTranscript: string[] = [];
  for (let loop = 0; loop < MAX_TOOL_LOOPS; loop++) {
    const response = await callLLMWithTools(agent.llm_provider, agent.llm_model, messages, agent.tools);
    if (!response.tool_calls?.length) {
      const content = response.content ?? "";
      return toolTranscript.length ? `${content}\n\n# Ferramentas executadas\n${toolTranscript.join("\n\n")}` : content;
    }

    messages.push({ role: "assistant", content: response.content, tool_calls: response.tool_calls });
    for (const tc of response.tool_calls as ToolCall[]) {
      const toolName = tc.function.name;
      let args: Record<string, unknown> = {};
      try { args = JSON.parse(tc.function.arguments); } catch { /* ignore */ }
      toolTranscript.push(`TOOL_CALL ${toolName}: ${JSON.stringify(args).slice(0, 2000)}`);
      if (onProgress) await onProgress(`# Ferramentas executadas\n${toolTranscript.join("\n\n")}`);
      let result: string;
      try { result = await executeTool(toolName, args); } catch (err) { result = `Erro ao executar ${toolName}: ${err}`; }
      toolTranscript.push(`TOOL_RESULT ${toolName}: ${result.slice(0, 4000)}`);
      if (onProgress) await onProgress(`# Ferramentas executadas\n${toolTranscript.join("\n\n")}`);
      messages.push({ role: "tool", content: result, tool_call_id: tc.id });
    }
  }
  return `Limite de tool calls atingido.\n\n# Ferramentas executadas\n${toolTranscript.join("\n\n")}`;
}

async function processStep(runId: string) {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: run, error: runError } = await supabase.from("squad_runs").select("*").eq("id", runId).single();
  if (runError || !run) throw runError ?? new Error("Run não encontrado");
  if (run.status === "done" || run.status === "error") return;

  const running = await supabase
    .from("agent_runs")
    .select("id, agent_slug, output, started_at")
    .eq("squad_run_id", runId)
    .eq("status", "running")
    .order("started_at")
    .limit(1);
  if (running.data?.length) {
    const active = running.data[0] as { id: string; agent_slug: string; output?: string | null; started_at?: string | null };
    const startedAt = active.started_at ? new Date(active.started_at).getTime() : 0;
    const isStale = startedAt > 0 && Date.now() - startedAt > STALE_RUNNING_MS;
    if (!isStale) return;

    await supabase
      .from("agent_runs")
      .update({
        status: "rejected",
        output: `${active.output ?? ""}\n\n# Supervisor\nACTION: retry_agent\nTARGET_AGENT: ${active.agent_slug}\nREASON: Etapa ficou running por mais de ${STALE_RUNNING_MS / 60000} minutos; retomando em nova execução.\nINPUT_FOR_AGENT: Continue do último checkpoint salvo. Se o repositório já existir, reutilize-o e avance para commitar código/testes.`,
        completed_at: new Date().toISOString(),
      })
      .eq("id", active.id);
  }

  const { data: squad } = await supabase.from("squad_definitions").select("*").eq("slug", run.squad_slug).single();
  if (!squad) throw new Error(`Squad '${run.squad_slug}' não encontrada`);

  const { data: loadedAgents } = await supabase.from("agent_definitions").select("*").in("slug", squad.agent_slugs);
  const agentDefs = (squad.agent_slugs as string[])
    .map((slug) => (loadedAgents as AgentDefinition[]).find((a) => a.slug === slug))
    .filter(Boolean) as AgentDefinition[];

  const { data: previousRuns } = await supabase
    .from("agent_runs")
    .select("agent_slug, agent_name, output, status, step_index")
    .eq("squad_run_id", runId)
    .in("status", ["done", "rejected"])
    .order("step_index");

  const accepted = (previousRuns ?? []).filter((r) => r.status === "done" && r.output);
  const history = accepted.map((r) => ({ agent: r.agent_name, output: r.output }));
  const stepIndex = previousRuns?.length ?? 0;

  if (stepIndex >= MAX_ITERATIONS) {
    await supabase.from("squad_runs").update({ status: "error", completed_at: new Date().toISOString() }).eq("id", runId);
    return;
  }

  let nextSlug = "";
  let recoveryInstruction = "";
  const lastRun = [...(previousRuns ?? [])].reverse()[0];
  if (lastRun?.status === "rejected" && lastRun.output) {
    const targetMatch = lastRun.output.match(/TARGET_AGENT:\s*([a-z0-9-]+)/i);
    nextSlug = targetMatch?.[1] ?? lastRun.agent_slug;
    const inputMatch = lastRun.output.match(/INPUT_FOR_AGENT:\s*([\s\S]*)$/i);
    recoveryInstruction = inputMatch?.[1]?.trim() ?? "";
  }

  if (!nextSlug) {
    const raw = await callLLMComplete(squad.orchestrator_provider, squad.orchestrator_model, buildOrchestratorPrompt(squad, agentDefs, history, run.initial_prompt));
    const clean = raw.trim().toLowerCase().replace(/[^a-z0-9-]/g, " ").trim();
    if (clean === "done" || clean.startsWith("done ")) {
      await supabase.from("squad_runs").update({ status: "done", completed_at: new Date().toISOString() }).eq("id", runId);
      return;
    }
    nextSlug = agentDefs.find((a) => clean.includes(a.slug))?.slug ?? "";
  }

  if (!nextSlug) {
    const executedNames = history.map((h) => h.agent);
    nextSlug = agentDefs.find((a) => !executedNames.includes(a.name))?.slug ?? "";
  }

  if (!nextSlug) {
    await supabase.from("squad_runs").update({ status: "done", completed_at: new Date().toISOString() }).eq("id", runId);
    return;
  }

  const agent = agentDefs.find((a) => a.slug === nextSlug);
  if (!agent) throw new Error(`Agente '${nextSlug}' não encontrado`);

  const attempts = (previousRuns ?? []).filter((r) => r.agent_slug === agent.slug && r.status === "rejected").length;
  if (attempts > MAX_AGENT_RETRIES) {
    await supabase.from("squad_runs").update({ status: "error", completed_at: new Date().toISOString() }).eq("id", runId);
    return;
  }

  const input = buildAgentInput(run.initial_prompt, history, agent.slug, recoveryInstruction);
  const { data: agentRun } = await supabase.from("agent_runs").insert({
    squad_run_id: runId,
    agent_slug: agent.slug,
    agent_name: agent.name,
    step_index: stepIndex,
    input,
    status: "running",
    started_at: new Date().toISOString(),
  }).select("id").single();

  let output = "";
  let runtimeError: string | null = null;
  try {
    output = await runAgent(agent, input, async (partialOutput) => {
      await supabase
        .from("agent_runs")
        .update({ output: partialOutput })
        .eq("id", agentRun.id);
    });
  } catch (err) {
    runtimeError = String(err);
    output = runtimeError;
  }

  const decision = deterministicReview(agentDefs, agent, output, runtimeError);
  const status = decision?.action === "accept" ? "done" : "rejected";
  const targetAgent = decision?.action === "call_agent"
    ? decision.agent_slug
    : decision?.action === "retry_agent"
      ? agent.slug
      : "";
  const outputWithReview = `${output}\n\n# Supervisor\nACTION: ${decision?.action ?? "accept"}\nTARGET_AGENT: ${targetAgent}\nREASON: ${decision?.reasoning ?? "Aceito."}\nINPUT_FOR_AGENT: ${decision?.input_for_agent ?? ""}`;

  await supabase.from("agent_runs").update({
    output: outputWithReview,
    status,
    completed_at: new Date().toISOString(),
  }).eq("id", agentRun.id);

  if (decision?.action === "abort") {
    await supabase.from("squad_runs").update({ status: "error", completed_at: new Date().toISOString() }).eq("id", runId);
  } else {
    await supabase.from("squad_runs").update({ status: "running", completed_at: null }).eq("id", runId);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });

  try {
    const { run_id } = await req.json();
    if (!run_id) {
      return new Response(JSON.stringify({ error: "run_id obrigatório" }), { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } });
    }

    const task = processStep(run_id).catch(async (err) => {
      console.error(`[run-squad-step] ${run_id}:`, err);
      const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
      await supabase.from("squad_runs").update({ status: "error", completed_at: new Date().toISOString() }).eq("id", run_id);
    });

    const edgeRuntime = (globalThis as unknown as { EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void } }).EdgeRuntime;
    if (edgeRuntime?.waitUntil) edgeRuntime.waitUntil(task);
    else await task;

    return new Response(JSON.stringify({ queued: true, run_id }), {
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  }
});
