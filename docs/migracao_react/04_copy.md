# Fase 4 — Copy (Personagens / Avatares)

Equivalente a `lib/features/copy/*`. Módulo de chat com IA para construir e usar "personas" (avatares de público), com persistência de sessão de chat no banco.

## 4.1 Personas — CRUD

- `PersonaModel` (fase 2): `id, orgId, name, content, createdAt, updatedAt`.
- Hooks: `usePersonas(orgId)`, `useCreatePersona()`, `useUpdatePersona()`, `useDeletePersona()` — tabela `personas`.
- `selectedPersonaStore` (Zustand, sem persistência) — equivalente a `selectedPersonaProvider`.

## 4.2 Chat com IA + persistência de sessão

Equivalente a `copy_chat_notifier.dart` — o componente central do módulo.

### Tipos
```ts
interface CopyChatMessage {
  role: 'user' | 'assistant';
  content: string;
  isStreaming?: boolean;
  createdAt: string;
}
```

### Store por contexto de chat (`createCopyChatStore({ agentSlug, personaContext?, orgId?, personaId? })`)

- Parametrizado por `agentSlug`: `'copy-avatar'` (chat "Jornada do Avatar", sem persona) ou `'copy-tools'` (chat livre com persona selecionada). Duas instâncias de store distintas compartilhando a mesma fábrica.
- **Persistência de sessão** na tabela `copy_sessions` (`org_id, persona_id, agent_slug, messages` JSONB, `updated_at`):
  - Ao montar (se `orgId` não-nulo), carregar a sessão mais recente que casa com `(org_id, agent_slug, persona_id)` — usar `.is('persona_id', null)` quando não há persona selecionada.
  - Ao final de cada resposta do assistente: upsert automático (insert se não há `sessionId` ainda; update caso contrário).
- **Streaming**: `streamSSE` (fase 2) contra Edge Function **`run-agent`**, payload `{agent_slug, messages, persona_context?}`. Eventos: `text` (acumula), `error`. Fim com `[DONE]`.
- `generatePersonaSheet()`: chamada adicional (não streaming acumulado, resposta única) ao mesmo agente pedindo para sintetizar toda a conversa numa "ficha técnica" em markdown — usada para persistir a Persona definitivamente após o chat "Jornada do Avatar".
- `personaSessionsProvider` equivalente: hook `usePersonaSessions(orgId, personaId)` — histórico de sessões do par `(org, persona, agent_slug='copy-tools')` para listagem.

## 4.3 Página — `copy_page.dart`

Duas abas:

1. **Personagens**:
   - Lista de personas (`usePersonas`).
   - Criar novo: abre chat "Jornada do Avatar" (`agentSlug='copy-avatar'`, sem persona) → ao salvar, chama `generatePersonaSheet()` e persiste via `useCreatePersona`.
   - Editar manualmente: textarea markdown raw (`useUpdatePersona`).
2. **Ferramentas**:
   - Seletor de persona + chat livre (`agentSlug='copy-tools'`, `personaContext = persona.content`).
   - Sugestões pré-definidas como botões de prompt rápido (strings fixas mencionando o nome da persona): "Dualidades", "12 Passos", "Criativos IAD", "Capitão Gancho", "VSL completa", "Narrative Canvas".

## 4.4 UI de chat compartilhada (`ChatScaffold`)

- Bolhas de mensagem com `react-markdown` + `remark-gfm` (suporte a tabelas, usado nas respostas).
- Indicador de digitação animado enquanto `isStreaming`.
- Botão copiar por mensagem.
- Reaproveitar este componente também na fase 6 (Instagram N3), que tem o mesmo padrão de chat.

## Critério de aceite da fase

- Criar uma persona nova via chat "Jornada do Avatar" ponta a ponta, validar que a ficha gerada e salva é coerente.
- Reabrir a página e confirmar que a sessão de chat é restaurada do banco (mesma conversa).
- Aba Ferramentas: trocar de persona, confirmar que carrega a sessão correspondente (ou inicia vazia se não existir).
- Validar que duas sessões diferentes (`copy-avatar` sem persona vs `copy-tools` com persona X) não se misturam.
