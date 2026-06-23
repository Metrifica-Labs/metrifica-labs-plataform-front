# Metrifica Platform — Features e Capacidades (mapeamento completo)

> Documento gerado por leitura direta do código-fonte (branch `master`, app Flutter Web em `lib/`, backend Supabase em `supabase/`). Cobre todas as 11 features, toda a infraestrutura compartilhada (`core/`, `shared/`), todo o schema do banco (27 migrations) e todas as 12 Edge Functions. Objetivo: nenhuma capacidade real do sistema deve estar ausente daqui.

## Stack e arquitetura

- **Frontend:** Flutter Web (`pubspec.yaml`: `flutter_riverpod` para estado, `go_router` para rotas, `supabase_flutter` para backend, `google_fonts`, `flutter_markdown_plus`, `flutter_svg`, `fl_chart` *(declarado mas não utilizado em lugar nenhum do código — dependência morta)*).
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions em Deno) — multi-tenant por `organization_id`.
- **IA:** Anthropic Claude (chat/streaming, agentes, squads), Higgsfield AI (geração de imagem), Composio (integração Instagram/Meta Graph API), servidor Whisper próprio (transcrição de áudio).
- **Padrão de estado:** majoritariamente `FutureProvider`/`StateNotifierProvider` do Riverpod ligados direto a `supabase.from(table)`; quase não há camada de repositório/abstração — a query Supabase normalmente fica dentro do próprio arquivo do provider.
- **Sem App separado em Vite/React em produção:** existe uma migração React em branch separada (`docs/migracao_react`), mas o app ativo em `master` é 100% Flutter.

### Bootstrap (`lib/main.dart`)
1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Lê `SUPABASE_URL`/`SUPABASE_ANON_KEY` via `--dart-define` (produção/Vercel).
3. Se vazio, faz fallback para `.env` via `flutter_dotenv` (dev local).
4. `Supabase.initialize(url, anonKey)`.
5. `runApp(ProviderScope(child: MetrificaApp()))` — `MaterialApp.router` com `AppTheme.light`/`AppTheme.dark` e `appRouterProvider`.

### Roteamento (`lib/core/router/app_router.dart`)
`GoRouter` com `initialLocation: '/org-picker'`, `refreshListenable` ligado a `RouterNotifier` (guarda de sessão).

| Rota | Página | Dentro do `ShellRoute` (sidebar)? |
|---|---|---|
| `/login` | `LoginPage` | Não |
| `/org-picker` | `OrgPickerPage` | Não |
| `/flows/:slug` | `FlowPage` | Sim |
| `/modules/:slug` (aceita `?flow=<slug>`) | `ModulePage` | Sim |
| `/squads/:slug` | `SquadPage` | Sim |
| `/copy` | `CopyPage` | Sim |
| `/editorial` | `EditorialPage` | Sim |
| `/instagram-post` | `InstagramPostPage` | Sim |
| `/instagram-n3` | `InstagramN3Page` | Sim |
| `/audio-visualizer` | `AudioVisualizerPage` | Sim |
| `/video-caption` | `VideoCaptionPage` | Sim |

Guarda (`RouterNotifier.redirect`): apenas checa presença de sessão (`supabase.auth.currentSession`) — não logado fora de `/login` → redireciona `/login`; logado em `/login` → `/org-picker`; não logado em `/org-picker` → `/login`. Não há guarda de organização/membro no nível de rota nem rota 404 — visibilidade por org é feita a nível de provider/feature flag.

---

## Autenticação e multi-tenancy

### `auth` (`lib/features/auth/`)
- **Login** (`/login`): email/senha via `supabase.auth.signInWithPassword`. Mapeamento de erros para mensagens amigáveis em PT-BR (credenciais inválidas, e-mail não confirmado, e-mail já cadastrado). Tela com fundo gradiente escuro + card glassmórfico com animação de entrada.
- **Seleção de empresa** (`/org-picker`): lista as organizations visíveis ao usuário (`userOrgsProvider` → tabela `organizations`).
  - Auto-seleciona se houver apenas 1 org, ou se já existir uma org salva em `localStorage` (`metrifica_active_org_id`).
  - Caso contrário mostra lista navegável por teclado (setas + Enter) de orgs.
  - Após selecionar: redireciona para `/flows/<primeiro flow da org>` ou `/squads/dev-squad` se não houver flows.
  - Usuário sem nenhuma org: tela de erro fixa ("Contate o administrador"), sem saída.
