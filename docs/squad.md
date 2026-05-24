# Plan: AI Squad Orchestrator

## Context

The platform has a single-agent `run-flow` system (one LLM, one linear response). This plan adds a **dynamic multi-agent orchestrator** where a meta-agent LLM decides in real time which specialist to call next (PM → Architect → Dev → Reviewer → QA), iterating until the result is satisfactory. The frontend gets a new `/squads/:slug` section with a real-time execution dashboard.

## Architecture

```
User prompt
    │
    ▼
run-squad (Supabase Edge Function)
    │
    ├─ Load squad_definitions + agent_definitions from DB
    │
    ├─ Orchestrator loop (max 10 iterations):
    │    │
    │    ├─ callLLMComplete(openai, gpt-4o)  ←── JSON decision
    │    │    └─ { action: 'call_agent', agent_slug, input } | { action: 'done' }
    │    │
    │    └─ If call_agent:
    │         ├─ emit SSE: agent_start
    │         ├─ callLLMStream(crofai, deepseek-v4-pro) → pipe chunks to client
    │         │    └─ emit SSE: thinking | text
    │         ├─ emit SSE: agent_done
    │         └─ accumulate in history[]
    │
    └─ emit SSE: squad_done | [DONE]
          │
          ▼
Flutter SSE parser (SquadNotifier)
    │
    ├─ AgentRunState list grows with each agent_start
    ├─ Active agent's output/thinking updated on each chunk
    └─ SquadPage renders timeline + streaming card
```

## 1. Database Schema (run via Supabase Studio SQL editor)

```sql
CREATE TABLE agent_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL,
  system_prompt TEXT NOT NULL,
  llm_provider TEXT NOT NULL DEFAULT 'crofai',
  llm_model TEXT NOT NULL DEFAULT 'deepseek-v4-pro',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE squad_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  orchestrator_provider TEXT NOT NULL DEFAULT 'openai',
  orchestrator_model TEXT NOT NULL DEFAULT 'gpt-4o',
  orchestrator_prompt TEXT NOT NULL,
  agent_slugs TEXT[] NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE squad_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_slug TEXT NOT NULL,
  squad_name TEXT,
  initial_prompt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'running',
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE agent_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_run_id UUID NOT NULL REFERENCES squad_runs(id) ON DELETE CASCADE,
  agent_slug TEXT NOT NULL,
  agent_name TEXT NOT NULL,
  step_index INTEGER NOT NULL,
  input TEXT NOT NULL,
  output TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
```

Seed one squad to test with:
```sql
INSERT INTO agent_definitions (slug, name, role, system_prompt) VALUES
  ('pm-agent', 'PM Agent', 'Define requisitos e escopo do produto', 'Você é um Product Manager experiente...'),
  ('architect-agent', 'Arquiteto', 'Projeta arquitetura técnica', 'Você é um Arquiteto de Software sênior...'),
  ('dev-agent', 'Developer', 'Implementa código e soluções técnicas', 'Você é um desenvolvedor full-stack sênior...');

INSERT INTO squad_definitions (slug, name, description, orchestrator_prompt, agent_slugs) VALUES
  ('dev-squad', 'Dev Squad', 'Squad completo de desenvolvimento',
   'Você é um orquestrador de agentes de software. Analise o histórico e decida qual agente chamar próximo. Retorne apenas JSON no formato: {"action":"call_agent","agent_slug":"<slug>","reasoning":"<motivo>","input_for_agent":"<input refinado>"} ou {"action":"done","reasoning":"<motivo>"}. Agentes disponíveis: PM Agent (pm-agent), Arquiteto (architect-agent), Developer (dev-agent).',
   ARRAY['pm-agent', 'architect-agent', 'dev-agent']);
```

## 2. Edge Function: `supabase/functions/_shared/llm-providers.ts` (new)

Extracted from the `run-flow` pattern. Provides two functions used by `run-squad`:

