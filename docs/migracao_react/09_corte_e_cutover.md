# Fase 9 — Paridade final, QA cruzado e cutover

Objetivo: validar que o app React é equivalente ao Flutter em todos os módulos, fazer o deploy definitivo, e desligar o app Flutter com segurança.

## 9.1 Checklist de paridade funcional (rodar os dois apps lado a lado)

Para cada módulo, repetir o mesmo roteiro de teste manual nos dois apps (Flutter atual em produção/staging vs React novo) com a **mesma organização e mesmos dados**, comparando resultado:

- [ ] Login + redirecionamento de auth (logado/deslogado, rotas protegidas).
- [ ] Org picker (1 org, múltiplas orgs, troca de org no footer da sidebar).
- [ ] Sidebar: feature flags por org corretas (testar com org com poucas features habilitadas).
- [ ] Tema claro/escuro persiste.
- [ ] Module: criar/editar/visualizar conteúdo, resolver `{{asset:alias}}`.
- [ ] Flow + Generation: gerar, refinar (múltiplos turnos), gerar imagem, baixar HTML, criar draft automático em Editorial.
- [ ] Editorial: dashboard de pilares, fluxo completo de status (draft → approved → scheduled → published), agendar com date picker.
- [ ] Copy: criar persona via chat, editar manualmente, aba Ferramentas com sessões por persona, sugestões pré-definidas.
- [ ] Squad: execução completa com polling, resume após reload, restaurar do histórico, calibração de tools.
- [ ] Instagram N3: gerar cards, enviar para Instagram Post, histórico local.
- [ ] Instagram Post: os 4 layouts, markup `[hl]/[b]/[i]/[u]`, 13 fontes, export PNG individual e em lote, auto-save de estilo, presets.
- [ ] Audio Visualizer: 3 modos de legenda, 3 tipos de fundo, export de vídeo com áudio sincronizado.
- [ ] Asset picker: upload, exclusão, seleção (usado dentro de Module/outros pontos).

## 9.2 Validação de integração com backend (não deve mudar, mas confirmar)

- [ ] RLS: confirmar que todas as queries do React respeitam as mesmas policies (testar com usuário sem permissão a uma org, deve falhar igual ao Flutter).
- [ ] Storage bucket `org-assets`: upload/signed URL/delete funcionando idêntico.
- [ ] As 6 Edge Functions (`run-flow`, `generate-image`, `run-agent`, `start-squad-run`, `run-squad-step`, `calibrate-tools`) **não precisam de nenhuma alteração** — só confirmar que o React monta a mesma URL/headers/payload exatos.
- [ ] Variáveis de ambiente: `VITE_SUPABASE_URL`/`VITE_SUPABASE_ANON_KEY` apontando para o mesmo projeto Supabase (não criar projeto novo).

## 9.3 Itens de produto a decidir antes do cutover

- [ ] Visual/design system definitivo (se for diferente do Flutter atual, validar com stakeholders antes, não depois).
- [ ] Decisão sobre migração ou não do histórico local existente (`ig_post_history`, `instagram_n3_history`, tema) — são `shared_preferences`/`localStorage` do navegador, não persistem entre apps diferentes; comunicar aos usuários que esse histórico local será reiniciado na troca (dados no Supabase — posts, personas, squads, etc. — não são afetados).
- [ ] Domínio/DNS: se o domínio do Flutter atual será reapontado para o build React (Vercel) ou se haverá período de transição com ambos no ar.

## 9.4 Deploy

- [ ] Build de produção React (`vite build`), validar bundle size e tempo de carregamento.
- [ ] Configurar projeto novo (ou atualizar o existente) no Vercel com as env vars corretas.
- [ ] Smoke test em produção com a organização real antes de anunciar a troca.
- [ ] Rollback plan: manter o build Flutter atual disponível (branch/deploy separado) por um período de segurança após o cutover, para reverter rapidamente se algo crítico passar pelo QA.

## 9.5 Desligamento do Flutter

- [ ] Só remover o código Flutter do repositório (ou arquivá-lo) após um período de estabilização do React em produção (sugestão: mínimo 1-2 semanas de uso real sem incidentes).
- [ ] Atualizar documentação do projeto (`CLAUDE.md`, memórias do projeto) para refletir a nova stack — note que as memórias atuais (`project_metrifica.md`, `feedback_no_build.md` sobre `fvm flutter analyze`) ficarão obsoletas e devem ser atualizadas/removidas quando o React for definitivo.

## Critério de aceite final

- Checklist completo da seção 9.1 sem divergências relevantes entre os dois apps.
- Nenhuma alteração necessária no schema/RLS/Edge Functions do Supabase.
- Deploy estável em produção por pelo menos 1-2 semanas antes de remover o código Flutter.