- **Troca de empresa**: pelo rodapé da sidebar (`PopupMenuButton`), só visível com sidebar expandida e múltiplas orgs.
- **Feature flags por org**: `OrganizationModel.hasFeature(slug)` lê `organizations.config.enabled_features` (JSON) e controla quais itens aparecem na sidebar: `squad`, `copy`, `editorial`, `instagram_post`, `instagram_n3`, `audio_visualizer`, `video_caption` (os dois últimos com fallback `true` se a org não definir nada).
- **Visibilidade granular de flows/modules por org**: tabelas `organization_flows`/`organization_modules` (`enabled` boolean) — se não houver linhas, mostra tudo (sem filtro).
- Logout: `supabase.auth.signOut()` + redireciona `/login` (botão no rodapé da sidebar).
- **Sem modelo de usuário/membership no app** — identidade vem só do `User` nativo do Supabase Auth; vínculo org↔usuário é resolvido inteiramente via RLS no Postgres (`organization_members`).

---

## Features de produto (uma seção por módulo em `lib/features/`)

### 1. `copy` — Builder de Personas (Avatares) + Ferramentas de Copy (`/copy`)
Ferramenta de IA conversacional para criar e usar "personas" (avatar do cliente ideal):
- **Aba Personagens**: lista personas salvas (cartão com inicial, nome, preview do conteúdo); criar uma nova abre um chat com o agente `copy-avatar` que conduz uma entrevista guiada; ao final, "Salvar" gera uma ficha técnica estruturada em markdown (perfil, dores, desejos, objeções, sonhos, valores, linguagem, comportamento) e persiste em `personas`. Edição manual do markdown da persona também é suportada. Exclusão com confirmação.
- **Aba Ferramentas**: chat com o agente `copy-tools`, contextualizado pela persona selecionada (`persona_context` enviado em toda chamada). Chips de sugestão pré-prontos: Dualidades, 12 Passos, Criativos IAD, Capitão Gancho, VSL completa, Narrative Canvas.
- Histórico de sessões por persona (`copy_sessions`), com auto-save silencioso a cada resposta completa do assistente; permite recarregar uma sessão antiga.
- Streaming de respostas via SSE manual (`fetch` direto, não `supabase.functions.invoke`) contra a Edge Function `run-agent`.
- Botão de copiar resposta, indicador de "digitando" (3 pontos pulsantes), renderização markdown das respostas da IA.

### 2. `editorial` — Pipeline editorial de posts (`/editorial`)
Dashboard de gestão dos posts gerados pelas outras features (geração de conteúdo, Instagram):
- Pipeline de status linear e unidirecional: **Rascunho → Aprovado → Agendado → Publicado** (cada card mostra só a próxima ação possível, sem "voltar").
- Agendamento abre `showDatePicker` (hoje até +365 dias); selecionar data já marca `status=scheduled` e grava `scheduled_at`.
- Ações por post: aprovar, agendar, copiar conteúdo, excluir.
- Dashboard de "pilares" (`pillar`) dos últimos 30 dias — chips com contagem por pilar (calculado no cliente a partir de uma query simples, sem agregação no servidor).
- Filtro por status (chips horizontais: Todos + um por `PostStatus`).
- Cartão expansível com preview truncado (100 chars), imagem de capa (com fallback gracioso se a URL falhar) e corpo completo em markdown.

### 3. `flow` — Wrapper de geração por slug (`/flows/:slug`)
Tela fina, genérica, por slug: carrega um `FlowModel` (`flows` table), monta `extraContext` concatenando o `content` de todos os `modules` vinculados ao flow (`module_slugs`) como blocos markdown `## Nome\n\nconteúdo`, e renderiza o painel de geração (`GenerationPanel`, da feature `generation`) com esse contexto. É a "casca" usada para qualquer fluxo nomeado de geração de conteúdo (ex.: `post-instagram`).