```typescript
interface LLMMessage { role: 'system' | 'user' | 'assistant'; content: string; }

const PROVIDERS = {
  crofai: { baseUrl: 'https://crof.ai/v1', apiKeyEnvVar: 'CROFAI_API_KEY' },
  openai: { baseUrl: 'https://api.openai.com/v1', apiKeyEnvVar: 'OPENAI_API_KEY' },
};

// Returns the raw streaming Response (SSE from LLM provider)
export async function callLLMStream(provider: string, model: string, messages: LLMMessage[]): Promise<Response>

// Collects all chunks and returns the full text string (for orchestrator JSON decisions)
export async function callLLMComplete(provider: string, model: string, messages: LLMMessage[]): Promise<string>
```

`callLLMStream` uses the same fetch pattern as `run-flow/index.ts:78-94` (AbortSignal.timeout 100s, streaming: true).  
`callLLMComplete` calls with `stream: false` (or `stream: true` and collects chunks). For OpenAI orchestrator decisions, add `response_format: { type: 'json_object' }` to force valid JSON output.

## 3. Edge Function: `supabase/functions/run-squad/index.ts` (new)

**SSE protocol** (superset of `run-flow`):
```
{"type":"squad_start","squad":"Dev Squad","run_id":"<uuid>"}
{"type":"orchestrator_thinking","text":"Vou começar pelo PM..."}
{"type":"agent_start","agent":"PM Agent","agent_slug":"pm-agent","step":0}
{"type":"thinking","text":"...","agent_slug":"pm-agent"}
{"type":"text","text":"...","agent_slug":"pm-agent"}
{"type":"agent_done","agent_slug":"pm-agent","step":0,"output":"<full output>"}
{"type":"squad_done","total_steps":3}
{"type":"error","message":"..."}
data: [DONE]
```

**Core logic:**
```typescript
// 1. Parse body: { squad_slug, user_message, user_id? }
// 2. Load squad_definitions and agent_definitions from Supabase
// 3. Insert squad_runs row → get run_id; emit squad_start
// 4. Orchestrator loop (max 10):
const history: { agent: string; output: string }[] = [];
for (let step = 0; step < 10; step++) {
  const decision = JSON.parse(await callLLMComplete(
    squad.orchestrator_provider, squad.orchestrator_model,
    buildOrchestratorMessages(squad.orchestrator_prompt, agentDefs, history, user_message)
  ));
  emit orchestrator_thinking with decision.reasoning;

  if (decision.action === 'done') { emit squad_done; break; }

  const agent = agentDefs.find(a => a.slug === decision.agent_slug);
  emit agent_start;
  // Insert agent_runs row (status: running)
  const llmStream = await callLLMStream(agent.llm_provider, agent.llm_model, [
    { role: 'system', content: agent.system_prompt },
    { role: 'user', content: decision.input_for_agent },
  ]);
  // Pipe chunks to client, accumulate full output, emit thinking/text with agent_slug
  const fullOutput = await streamAgentToClient(llmStream, writer, agent.slug);
  // Update agent_runs row (status: done, output: fullOutput)
  history.push({ agent: agent.name, output: fullOutput });
  emit agent_done with output;
}
// Update squad_runs row (status: done/error)
```

**Key implementation note:** The Supabase Edge Function uses `TransformStream` + `ReadableStream` as in `run-flow`. The function body creates a `ReadableStream` whose `start(controller)` runs the entire orchestrator loop, enqueuing SSE frames. Total timeout bumped to 300s (`AbortSignal.timeout(300_000)`) to accommodate multi-agent runs.

## 4. Flutter: Models (`lib/core/models/`)

Four new files following `FlowModel` pattern exactly:

**`squad_definition_model.dart`**
```dart
class SquadDefinitionModel {
  final String id, slug, name;
  final String? description;
  final List<String> agentSlugs;
  factory SquadDefinitionModel.fromJson(Map<String, dynamic> json) { ... }
}
```

**`agent_definition_model.dart`** — id, slug, name, role, llmProvider, llmModel

