# Fase 3 — Module, Flow + Generation, Editorial

Objetivo: portar os módulos de menor risco técnico (CRUD + markdown + um motor de geração de IA genérico), que servem de base para entender o padrão de geração usado depois em Instagram Post/N3.

## 3.1 Module — `module_page.dart`

- Página `/modules/:slug`: carrega `ModuleModel` via `useModuleBySlug(slug)`.
- Toggle Editar/Visualizar:
  - Viewer: renderiza `content` com `react-markdown`, resolvendo `{{asset:alias}}` via `resolveAssetRefs` + `useAssetMap` (fase 2).
  - Editor: textarea de markdown raw + botão salvar (`useUpsertModule`), com toggle interno Editar/Preview.
- **Atenção ao salvar**: `module_ref` é `NOT NULL` no banco — sempre enviar esse campo no payload de upsert mesmo que o registro já exista (ver memória `modules-module-ref-not-null`).

## 3.2 Flow — `flow_page.dart`

- Página `/flows/:slug`: carrega `FlowModel` via `useFlowBySlug(slug)`.
- Busca módulos do flow via `useModulesBySlugsCsv(flow.moduleSlugs.join(','))`.
- Monta `extraContext` concatenando `## {nome}\n\n{conteúdo}` de cada módulo, separado por `---`.
- Renderiza `<GenerationPanel flowSlug={flow.slug} extraContext={extraContext} />` (componente compartilhado, ver 3.3).

## 3.3 Generation — motor de geração genérico

Equivalente a `generation_state.dart` + `generation_notifier.dart` + `generation_panel.dart` + `history_panel.dart`. Usado dentro de Flow, mas é um componente reutilizável.

### Store (Zustand) — substitui `GenerationState`/`GenerationNotifier`

Estado:
```ts
type GenerationStatus = 'idle'|'connecting'|'thinking'|'streaming'|'done'|'error';
type ImageStatus = 'idle'|'generating'|'done'|'error';
type ChatTurn = { userMessage: string; output: string };

interface GenerationState {
  status: GenerationStatus;
  thinking: string;
  output: string;
  turns: ChatTurn[];
  currentUserMessage: string;
  imageStatus: ImageStatus;
  imageUrl?: string;
  imageError?: string;
}
```
- `extractedImagePrompts`: regex que extrai blocos ` ```...``` ` do `output` — usados como prompts de imagem por slide.

Ações:
- `generate({flowSlug, userMessage, extraContext?})`: reseta e inicia stream.
- `refine({flowSlug, correction})`: monta nova mensagem (output anterior + instrução), empilha turno anterior em `turns`, reinicia stream — é o "chat" de refinamento iterativo.
- `_stream(...)`: usa `streamSSE` (fase 2) contra Edge Function **`run-flow`**, payload `{flow_slug, user_message, extra_context?}`. Eventos: `flow_start` (nome do flow), `thinking` (acumula), `text` (acumula no output), `error`. Timeout 35s por chunk.
- `generateImage({prompt, aspectRatio})`: `streamSSE` contra **`generate-image`**, payload `{prompt, aspect_ratio}`. Eventos: `queued`, `progress`, `image_url`, `error`. Timeout 130s.
- `restoreFromHistory(output, flowName?)`: reidrata o estado a partir de um histórico salvo.

### UI — `GenerationPanel`

- Seleção opcional de "Template de referência" (`useProposalTemplates(flowSlug)`) que pré-preenche a mensagem com scaffold contendo placeholders `[[texto]]`, com navegação Tab entre placeholders (selecionar próximo trecho `[[...]]` no textarea).
- Em modo dev (`import.meta.env.DEV`), pré-preencher com briefing fixo de exemplo para o flow `post-instagram` (mesmo comportamento do `kDebugMode` atual).
- Ao concluir geração:
  - Salvar automaticamente em `generation_history` (evitar duplicata se idêntico ao último salvo nos últimos 10s).
  - Criar rascunho automático em `posts` via `useCreatePostDraft`, extraindo `pillar` do texto via regex `PILAR:\s*(\S+)`.
- Extrair prompts de imagem do output e oferecer UI para gerar imagem (aspect ratio 1:1/4:5/9:16/16:9); ao concluir, fazer `useUpdatePostImageUrl` no post criado.
- Botão "Baixar como HTML": markdown → HTML via `marked`/`markdown-it` (extensões GFM), embrulhar em template HTML com CSS inline, `downloadFile` (fase 2).
- Suporte a múltiplos turnos de refinamento (componente `RefinementInput`).

### UI — `HistoryPanel`

- Painel lateral (slide-in da direita) listando `generation_history` (org ativa), com detalhe expandido, botão "Carregar no fluxo principal" (`restoreFromHistory`), exportar HTML, copiar, excluir.

## 3.4 Editorial — `editorial_page.dart`

- `PostModel`/`PostStatus` (fase 2) com label/cor em PT-BR (`draft`, `approved`, `scheduled`, `published`).
- Dashboard:
  - `PillarDashboard`: chips com contagem de posts por pilar nos últimos 30 dias (`usePillarStats`).
  - `StatusFilterBar`: filtro local por status (estado de UI puro, sem query).
  - `PostCard`: expansível, preview/imagem/markdown completo (`react-markdown`), ações condicionais por status:
    - `draft` → Aprovar (`approved`)
    - `approved` → Agendar (abre date picker, `scheduledAt`) → `scheduled`
    - `scheduled` → Publicado → `published`
  - Botões: copiar conteúdo, excluir (`useDeletePost`).

## Critério de aceite da fase

- Module: criar/editar conteúdo markdown de um módulo real, ver refletido no Flow que o usa.
- Flow: gerar conteúdo via IA real (endpoint `run-flow` de produção/staging) com extraContext correto, refinar pelo menos 1 vez.
- Geração de imagem funcionando ponta a ponta (gerar, ver preview, salvar no post).
- Download HTML produz arquivo válido e visualmente equivalente ao gerado pelo Flutter atual (comparar lado a lado).
- Editorial: criar draft (via geração), mover pelos status até `published`, conferir dashboard de pilares atualiza.
