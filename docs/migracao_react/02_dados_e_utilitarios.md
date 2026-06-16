# Fase 2 — Camada de dados e utilitários compartilhados

Objetivo: ter toda a tipagem (models), os hooks de dados (React Query) e os 3 utilitários de browser extraídos e testados isoladamente, antes de construir qualquer página de feature. Isso evita duplicar lógica entre os módulos 3 a 8.

## 2.1 Models (TypeScript)

Portar 1:1 de `lib/core/models/*.dart`. Usar `type`/`interface` simples + funções `fromRow(row): T` (equivalente a `fromJson`), sem necessidade de classes.

- `AgentDefinitionModel`: `id, slug, name, role, systemPrompt, llmProvider='crofai', llmModel='deepseek-v4-pro', toolNames: string[], createdAt?`. `toolNames` extraído de `tools` (array `{function:{name}}`, formato OpenAI tool-calling).
- `AgentRunModel`: `id, squadRunId, agentSlug, agentName, stepIndex, input, output?, status, startedAt?, completedAt?`.
- `FlowModel`: `id, slug, name, description?, moduleSlugs: string[], createdAt?`. `moduleSlugs` pode vir como array JSON ou string separada por espaço — replicar parsing defensivo.
- `ModuleModel`: `id, slug, name, content?, moduleRef?, updatedAt?, createdAt?`. **Atenção**: `module_ref` é `NOT NULL` no banco mesmo que o model trate como opcional — sempre enviar valor em inserts (já documentado em memória do projeto).
- `OrgAssetModel`: `id, organizationId, name, storagePath, publicUrl?, assetType='image', alias?, createdAt: Date`.
- `OrganizationModel`: `id, slug, name, enabledFeatures: string[]` (de `config.enabled_features`). Função `hasFeature(org, name)`.
- `ProposalTemplateModel`: `id, slug, name, content?, promptScaffold?, flowSlug?, createdAt?, updatedAt?`.
- `SquadDefinitionModel`: `id, slug, name, description?, agentSlugs: string[], createdAt?` (mesmo parsing defensivo array/string).
- `SquadRunModel`: `id, squadSlug, squadName?, initialPrompt, status, createdAt?, completedAt?`.
- `PostModel` (editorial): `id, organizationId, flowSlug, content, imageUrl?, status: PostStatus, pillar?, scheduledAt?, createdAt, updatedAt`. `PostStatus = 'draft'|'approved'|'scheduled'|'published'` com label/cor em PT-BR num mapa auxiliar.
- `PersonaModel` (copy): `id, orgId, name, content, createdAt, updatedAt`.

## 2.2 Camada de dados — React Query (substitui Repositories + FutureProvider)

Cada "repository" Dart se torna um arquivo `src/data/<entidade>.ts` exportando hooks `use*` baseados em `useQuery`/`useMutation`.

| Hook React Query | Tabela | Equivalente Dart |
|---|---|---|
| `useAgentDefinitions()` | `agent_definitions` | `agentDefinitionsProvider` |
| `useAgentsBySlugs(slugs)` | `agent_definitions` | `agentsBySlugListProvider` |
| `useFlows()` | `flows` | `flowsProvider` |
| `useFlowBySlug(slug)` | `flows` | `flowBySlugProvider` |
| `useModules()`, `useModuleBySlug(slug)`, `useModulesBySlugsCsv(csv)` | `modules` | `modulesProvider` etc. |
| `useUpsertModule()`, `useDeleteModule()` | `modules` | `ModulesRepository.upsert/delete` |
| `useOrgAssets(orgId)`, `useUploadOrgAsset()`, `useDeleteOrgAsset()`, `useRefreshAssetUrl()` | `org_assets` + Storage `org-assets` | `OrgAssetsRepository` |
| `useProposalTemplates(flowSlug)` | `proposal_templates` | `proposalTemplatesProvider` |
| `useSquads()`, `useSquadBySlug(slug)` | `squad_definitions` | `squadsProvider` |
| `usePosts(orgId)`, `usePillarStats(orgId)`, `useCreatePostDraft()`, `useUpdatePostStatus()`, `useUpdatePostImageUrl()`, `useDeletePost()` | `posts` | `posts_repository.dart` |
| `usePersonas(orgId)`, `useCreatePersona()`, `useUpdatePersona()`, `useDeletePersona()` | `personas` | `personas_repository.dart` |
| `useGenerationHistory(orgId)`, `useAddHistoryEntry()`, `useRemoveHistoryEntry()`, `useClearHistory()` | `generation_history` | `generation_history.dart` |
| `useSquadRunsHistory()`, `useAgentRunsForSquad(squadRunId)` | `squad_runs`, `agent_runs` | `squad_history.dart` |