**`squad_run_model.dart`** — id, squadSlug, squadName, status, initialPrompt, createdAt

**`agent_run_model.dart`** — id, squadRunId, agentSlug, agentName, stepIndex, input, output, status

## 5. Flutter: Repositories (`lib/core/repositories/`)

**`squads_repository.dart`** — mirrors `flows_repository.dart`:
```dart
final squadsProvider = FutureProvider<List<SquadDefinitionModel>>((ref) async { ... });
final squadBySlugProvider = FutureProvider.family<SquadDefinitionModel?, String>((ref, slug) async { ... });
```

**`agent_definitions_repository.dart`** — `agentDefinitionsProvider` with optional slug filter.

## 6. Flutter: State Management (`lib/features/squad/data/`)

**`squad_state.dart`**
```dart
enum SquadStatus { idle, connecting, running, done, error }

class AgentRunState {
  final String agentSlug, agentName;
  final int step;
  final bool isActive, isDone;
  final String thinking, output;
}

class SquadState {
  final SquadStatus status;
  final String? squadName, runId, orchestratorThinking, error;
  final List<AgentRunState> agentRuns;

  bool get isRunning => status == SquadStatus.connecting || status == SquadStatus.running;
}
```

**`squad_notifier.dart`** — follows `GenerationNotifier` exactly:
- `StateNotifierProvider.autoDispose<SquadNotifier, SquadState>`
- `run(squadSlug, userMessage)` — POST to `/functions/v1/run-squad`, parse SSE stream
- SSE parser switch cases for the new event types:
  - `squad_start` → set squadName, runId, status=running
  - `orchestrator_thinking` → set orchestratorThinking
  - `agent_start` → append new `AgentRunState(isActive:true)` to agentRuns
  - `thinking` (with agent_slug) → update active agent's thinking field
  - `text` (with agent_slug) → update active agent's output field
  - `agent_done` → mark active agent isDone=true, isActive=false
  - `squad_done` → status=done
  - `error` → status=error

## 7. Flutter: UI (`lib/features/squad/presentation/`)

### `squad_page.dart`
Mirrors `flow_page.dart`. Loads `squadBySlugProvider(slug)`, renders header + `SquadRunPanel`.

### `squad_run_panel.dart`
Main panel with two states:
- **Input state** (status=idle): simple TextField + "Executar Squad" button
- **Running/done state**: 
  - `_OrchestratorBadge` — shows current orchestratorThinking text in a subtle container
  - `_AgentTimeline` — vertical list of all agentRuns with status indicator:
    - pending: faded dot `○`
    - active: `_PulsingDot` (replicate from `generation_panel.dart`)
    - done: checkmark `✓`
  - For the active agent: full `_ThinkingSection` + `_OutputCard` pattern (replicated from `generation_panel.dart` — these are private widgets, so copy the implementation into squad files)
  - For completed agents: collapsed card showing agent name + output snippet, expandable on tap

### `squad_history_panel.dart`
Slide-in panel (same `showGeneralDialog` + SlideTransition pattern as `history_panel.dart`).
Reads from `squad_runs` table via a `squadRunsHistoryProvider` (AsyncNotifierProvider, same pattern as `HistoryNotifier`).
Shows list of past runs with squad name, prompt preview, timestamp, step count.

## 8. Routing & Navigation

**`lib/core/router/app_router.dart`** — add inside the ShellRoute:
```dart
GoRoute(
  path: '/squads/:slug',
  builder: (context, state) => SquadPage(slug: state.pathParameters['slug']!),
),
```

**`lib/shared/widgets/shell_scaffold.dart`** — the `_Sidebar` currently watches `flowsAsync` + `modulesAsync`. Add `squadsAsync = ref.watch(squadsProvider)` and pass to `_NavList`. In `_NavList.build()`, add a "Squads" section header + one `_SquadNavTile` per squad (no expandable children needed, squads navigate directly to `/squads/:slug`). The compact sidebar shows a `Groups` icon tile for each squad.