### 4. `generation` — Painel de geração de conteúdo por IA (embutido em `flow`)
Não é uma rota própria — é um painel (`GenerationPanel`) reutilizado dentro de `FlowPage`. Capacidades:
- Seleção de **template de referência** (scaffold) por flow (`proposal_templates`), com placeholders `[[campo]]` que podem ser navegados via Tab.
- Geração via streaming (Edge Function `run-flow`), com seções de "pensamento" (thinking) visíveis durante a geração.
- **Refinamento conversacional**: corrigir a saída anterior com uma instrução nova, mantendo o histórico de turnos (`turns`).
- **Geração de imagem** associada ao conteúdo: extrai prompts de imagem de blocos de código no output, escolhe proporção (1:1, 4:5, 9:16, 16:9) e chama a Edge Function `generate-image` (Higgsfield Soul).
- Auto-cria um **rascunho de post** (`posts`, via `editorial`'s `PostsRepository`) a cada geração concluída, extraindo o `pillar` do texto por regex (`PILAR:\s*(\S+)`); ao gerar imagem depois, atualiza `image_url` desse post.
- Histórico de gerações (`generation_history`, até 50, com painel lateral de restauração) e exportação do output como HTML estilizado para download.

### 5. `instagram_n3` — Chat de conteúdo "N3" (`/instagram-n3`)
Assistente conversacional (multi-turno) especializado em posts estruturados de carrossel (formato "N3": 1/9 "O Método", 2/9 "A Vida Após", 3/9 "O Contraponto", 10/9 "Aplicação Real"), sugestões de bio, legendas e roteiros de "discurso"/método de vendas.
- Detecta e extrai um bloco JSON de cards (`{post_type, cards:[{card, objetivo, headline, body}]}`) embutido na resposta da IA e renderiza um **visualizador de cards paginado** inline (prev/next, copiar tudo).
- Botão **"Text Post"** envia os cards gerados direto para a feature `instagram_post` (via `pendingN3SlidesProvider`, ponte de estado compartilhada) para edição visual/exportação.
- Streaming via Edge Function `run-flow` com `flow_slug: 'instagram-n3'`.
- Histórico local (`SharedPreferences`, até 20 entradas) — existe na camada de dados mas não tem botão de acesso na UI atual.

### 6. `instagram_post` — Editor visual de carrossel/post + publicação (`/instagram-post`)
A feature mais extensa do app: gera texto via IA (single-shot, não chat) e renderiza/exporta/publica visualmente o carrossel.
- **Canvas fixo** 432×540 (proporção 4:5, padrão Instagram), exportado em PNG a `pixelRatio: 2.5` (~1080×1350px).
- **5 layouts visuais por slide** (`SlideLayout`):
  1. **Type 1 – Text Post**: header de perfil opcional (avatar, nome, @handle, selo verificado), imagem acima/abaixo do texto, contador `i/total` + seta.
  2. **Type 2 – Image Cover**: imagem de fundo full-bleed + gradiente, 4 variantes (`logoMid`, `logoTop`, `subtitleTop`, `logoTopInline`), texto de "arraste" opcional.
  3. **Type 3 – Text Grid**: imagem de fundo + grade de texto 2×2 (cada célula com negrito/alinhamento independentes, espaçamento ajustável).
  4. **Type 4 – Image Stack**: duas imagens empilhadas 50/50 com textos sobrepostos (título/subtítulo via split em `\n\n`).
  5. **Type 5 – Freestyle**: como o Type 1 mas sem header de perfil; única opção com posição de imagem **"no meio"** (entre headline e body).
- **Linguagem de marcação inline** aplicada a headline/body/grid/swipe text: `[hl]`/`[hl=#RRGGBB]` (destaque), `[c]`/`[c=#RRGGBB]` (cor do texto), `[b]` (negrito), `[i]` (itálico), `[u]` (sublinhado) — parser recursivo com suporte a tags aninhadas.
- 13 fontes do Google Fonts selecionáveis, 5 presets de estilo prontos (Clean, Dark, Editorial, Bold Blue, Punch).
- Cores resolvidas com precedência: override por slide → cor genérica do slide → cor global do estilo.
- Histórico local (`SharedPreferences`, 15 entradas) e auto-save de estilo a cada 60s — binários (imagens) nunca são persistidos no histórico/estilo salvo.
- **Conexão com Instagram pessoal** (OAuth via Composio): conectar conta, status de conexão (pendente/ativo/erro), sempre escopada ao **usuário atual** (nunca a outro membro da org).
- **Publicação**: upload das imagens exportadas para o bucket `instagram-publish-media`, criação de post (`posts`, com `image_urls` para carrossel), publicação imediata ou **agendamento** (data/hora); publicação imediata aciona a Edge Function `publish-instagram-post`; agendados são processados pelo cron `publish-instagram-post-due`.
- Regra de negócio explícita: quem cria o post é sempre quem publica (a Edge Function valida `created_by === auth.uid()` antes de publicar, mesmo que a tabela `posts` seja compartilhada pela org).

### 7. `module` — Editor de base de conhecimento (`/modules/:slug`)
Documentos de referência reutilizáveis em markdown (ex.: voz da marca, fatos da empresa) que alimentam o contexto de geração de outras features (via `flow`).
- Alternância visualizar/editar; preview markdown resolve referências de asset (`{{asset:alias}}` → URL assinada) só no modo leitura.
- Salvar faz `upsert` na tabela `modules`.

### 8. `squad` — Orquestração multi-agente (`/squads/:slug`)
Executa um pipeline sequencial de agentes de IA (ex.: PM → Arquiteto → Developer → QA) contra um prompt do usuário, com acompanhamento em tempo real.
- **Aba Execução**: inicia uma run, mostra timeline de agentes (status, "pensamento" com auto-scroll, chamadas de ferramenta, output em markdown), permite retomar (`Continuar execução`) ou reiniciar.
- **Aba Calibração**: testa, agente por agente, se cada ferramenta externa configurada (ex.: ferramentas do GitHub) está funcionando antes de uma execução real — status agregado "Tudo OK"/"Falhas detectadas".
- **Histórico**: lista runs anteriores (`squad_runs`/`agent_runs`), com restauração de uma run histórica para a view ativa.
- Polling do servidor a cada 3–5s (mais rápido se um agente estiver ativo); avança o pipeline chamando a Edge Function de "step" sem que o cliente espere a resposta completa.

### 9. `audio_visualizer` — Gerador de vídeo com visualizador de áudio (`/audio-visualizer`)
Ferramenta 100% client-side (sem renderização no servidor) para criar vídeos de "espectro de áudio" para redes sociais:
- Upload de áudio + imagem central opcional + fundo (sólido/gradiente/imagem) + legendas (upload de JSON/SRT/VTT ou transcrição automática via Edge Function `transcribe-audio`).
- Anel circular de barras de frequência reativo ao áudio (Web Audio API `AnalyserNode`), com cor, contagem de barras, raio, espessura, sensibilidade, velocidade de rotação e brilho configuráveis.
- 3 modos de legenda: segmento completo, karaokê (palavra destacada dentro da frase), palavra a palavra.
- 4 formatos de exportação: quadrado, retrato/story, paisagem; FPS configurável.
- **Pipeline de exportação**: grava via `MediaRecorder` + `captureStream`, sempre **re-codifica para MP4 de taxa de quadro constante via ffmpeg.wasm** (motivo documentado no código: vídeos de taxa variável fazem o Instagram/TikTok calcular duração errada e rejeitar o upload); se a normalização falhar, entrega o arquivo bruto com aviso ao usuário.
- **Presets** salvos por organização (`audio_visualizer_presets`) — apenas configuração numérica/cor/enum, nunca as imagens.

### 10. `video_caption` — Editor de legendas e cortes de vídeo (`/video-caption`)
Único módulo que **não usa Supabase** — conversa só com uma API local própria (Node, `http://localhost:3002` por padrão, configurável), portado de um pipeline externo de edição de vídeo.
- Upload de vídeo → transcrição (Whisper) + sugestão automática de cortes e legendas pelo backend local.
- Editor com abas: **Cortes** (criar/editar/excluir cortes manuais ou sugeridos), **Legendas** (detecta "gaps" de fala sem legenda e permite regenerar; identifica legendas com mais de 2 linhas e oferece "Reotimizar"/dividir), **Segmentos** (gerencia clipes de "outro" anexados na exportação e visualiza os trechos "mantidos" após os cortes), **Análise** (notas de IA sobre a edição), **Estilo** (fonte, tamanho, posição, cor de texto/fundo da legenda).
- **Reflow inteligente de legendas**: repacking baseado em timing de palavra, respeitando pausas naturais de fala (gap > 0.7s), preservando legendas editadas manualmente (sem timing) como estão.
- Exportação de vídeo completo (corte + legenda aplicados) ou de segmentos individuais, com rotação em incrementos de 90° e estilo de legenda convertido para proporções independentes de resolução antes de enviar ao backend.

---

## Infraestrutura compartilhada (`lib/core/`, `lib/shared/`)

### Sidebar / Shell (`lib/shared/widgets/shell_scaffold.dart`)
Único "chrome" do app — não há topbar separada. Sidebar retrátil (220px expandida / 68px compacta, breakpoint 960px), com:
- Logo + nome da organização ativa.
- Lista de Flows (expansíveis, mostrando Modules filhos conforme `organization_flows`/`organization_modules`).
- Seção Squads (gate por feature flag `squad`).
- Itens fixos com gate por feature flag: Personagens (`/copy`), Editorial (`/editorial`), Instagram Text Post (`/instagram-post`), Instagram N3 (`/instagram-n3`), Audio Visualizer (`/audio-visualizer`, default ativo), Video Caption (`/video-caption`, default ativo).
- Rodapé: troca de organização (se houver mais de uma), avatar com inicial do e-mail, alternância de tema claro/escuro, sair.

### Asset picker (`lib/shared/widgets/asset_picker.dart`)
Bottom sheet para inserir imagens da empresa em conteúdo markdown: upload de imagem (PNG/JPEG/WEBP/SVG/GIF) com definição de um "alias" (ex.: `logo`), referenciável no texto como `{{asset:logo}}`, resolvido para uma URL assinada de 1 ano (`org_assets` + bucket `org-assets`).

### Design system (`lib/core/theme/app_theme.dart`)
Único arquivo de tema, Material 3, fonte **Inter** (Google Fonts). Sem arquivo de espaçamento/tokens dedicado — valores hardcoded por widget. Paleta:

| Token | Hex | Uso |
|---|---|---|
| Primária | `#6366F1` | indigo, ambos os temas |
| Secundária | `#0EA5A4` | teal, ambos os temas |
| Fundo escuro | `#0F0F14` | scaffold dark |
| Cartão escuro | `#16161F` | surface dark |
| Borda escura | `#1E1E2E` | outline/inputs dark |
| Fundo claro | `#F1F5F9` | scaffold light |
| Cartão claro | `#FFFFFF` | surface light |
| Borda clara | `#E2E8F0` | outline light |
| Sidebar escura | `#0C0C12` | só na sidebar |
| Sidebar clara | `#F8FAFC` | só na sidebar |

Cantos arredondados padrão: 8–12px em cards/inputs/botões. Não existe pasta de "primitives" de UI (`ui/`) — cada feature constrói seus próprios botões/cards direto sobre o `ThemeData`.

### Providers globais (`lib/core/providers/`)
- `authStateProvider`, `currentUserProvider`, `RouterNotifier` (guarda de sessão).
- `userOrgsProvider`, `ActiveOrgNotifier`/`activeOrgProvider` (org ativa, persistida em `localStorage`), `orgEnabledFlowSlugsProvider`, `orgEnabledModuleSlugsProvider`.
- `themeModeProvider` (claro/escuro, persistido em `SharedPreferences`, sem suporte a "seguir sistema").
- `assetMapProvider` + `resolveAssetRefs()` (resolução de `{{asset:alias}}`).

### Repositórios compartilhados (`lib/core/repositories/`)
Majoritariamente providers funcionais simples sobre `supabase.from(tabela)`: `flows`, `modules` (única com classe + `upsert`/`delete`), `agent_definitions`, `squad_definitions`, `proposal_templates`. `OrgAssetsRepository` é o único explicitamente escopado por org via injeção de `activeOrgProvider`, com upload/listagem/exclusão de assets e URLs assinadas com renovação.

---

## Backend Supabase — schema completo (27 migrations)

Multi-tenant por `organization_id`, com **uma exceção deliberada**: `instagram_connections` é escopada por `user_id = auth.uid()` (conexão Instagram é pessoal, nunca compartilhada entre membros da mesma org — reforçado em código no Edge Function de publicação).

### Tabelas

- **`agent_definitions`** — `id, slug (unique), name, role, system_prompt, llm_provider ('anthropic'), llm_model ('claude-haiku-4-5'), tools (jsonb), created_at`. Seeds: `pm-agent`, `architect-agent`, `dev-agent`, `qa-agent`.
- **`squad_definitions`** — `id, slug (unique), name, description, orchestrator_provider, orchestrator_model, orchestrator_prompt, agent_slugs (text[]), created_at`. Seed: `dev-squad`.
- **`squad_runs`** — `id, squad_slug, squad_name, initial_prompt, status (running/done/error), user_id, organization_id, created_at, completed_at`. RLS por org.
- **`agent_runs`** — `id, squad_run_id (FK cascade), agent_slug, agent_name, step_index, input, output, status (pending/running/done/rejected), started_at, completed_at`. Sem RLS (só service-role).
- **`organizations`** — `id, slug (unique), name, config (jsonb: enabled_features), invite_code (unique), created_at`. RLS: membro só vê suas orgs. Orgs conhecidas: `metrifica`, `speake`, `mirian`, `oliveira`.
- **`organization_members`** — PK composta `(user_id, organization_id)`, `role (owner/admin/member)`. Escritas só via função `join_org_by_code` (SECURITY DEFINER) ou migrations diretas.
- **`organization_modules`** / **`organization_flows`** — PK composta `(organization_id, slug)`, `enabled (bool)`. Somente leitura via RLS.
- **`generation_history`** — `organization_id` (FK). RLS granular: leitura/inserção por membro, **exclusão só por admin/owner** (`user_is_org_admin`).
- **`posts`** — `id, organization_id, flow_slug, content, image_url, image_urls (text[], carrossel), status (draft/approved/scheduled/published, CHECK), pillar, scheduled_at, ig_user_id, composio_connection_id, composio_container_id, publish_error, created_by, created_at, updated_at (trigger)`. RLS FOR ALL por org.
- **`org_assets`** — `id, organization_id, name, storage_path, public_url (na verdade signed URL), asset_type, alias (unique por org), created_by, created_at`.
- **`instagram_connections`** — `id, user_id (unique, FK), composio_connected_account_id, ig_user_id, ig_username, status (pending/active/disabled/error, CHECK), status_reason, created_at, updated_at`. **RLS por `user_id`, não por org.**
- **`audio_visualizer_presets`** — `id, organization_id, name, config (jsonb), created_by, created_at, updated_at`, único por `(organization_id, name)`.
- **`modules`**, **`flows`** — schema original pré-existente (não recriado nas migrations lidas); colunas confirmadas em uso: `modules(slug, name, module_ref, content)`, `flows(slug, name, description, module_slugs text[])`.

### Storage buckets
- **`org-assets`** (privado, 10MB, png/jpeg/webp/svg/gif) — path `{org_id}/{filename}`, políticas por membership.
- **`instagram-publish-media`** (público, 8MB, png/jpeg) — path `{user_id}/{filename}`; leitura pública necessária porque a Graph API do Instagram busca a imagem sem autenticação.

### Funções SQL
- `user_organization_ids()` — helper central de toda RLS por org.
- `join_org_by_code(invite_code)` — entrada por código de convite (SECURITY DEFINER).
- `set_updated_at()` — trigger genérico de `updated_at` (usado em `posts`, `instagram_connections`).
- `user_is_org_admin(org_id)` — usado na policy de exclusão de `generation_history`.

### Cron
- `pg_cron` + `pg_net` habilitados. Job **`publish-instagram-post-due`** roda a cada minuto, chamando a Edge Function homônima via `net.http_post` (credenciais guardadas em `vault`). É o único job agendado do banco.

---

## Edge Functions (Deno, `supabase/functions/`)

| Função | Disparo | O que faz |
|---|---|---|
| `run-agent` | chat (`copy`) | Chat de agente único com Anthropic, streaming SSE, opcionalmente injeta `persona_context` no system prompt. |
| `run-flow` | `flow`/`generation`/`instagram_post`/`instagram_n3` | Monta system prompt a partir dos `modules` de um `flow`, chama Anthropic em streaming; emite `flow_start` antes do texto. |
| `generate-image` | `generation`/`instagram_post` | Gera imagem via **Higgsfield AI** (`text2image/soul`), faz polling de status e devolve a URL final via SSE. |
| `transcribe-audio` | `audio_visualizer` | Proxy para um servidor Whisper próprio (`WHISPER_SERVER_URL`), envia áudio em multipart. |
| `start-squad-run` | `squad` | Cria a linha inicial em `squad_runs` (sem executar nada ainda). |
| `run-squad` | `squad` | Orquestração completa do squad em uma única requisição longa: orquestrador decide próximo agente, agentes usam ferramentas do GitHub, um "supervisor" valida cada output (regras determinísticas + fallback LLM) antes de aceitar; emite SSE rico (`tool_call`, `supervisor_decision`, `squad_done` etc.). |
| `run-squad-step` | `squad` | Versão stateless/poll-driven: avança **um** passo por chamada; recupera passos travados (>6min `running`), tem fallback para forçar push de arquivos se o Developer esqueceu, e devolve `{queued:true}` usando `EdgeRuntime.waitUntil`. |
| `calibrate-tools` | `squad` (aba Calibração) | Testa, isoladamente, cada ferramenta do GitHub (`github_create_repo`, `github_push_files`, etc.) contra um repositório de calibração dedicado. |
| `instagram-connect` | `instagram_post` | Inicia (ou reaproveita) conexão OAuth do Instagram do usuário via Composio; nunca aceita `user_id` do corpo da requisição — sempre resolve pelo JWT. |
| `instagram-connect-status` | `instagram_post` | Faz polling do status da conexão Composio e sincroniza com `instagram_connections`. |
| `publish-instagram-post` | `instagram_post` (botão "Publicar") | Publica um post específico, validando que quem chama é o `created_by` do post (mesmo a tabela `posts` sendo compartilhada por org). |
| `publish-instagram-post-due` | cron (a cada minuto) | Processa até 20 posts agendados (`status='scheduled' AND scheduled_at <= now()`) e publica cada um via Composio (single image ou carrossel). |

Toda a lógica de publicação no Instagram (criação de containers, carrossel, publicação) está centralizada em `_shared/instagram-publisher.ts`, usado tanto pelo endpoint manual quanto pelo cron job.

---

## Pontos de atenção identificados durante o mapeamento

- `fl_chart` está declarado no `pubspec.yaml` mas não é importado em nenhum lugar do código — não há gráficos no app hoje.
- `instagram_n3` tem uma camada de histórico local pronta (`n3HistoryProvider`) mas sem botão de acesso na UI atual.
- `instagramN3Provider` (`instagram_n3_notifier.dart`) parece não utilizado pela página (que usa `n3ChatProvider` diretamente).
- Em `squad`, os campos `orchestratorThinking` e `toolCalls` existem no modelo de estado mas não são preenchidos pelo notifier atual — provável funcionalidade parcial/planejada.
- `modules` e `flows` não têm `CREATE TABLE` em nenhuma migration lida (schema pré-existente, fora do controle de versão do repositório) — apenas as colunas observadas em uso estão documentadas aqui.