Detalhes de queries específicas a preservar exatamente:
- `org_assets`: ordenar por `created_at desc`.
- `posts`: `WHERE organization_id=:orgId ORDER BY created_at DESC LIMIT 100`; stats de pilares filtram `created_at >= now() - 30 dias` e agregam no client.
- `generation_history`: lista últimas 50; `clear()` é um `DELETE WHERE id != ''` (delete tudo).
- Upload de asset: path `{orgId}/{timestamp}_{safeName}`, `storage.from('org-assets').upload(...)`, depois `createSignedUrl(path, 1 ano)`, depois insert na tabela com `organization_id, name, storage_path, public_url, asset_type, created_by, alias?`.

## 2.3 Resolver de assets em markdown

Equivalente a `asset_resolver_provider.dart`.

- `useAssetMap(orgId)`: monta `Record<alias, publicUrl>` a partir de `useOrgAssets` (apenas os com `alias` não-nulo).
- `resolveAssetRefs(markdown, assetMap)`: regex `\{\{asset:([^}]+)\}\}` → substitui pela URL; se alias não existe, mantém o placeholder intacto.

## 2.4 Utilitário SSE — `streamSSE`

Substitui o parsing manual duplicado em `generation_notifier`, `copy_chat_notifier`, `instagram_n3_chat`.

```ts
type SSEHandler = (event: { type: string; [k: string]: any }) => void;

async function streamSSE(url: string, body: unknown, onEvent: SSEHandler, opts?: { timeoutMs?: number }) {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${supabaseAnonKey}`,
      apikey: supabaseAnonKey,
    },
    body: JSON.stringify(body),
  });
  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      if (!line.trim()) continue;
      if (line === 'data: [DONE]') return;
      if (line.startsWith('data: ')) onEvent(JSON.parse(line.slice(6)));
    }
  }
}
```

- URL montada como `${supabaseUrl}/functions/v1/<nome>` (igual ao Flutter — **não existe** `supabase.functions.invoke` por causa do streaming).
- Timeout por chunk deve ser respeitado por endpoint: `run-flow`/`run-agent` ~35s, `generate-image` ~130s (geração de imagem é lenta).
- Tipos de evento por endpoint documentados na fase de cada módulo (generation: `flow_start/thinking/text/error`; copy/n3: `text/error`; image: `queued/progress/image_url/error`).

## 2.5 Utilitário de download — `downloadFile`

Substitui o padrão repetido em `post_export.dart`, `web_download.dart`, `generation_panel.dart`, `history_panel.dart`.

```ts
function downloadFile(bytes: Uint8Array | Blob, filename: string, mime: string) {
  const blob = bytes instanceof Blob ? bytes : new Blob([bytes], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
```

## 2.6 Utilitário de seleção de arquivo — `pickFile`

Substitui o padrão repetido em `asset_picker.dart`, `post_export.dart` (`pickImageBytes`), `web_download.dart` (`pickFileBytes`).

```ts
function pickFile(accept: string): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = accept;
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.click();
  });
}
```

- Para obter bytes: `await file.arrayBuffer()`.
- Aceitar lista usada hoje no asset picker: `image/png,image/jpeg,image/webp,image/svg+xml,image/gif`.

## 2.7 Detecção de SVG por assinatura de bytes

Equivalente a `logo_image.dart` — útil em qualquer lugar que renderize logo/imagem que pode ser SVG ou raster:

```ts
function isSvg(bytes: Uint8Array): boolean {
  const head = new TextDecoder().decode(bytes.slice(0, 64));
  return head.includes('<svg') || head.includes('<?xml');
}
```
Em React, ambos os casos (SVG e raster) podem ser renderizados com `<img src={URL.createObjectURL(blob)}>` — não precisa de componente separado como no Flutter (`SvgPicture.memory` vs `Image.memory`).

## Critério de aceite da fase

- Todos os hooks de dados compilam e retornam dados reais ao testar manualmente em uma página de debug temporária.
- `streamSSE` testado contra pelo menos um endpoint real (`run-flow`) recebendo eventos corretamente.
- `downloadFile`/`pickFile` testados manualmente (baixar um arquivo de teste, selecionar uma imagem).
- Nenhuma lógica de UI ainda — esta fase é só fundação de dados.