## 9. Files to Create / Modify

| File | Action |
|------|--------|
| `supabase/functions/_shared/llm-providers.ts` | Create |
| `supabase/functions/_shared/tool-executor.ts` | Create |
| `supabase/functions/run-squad/index.ts` | Create |
| `lib/core/models/squad_definition_model.dart` | Create |
| `lib/core/models/agent_definition_model.dart` | Create |
| `lib/core/models/squad_run_model.dart` | Create |
| `lib/core/models/agent_run_model.dart` | Create |
| `lib/core/repositories/squads_repository.dart` | Create |
| `lib/core/repositories/agent_definitions_repository.dart` | Create |
| `lib/features/squad/data/squad_state.dart` | Create |
| `lib/features/squad/data/squad_notifier.dart` | Create |
| `lib/features/squad/presentation/squad_page.dart` | Create |
| `lib/features/squad/presentation/squad_run_panel.dart` | Create |
| `lib/features/squad/presentation/squad_history_panel.dart` | Create |
| `lib/core/router/app_router.dart` | Edit — add `/squads/:slug` route |
| `lib/shared/widgets/shell_scaffold.dart` | Edit — add Squads section to sidebar |

**Reference files (read-only, patterns to follow):**
- `supabase/functions/run-flow/index.ts` — SSE streaming pattern
- `lib/features/generation/data/generation_notifier.dart` — StateNotifier + SSE parsing
- `lib/features/generation/data/generation_state.dart` — state shape
- `lib/features/generation/presentation/generation_panel.dart` — `_ThinkingSection`, `_OutputCard`, `_StatusRow`, `_PulsingDot`, `_ErrorCard`
- `lib/features/generation/presentation/history_panel.dart` — slide-in panel pattern
- `lib/features/generation/data/generation_history.dart` — AsyncNotifier DB persistence
- `lib/core/repositories/flows_repository.dart` — FutureProvider.family pattern
- `lib/core/models/flow_model.dart` — model fromJson pattern

## 10. Optional MCP Tool Capabilities

Agents can optionally have tools (Trello, Figma, GitHub, Slack, etc.) configured via the DB. Agents without tools behave exactly as before — no impact on the core flow.

### DB change: add `tools` column to `agent_definitions`

```sql
ALTER TABLE agent_definitions ADD COLUMN tools JSONB NOT NULL DEFAULT '[]';
```

The `tools` array contains OpenAI function-calling format schemas, e.g.:

```json
[
  {
    "type": "function",
    "function": {
      "name": "trello_create_card",
      "description": "Cria um card no Trello",
      "parameters": {
        "type": "object",
        "properties": {
          "list_id": { "type": "string" },
          "name": { "type": "string" },
          "description": { "type": "string" }
        },
        "required": ["list_id", "name"]
      }
    }
  }
]
```

### New shared file: `supabase/functions/_shared/tool-executor.ts`

Centralizes all tool implementations. Each tool is a function that receives `args` and returns a string result:

```typescript
export async function executeTool(
  toolName: string,
  args: Record<string, unknown>
): Promise<string>
```

Initial tool registry:
- **Trello**: `trello_create_card`, `trello_get_board`, `trello_move_card` — calls `https://api.trello.com/1/...` with `TRELLO_API_KEY` + `TRELLO_TOKEN` env vars
- **Figma**: `figma_get_file`, `figma_get_components` — calls `https://api.figma.com/v1/...` with `FIGMA_ACCESS_TOKEN`
- **GitHub**: `github_create_issue`, `github_get_repo` — calls GitHub REST API with `GITHUB_TOKEN`

Adding new integrations = adding a new `case` to the switch in `executeTool`. No schema changes needed.

### Agent inner loop in `run-squad`

When `agent.tools.length > 0`, include `tools` in the LLM request. After each LLM response, check for `tool_calls`:

