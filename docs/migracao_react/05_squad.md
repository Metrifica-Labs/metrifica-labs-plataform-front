# Fase 5 — Squad (orquestração multi-agente)

Equivalente a `lib/features/squad/*`. Diferente dos outros módulos de IA, **não usa SSE** — usa polling, porque toda a orquestração roda no backend (Edge Functions) e o client apenas reflete snapshots do banco. É o módulo logicamente mais simples de portar (client "burro"), mas precisa replicar fielmente a máquina de estados e o ritmo de polling.

## 5.1 Estado

Equivalente a `squad_state.dart`:
```ts
type SquadStatus = 'idle'|'connecting'|'running'|'done'|'error';
type AgentRunStatus = 'pending'|'running'|'done'|'error';
interface ToolCallState { tool: string; result?: unknown } // isPending = result == null
interface AgentRunState { agentSlug, agentName, stepIndex, thinking, output, toolCalls: ToolCallState[], status: AgentRunStatus }
interface SquadState { squadName, runId, initialPrompt, orchestratorThinking, agentRuns: AgentRunState[], status: SquadStatus }
```

## 5.2 Store + loop de polling (Zustand)

Equivalente a `squad_notifier.dart`. Fluxo:

1. **`run({squadSlug, userMessage, organizationId?})`**: `POST {supabaseUrl}/functions/v1/start-squad-run` com `{squad_slug, user_message, organization_id?}` → resposta `{run: SquadRunModel}`.
2. **`driveRun(runId)`** — loop de polling (`while (mounted && !cancelled)`):
   - SELECT direto `squad_runs` (by id, single) e `agent_runs` (`WHERE squad_run_id = runId ORDER BY step_index`).
   - Aplica snapshot ao state.
   - Se `run.status` é `'done'` ou `'error'` → encerra o loop.
   - Se nenhum agente está `running` e ainda não foi solicitado avanço → `POST {supabaseUrl}/functions/v1/run-squad-step` com `{run_id}` (pede ao backend para processar o próximo passo).
   - Aguarda 5s (se há agente `running`) ou 3s (senão) antes do próximo poll.
   - **Implementação em React**: usar `setTimeout` recursivo (não `setInterval`, para respeitar o intervalo variável) dentro de um efeito com cleanup (`cancelled` flag) — atenção especial ao desmontar componente/trocar de squad para não deixar polling órfão.
3. **`resume({squadSlug, userMessage, runId})`**: retoma polling de um run já existente (útil após reload de página — persistir `runId` atual em algum lugar acessível ao montar, ex. URL ou state local).
4. **`restore({run, agentRuns})`**: reidrata o state a partir de dados já carregados (usado ao reabrir do histórico, sem novo polling).

## 5.3 Calibração de tools

Equivalente a `calibration_notifier.dart`:
- Para cada `toolName` em `agent.toolNames`, `POST {supabaseUrl}/functions/v1/calibrate-tools` com `{tool_name}`.
- Resposta `{ok: boolean, message?: string, duration_ms?: number}`.
- Usado para testar tools antes de rodar o squad de fato (status agregado pass/fail/running/idle por agente).

## 5.4 Histórico

Equivalente a `squad_history.dart`:
- `useSquadRunsHistory()`: últimos 30 de `squad_runs`.
- `useAgentRunsForSquad(squadRunId)`: lista de `agent_runs` daquele run.

## 5.5 UI — `squad_page.dart` e painéis

- **SquadPage**: header (nome/descrição/contagem de agentes), 2 tabs (Execução / Calibração) + botão de histórico.
- **SquadRunPanel**: textarea de prompt inicial (prefill fixo em dev), timeline de cards por agente (thinking expansível, tool calls com status, output em `react-markdown`), botões "Continuar execução" (`resume`) e "Nova execução" (reset state).
- **SquadCalibrationPanel**: lista de agentes do squad com suas tools, status agregado por agente, botão "Verificar Todos".
- **SquadHistoryPanel**: painel lateral com lista de runs, detalhe expandido por agent_run, botão "Restaurar na view principal" (`restore`).

## Critério de aceite da fase

- Rodar um squad real ponta a ponta, validar que a timeline de agentes atualiza em tempo (quase) real conforme o polling avança.
- Recarregar a página no meio de uma execução e confirmar que `resume` retoma corretamente o polling sem duplicar passos.
- Restaurar um run do histórico e confirmar que a timeline reflete o snapshot salvo, sem iniciar polling novo.
- Validar que o polling é encerrado corretamente ao trocar de squad ou navegar para outra rota (sem leak de timers).
