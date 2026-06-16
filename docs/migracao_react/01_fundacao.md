# Fase 1 — Fundação do projeto React

Objetivo: ter um app React rodando, autenticado, navegando entre rotas vazias (placeholders), com sidebar dinâmica e tema — equivalente esqueleto do que `main.dart` + `app_router.dart` + `shell_scaffold.dart` fazem hoje.

## 1.1 Setup do projeto

- [ ] Criar projeto Vite + React + TypeScript (`npm create vite@latest -- --template react-ts`).
- [ ] Instalar dependências base: `@supabase/supabase-js`, `react-router-dom`, `@tanstack/react-query`, `zustand`.
- [ ] Configurar `.env` / `.env.local` com `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` (mesmos valores do `.env` Flutter atual — não rotacionar chaves).
- [ ] Configurar `vercel.json`/build do Vercel se o deploy continuar lá (equivalente ao `--dart-define` usado hoje em build).
- [ ] Decidir e configurar o UI kit/estilo (Tailwind recomendado, dado que não há design system documentado no Flutter — perguntar ao usuário se há preferência antes de avançar).

## 1.2 Cliente Supabase

- Criar `src/lib/supabaseClient.ts`:
  ```ts
  export const supabase = createClient(import.meta.env.VITE_SUPABASE_URL, import.meta.env.VITE_SUPABASE_ANON_KEY)
  ```
- Guardar também `supabaseUrl`/`supabaseAnonKey` exportados separadamente (precisos depois para montar as URLs das Edge Functions manualmente, igual ao Flutter — ver fase 2).

## 1.3 Autenticação

Equivalente a `auth_provider.dart` + `login_page.dart`.

- [ ] Hook `useAuth()` (ou store Zustand `authStore`) que:
  - Assina `supabase.auth.onAuthStateChange` (equivalente ao `authStateProvider` StreamProvider).
  - Expõe `user`, `session`, `loading`.
- [ ] Página `/login`:
  - Form email/senha controlado, chama `supabase.auth.signInWithPassword`.
  - Tratamento de erros em PT-BR replicando as mensagens atuais (credenciais inválidas, email não confirmado).
  - Manter o visual glassmorphism/gradiente se for mantida a identidade visual atual (decisão de produto — ver UI kit).

## 1.4 Roteamento + guard de auth

Equivalente a `app_router.dart`.

- [ ] Configurar React Router v6 com rotas:
  - `/login` (pública)
  - `/org-picker` (autenticada, fora do shell)
  - Layout shell (`<ShellLayout>`) com rotas filhas:
    - `/flows/:slug`
    - `/modules/:slug` (aceitar query param `?flow=`)
    - `/squads/:slug`
    - `/copy`
    - `/editorial`
    - `/instagram-post`
    - `/instagram-n3`
    - `/audio-visualizer`
- [ ] Implementar guard de redirect equivalente ao `RouterNotifier.redirect`:
  - Não logado + não em `/login` → redirect `/login`.
  - Logado + em `/login` → redirect `/org-picker`.
  - Não logado + em `/org-picker` → redirect `/login`.
  - Implementação sugerida: componente `<RequireAuth>` wrapper ou `loader` por rota reagindo ao `authStore`.
- [ ] `initialLocation` equivalente: ao entrar autenticado sem rota definida, ir para `/org-picker`.

## 1.5 Organização ativa

Equivalente a `organization_provider.dart`.

- [ ] `userOrgsProvider` → React Query: `useQuery(['orgs'], () => supabase.from('organizations').select('id,slug,name,config').order('created_at'))`.
- [ ] `activeOrgStore` (Zustand): estado `activeOrg: OrganizationModel | null`, método `setOrg(org)`.
  - Persistir `org.id` em `localStorage['metrifica_active_org_id']` (mesma chave usada hoje, para não perder a seleção de usuários que já têm o valor salvo — embora seja local storage do browser, não compartilhado entre apps, então pode ser uma chave nova também; **decidir se reaproveita a chave ou começa limpo**).
  - Ao carregar lista de orgs, se não há org ativa: tentar recuperar do localStorage, senão pegar a primeira.
- [ ] `orgEnabledFlowSlugsProvider` / `orgEnabledModuleSlugsProvider` → React Query dependente do `activeOrg.id`, buscando `organization_flows`/`organization_modules` filtrando por `enabled = true`.

## 1.6 Página Org Picker

Equivalente a `org_picker_page.dart`.

- [ ] Se 1 org só, ou já há org salva → auto-seleciona e redireciona para o primeiro flow disponível (ou `/squads/dev-squad` se não houver flows).
- [ ] Se múltiplas orgs sem seleção prévia → lista navegável (setas + Enter), chama `setOrg`.

## 1.7 Tema

Equivalente a `theme_provider.dart`.

- [ ] `themeStore` (Zustand) com `mode: 'light'|'dark'`, persistido em `localStorage['theme_mode']`.
- [ ] `toggleTheme()`, `setThemeMode(mode)`.
- [ ] Aplicar tema via classe no `<html>`/`<body>` (`dark` class, padrão Tailwind) ou via CSS variables, conforme decisão do UI kit.

## 1.8 Shell + Sidebar

Equivalente a `shell_scaffold.dart`. Este é o componente mais "lógico" da fundação — depende de várias fontes de dados simultâneas.

- [ ] Layout responsivo: sidebar expandida (220px) se `window.innerWidth > 960`, colapsada (68px, ícones com tooltip) caso contrário. Usar `useMediaQuery`-style hook ou `resize` listener.
- [ ] Seção de Flows: lista `flowsProvider` (fase 2) filtrado por `orgEnabledFlowSlugsProvider`; cada flow expansível mostrando seus módulos (filtrados por `orgEnabledModuleSlugsProvider`).
  - Replicar lógica de "qual flow deve estar expandido por padrão" baseado na rota atual (`/flows/:slug` ativa diretamente; `/modules/:slug?flow=hint` usa o hint).
- [ ] Seção "SQUADS": lista `squadsProvider`, visível apenas se `activeOrg.hasFeature('squad')` (default true se org nula/sem config).
- [ ] Itens estáticos condicionais por feature flag da org ativa: Personagem (`copy`), Editorial (`editorial`), Instagram Text Post (`instagram_post`), Instagram N3 (`instagram_n3`), Audio Visualizer (`audio_visualizer`, default true).
- [ ] Footer: avatar com inicial do email do usuário, seletor de org (dropdown, só se múltiplas orgs), toggle de tema, botão sair (`supabase.auth.signOut()` + redirect `/login`).

## Critério de aceite da fase

- Login funciona, redireciona corretamente conforme estado de auth.
- Org picker seleciona/persiste a organização ativa.
- Sidebar mostra os itens corretos conforme feature flags da org selecionada, navega entre rotas (mesmo que as páginas internas ainda sejam placeholders).
- Tema claro/escuro persiste entre reloads.
- Testado com pelo menos 2 organizações distintas (uma com poucas features habilitadas) para validar os flags.