```typescript
// Inner agentic loop for a single agent turn
const messages = [systemMsg, userMsg];
while (true) {
  const response = await callLLMComplete(agent.llm_provider, agent.llm_model, messages, agent.tools);
  if (response.tool_calls) {
    for (const tc of response.tool_calls) {
      emit tool_call SSE event;
      const result = await executeTool(tc.function.name, JSON.parse(tc.function.arguments));
      emit tool_result SSE event;
      messages.push({ role: 'assistant', tool_calls: [tc] });
      messages.push({ role: 'tool', tool_call_id: tc.id, content: result });
    }
    continue; // LLM decides next step based on tool results
  }
  // No more tool calls — stream final content to client
  await streamFinalContent(response.content, writer, agent.slug);
  break;
}
```

Note: The `callLLMComplete` function in `_shared/llm-providers.ts` gets an optional `tools` parameter. When tools are present, the call is always non-streaming (to handle tool_calls in the response); the final content streaming happens only after all tool calls resolve. Alternatively, use streaming with tool_call deltas — but non-streaming for the agentic loop keeps it simpler.

### New SSE event types for tool calls

```
{"type":"tool_call","tool":"trello_create_card","args":{"list_id":"...","name":"Sprint 1"},"agent_slug":"scrum-agent"}
{"type":"tool_result","tool":"trello_create_card","result":"Card criado: Sprint 1 (ID: abc123)","agent_slug":"scrum-agent"}
```

### Flutter state additions

`AgentRunState` gets:
```dart
final List<({String tool, String? result})> toolCalls;
```

`SquadNotifier` handles new events:
- `tool_call` → append `(tool: name, result: null)` to active agent's toolCalls
- `tool_result` → update matching toolCall entry with result

### UI: Tool call display in `squad_run_panel.dart`

Inside the active agent card, above the thinking section, show each tool call inline:

```
🔧 trello_create_card {"name":"Sprint 1"} → Card criado: Sprint 1 (ID: abc123)
```

Compact single-line format: tool icon + tool name + args summary → result snippet. No separate widget needed — rendered inside `_StreamingAgentCard` as a simple `Column` of `_ToolCallRow` widgets.

## 11. Environment Variables

Add to Supabase project secrets (dashboard → Edge Functions → Secrets) and to local `.env`:

```
OPENAI_API_KEY=sk-...
TRELLO_API_KEY=...       # optional, only needed if any agent uses Trello tools
TRELLO_TOKEN=...         # optional
FIGMA_ACCESS_TOKEN=...   # optional, only needed if any agent uses Figma tools
GITHUB_TOKEN=...         # optional
```

Only secrets for tools actually used need to be set. `tool-executor.ts` reads them lazily and returns a clear error message if the required env var is missing.

## 11. Verification

1. **DB**: Run the 4 `CREATE TABLE` + seed SQL in Supabase Studio SQL editor
2. **Edge function**: `supabase functions deploy run-squad` then test:
   ```bash
   curl -N -X POST https://<project>.supabase.co/functions/v1/run-squad \
     -H "Authorization: Bearer <anon-key>" \
     -H "Content-Type: application/json" \
     -d '{"squad_slug":"dev-squad","user_message":"Criar um sistema de login"}'
   ```
   Verify SSE events flow: `squad_start` → `agent_start` → `text` chunks → `agent_done` → `squad_done` → `[DONE]`
3. **Flutter**: `flutter run -d chrome`, navigate to `/squads/dev-squad`, submit a prompt
4. **Verify UI**: Each agent card appears sequentially with pulsing dot while active; collapses when done; orchestrator thinking badge updates between agents
5. **Verify persistence**: After run completes, check `squad_runs` and `agent_runs` tables in Supabase Studio have the expected rows with `status='done'`
6. **Verify MCP tools**: Seed the scrum-agent with `tools` JSON including `trello_create_card`; set `TRELLO_API_KEY` + `TRELLO_TOKEN` secrets; run a squad and confirm `tool_call` + `tool_result` SSE events appear, and the Trello card is actually created. Check the inline tool call row appears in the agent card UI.