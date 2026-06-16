# Migração Flutter Web → React — Visão Geral

## Por que migrar

A app atual é Flutter Web (FVM 3.7.2+) com Riverpod + go_router + Supabase. O alvo é um SPA React equivalente, mantendo 100% do backend (Supabase: tabelas, RLS, Storage, Edge Functions) intacto. **Nada no Supabase muda** — a migração é só de front-end.

## Stack recomendada para o destino

| Camada | Escolha recomendada | Por quê |
|---|---|---|
| Framework | React 18 + Vite (SPA) | App é client-only, atrás de auth; sem necessidade de SSR/SEO. Vite = build rápido, fácil portar `--dart-define` → `import.meta.env.VITE_*` |
| Linguagem | TypeScript | Models tipados (equivalente aos models Dart), segurança em payloads de Edge Functions |
| Roteamento | React Router v6 | Equivalente direto ao go_router (ShellRoute, redirects, params de rota) |
| Estado servidor/cache | TanStack Query (React Query) | Substitui os `FutureProvider`/`AsyncNotifier` do Riverpod (orgs, flows, modules, squads, assets, posts, personas) |
| Estado cliente/UI | Zustand | Substitui `StateNotifier` (theme, active org, generation state, squad state, instagram_post style, n3, copy chat) |
| Supabase client | `@supabase/supabase-js` v2 | Mesmo client JS oficial, mesmas tabelas/RLS/Storage/Auth |
| Markdown | `react-markdown` + `remark-gfm` | Equivalente a `flutter_markdown_plus` (suporte a tabelas GFM usado no copy chat) |
| Markdown→HTML (export) | `marked` ou `markdown-it` | Equivalente a `package:markdown` (`ExtensionSet.gitHubWeb`) usado no "baixar como HTML" |
| Fontes | `@fontsource/*` ou Google Fonts via `<link>`/`next/font` style loader | Substitui `google_fonts` (13 fontes fixas + presets) |
| Canvas/export PNG | Canvas API 2D nativa (sem lib) | Para os 4 layouts do Instagram Post — replicar estratégia já usada no `audio_visualizer_engine.dart` (desenho manual, não html2canvas) |
| Áudio/vídeo | Web Audio API + MediaRecorder nativos | Zero dependências — portar `audio_visualizer_engine.dart` quase 1:1 para TS |
| Persistência local | `localStorage` direto + util próprio | Substitui `shared_preferences` (theme, ig_post history, n3 history, active org) |
| Estilo/UI kit | A definir com o usuário (Tailwind + componentes próprios, ou Mantine/Radix) | Não há um design system documentado no Flutter — decisão de produto, ver fase 1 |

## Princípio geral da migração

1. **Backend é fonte da verdade e não muda.** Todas as 6 Edge Functions, todas as tabelas, RLS, Storage bucket `org-assets` — permanecem exatamente como estão. O React só troca o cliente que fala com elas.
2. **Migração por módulo, de forma incremental e verificável.** Cada módulo do Flutter (`lib/features/*`) se torna uma fase isolada com critério de aceite próprio, permitindo validar contra o app antigo lado a lado antes de desligar o Flutter.
3. **Extrair os 3 padrões duplicados como utilitários únicos desde o início** (fase 2), em vez de duplicá-los por módulo:
   - `streamSSE(url, body, onEvent)` — substitui o parsing manual de SSE repetido em generation/copy/n3.
   - `downloadFile(bytes, filename, mime)` — Blob + `<a download>`.
   - `pickFile(accept): Promise<File>` — `<input type=file>` + FileReader.
4. **Instagram Post (canvas) e Audio Visualizer são os módulos de maior risco técnico** — tratados em fases dedicadas, com protótipo de fidelidade visual validado antes do resto da integração (histórico, auto-save, etc).
5. **Squad é o módulo mais simples de portar logicamente** (client "burro", só reflete snapshots do banco via polling) mas precisa do mesmo cuidado de UX (timeline, polling, resume).

## Fases (ver arquivos individuais para detalhe)

1. [`01_fundacao.md`](01_fundacao.md) — setup do projeto, auth, roteamento, shell/sidebar, tema, providers base
2. [`02_dados_e_utilitarios.md`](02_dados_e_utilitarios.md) — models TS, camada de dados (React Query), utilitários SSE/download/upload
3. [`03_modulos_crud_simples.md`](03_modulos_crud_simples.md) — Module, Flow+Generation, Editorial (CRUD + markdown, sem canvas)
4. [`04_copy.md`](04_copy.md) — Personas + chat (SSE) + sessões
5. [`05_squad.md`](05_squad.md) — orquestração multi-agente com polling
6. [`06_instagram_n3.md`](06_instagram_n3.md) — chat → cards parseados → ponte para Instagram Post
7. [`07_instagram_post.md`](07_instagram_post.md) — editor de carrossel com Canvas API (módulo de maior risco)
8. [`08_audio_visualizer.md`](08_audio_visualizer.md) — engine de áudio/vídeo client-side (Web Audio + MediaRecorder)
9. [`09_corte_e_cutover.md`](09_corte_e_cutover.md) — paridade final, QA cruzado, deploy, desligamento do Flutter

## Estimativa de complexidade relativa (não é cronograma)

| Módulo | Complexidade | Motivo |
|---|---|---|
| Fundação (auth/router/shell) | Média | Lógica de redirect e sidebar dinâmica por org/feature flags |
| Module / Flow / Editorial | Baixa | CRUD simples + markdown |
| Copy | Média | Chat SSE + persistência de sessão + 2 abas |
| Squad | Média | Polling + máquina de estados, mas sem UI visual complexa |
| Instagram N3 | Baixa-Média | Chat simples + parser de JSON |
| **Instagram Post** | **Alta** | 4 layouts de canvas, markup customizado, export pixel-perfect, 13 fontes, histórico local |
| **Audio Visualizer** | **Alta** | Web Audio API + Canvas render loop + MediaRecorder + parsing de legendas (JSON custom e SRT) |
| Cutover | Média | QA cruzado de todos os módulos, validação de RLS/Storage, DNS/deploy |
