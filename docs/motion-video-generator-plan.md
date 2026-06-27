# Motion Video Generator — Plano de Implementação

> Gerador de vídeos de motion design assistido por IA: o usuário descreve uma ideia,
> a API da Anthropic enriquece o conteúdo usando a skill de princípios de motion,
> o resultado é renderizado via Remotion (preview ao vivo no browser) e pode ser
> ajustado por um chat de edição. Encaixa no padrão atual de Edge Functions do
> Supabase consumidas pelo front.

**Status:** Fases 0–5 implementadas (fundações, MotionSpec + compositions, preview, enriquecimento IA, persistência, chat de edição) — marco de "versão funcional mínima" atingido. Próxima: Fase 6 (export mp4 no browser via WebCodecs).
**Stack alvo:** versão Vite/React (branch `redesign/component-library-ux`), que será a de produção.

---

## 1. Contexto e stack

A plataforma está migrando de Flutter Web para **Vite + React 19**. A versão Vite já é
um port maduro e feature-first, e é sobre ela que esta feature será construída.

| Camada | Tecnologia (versão Vite) |
|---|---|
| UI | React 19 + Vite 6 + TailwindCSS (design tokens próprios) |
| Estado de feature | Zustand |
| Data fetching / cache | TanStack React Query |
| Rotas | react-router-dom 7 |
| Validação | Zod |
| Backend | Supabase (auth, Postgres, Edge Functions) |
| Streaming | `src/core/sse/sse-client.ts` (SSE `data: {...}` próprio) |
| Testes | Vitest + Testing Library + Playwright |
| Deploy | Vercel (plano free) |

### Pontos de integração já existentes (a reusar)
- **`streamSSE`** (`src/core/sse/sse-client.ts`) — transporte pronto para o enriquecimento.
- **`useSquadRun`** (`src/features/squad/useSquadRun.ts`) — molde do padrão assíncrono
  (polling + status + cancel via ref), referência para o futuro render em cloud.
- **`useGeneration`** (`src/features/generation/useGeneration.ts`) — molde do padrão de
  streaming (`idle → connecting → thinking → streaming → done | error`).
- **React Query** (`src/core/org/org-queries.ts`, `useUserOrgs`) — padrão de fetch/cache.
- **Chat compartilhado** (`src/shared/components/chat/*`: `ChatComposer`,
  `ChatMessageBubble`, `TypingIndicator`) — reuso direto no chat de edição.
- **UI kit** (`src/shared/components/ui/*`) e **`web-download.ts`** (audio-visualizer).
- **Feature flag por org** — `organization.config.enabled_features`.

> ⚠️ Dívida conhecida: o `Sidebar.tsx` da versão Vite lista as ferramentas de forma
> *hardcoded* (sem feature-gating por org, diferente da versão Flutter). O plano
> endereça isso na Fase 0.3 / Fase 7.

---

## 2. Decisões de arquitetura

### 2.1 A restrição central
Renderizar Remotion **não cabe numa Edge Function** (Deno, com limite curto de
CPU/tempo). Render de vídeo precisa de Node + Chromium headless + ffmpeg, é pesado e
demora segundos a minutos. Portanto o pipeline tem **duas naturezas separadas**:

| Etapa | Natureza | Onde roda |
|---|---|---|
| Enriquecimento (Anthropic) | leve, streaming | Edge Function (padrão atual) |
| Renderização (Remotion) | pesado, assíncrono | browser (preview) / serviço dedicado (mp4 futuro) |

### 2.2 O que a Anthropic produz — **Spec-driven, híbrido depois**
A Anthropic **não escreve código**. Ela preenche um **`MotionSpec` (JSON)** validado por
Zod, e uma **biblioteca fixa de compositions Remotion** interpreta esse JSON.

- ✅ Seguro, determinístico, edição sã (editar JSON, não código).
- ✅ A skill de motion vira o **vocabulário/schema**: os `motionTokens`
  (durations `instant/fast/normal/slow/crawl`, easings `smooth/sharp/bounce/linear`,
  springs, distances) viram os **enums válidos do JSON**.
- ➡️ Modo *code-gen* (IA escreve TSX) fica como evolução futura ("híbrido depois"),
  apenas para casos que os componentes não cobrirem.

### 2.3 Render no Vercel free — o que é viável
Renderizar mp4 server-side no Vercel free **não é confiável** (timeout de ~60s, limite
de bundle, CPU/RAM) — é a própria recomendação do Remotion ("use Lambda, não
serverless"). A virada de chave é **separar preview de export**:

| | O que é | Custo | Onde roda |
|---|---|---|---|
| **Preview** | tocar a animação ao vivo a partir do MotionSpec | leve, instantâneo | **browser** (`@remotion/player`) |
| **Export mp4** | codificar o arquivo final | pesado | browser via WebCodecs (Fase 6) / serviço dedicado (Fase 8) |

Com o front em React, o **Remotion Player é um componente React nativo** — sem ponte,
sem iframe. O chat de edição fica **instantâneo e grátis**: muda o `MotionSpec` →
o Player re-renderiza na hora.

### 2.4 Regra de ouro: `src/remotion/` framework-agnostic
As compositions devem ser **React puro**, sem importar nada de `src/features`,
`src/core`, router ou Zustand. Motivo: na Fase 1–6 são consumidas pelo `<Player>`
(dentro do Vite); na Fase 8, pelo **bundler próprio do Remotion** (`bundle()`,
independente do Vite). Mantendo-as limpas, o mesmo código serve aos dois mundos.

---

## 3. O artefato central — `MotionSpec`

JSON que a IA gera, o chat de edição modifica, o Remotion consome e o banco persiste.
Esboço conceitual (schema completo a definir na Fase 1):

```jsonc
{
  "specVersion": 1,
  "meta": { "fps": 30, "width": 1080, "height": 1920, "format": "reel" },
  "theme": { "palette": ["#..."], "fonts": { "heading": "Inter" } },
  "scenes": [
    {
      "id": "s1",
      "durationInFrames": 60,
      "transitionIn": "fade",          // vocabulário Remotion (transitions.md)
      "elements": [
        {
          "type": "text",
          "content": "Sua headline",
          "enter": { "token": "slow", "easing": "smooth", "distance": "lg" }, // ← motionTokens da skill
          "emphasis": "guide-attention"  // ← princípio da skill
        }
      ]
    }
  ]
}
```

- `enter.token/easing/distance` usam **literalmente** os nomes da skill `motion-foundations`.
- Zod valida que a IA só usou valores do vocabulário.
- `calculateMetadata` soma os `durationInFrames` das cenas → duração total automática.
- Por ser JSON, diff e edição incremental (patch) são triviais.

---

## 4. Impedimentos e soluções

| # | Impedimento | Gravidade | Solução |
|---|---|---|---|
| 1 | Bundle do Remotion infla o app | Média | `lazy()` na rota `/motion-video` + gate `motion_video`. Quem não usa não baixa. |
| 2 | Vite ≠ bundler do Remotion (render server-side) | Média | Sem conflito: `<Player>` roda no Vite; render real (Fase 8) usa `bundle()` próprio sobre a **mesma `src/remotion/`** (por isso ela é React puro). |
| 3 | Export mp4 sem cloud | Alta | Fase 6 = WebCodecs no browser (experimental). Não forçar render no Vercel free. Preview já entrega o valor central. |
| 4 | Skill de motion é `motion/react`, não Remotion | Baixa | Usar como *vocabulário de design*, não código: tokens → enums Zod; tradução p/ `interpolate`/`spring` nas compositions. |
| 5 | IA gera spec inválido / quebra render | Média | Zod valida na saída da Edge Function + 1 retry de reparo. Edição via **patch**, não spec inteiro. |
| 6 | Versionamento do spec | Baixa | `specVersion` desde o dia 1; migrações triviais. |
| 7 | Sidebar Vite sem feature-gating | Planejamento | Gate do item Motion via `useOrgStore`/`useUserOrgs` (Fase 0.3 / 7). |
| 8 | Export WebCodecs experimental (qualidade/compat) | Média | Detectar suporte (`can-decode`), limitar resolução/duração, posicionar como "export rápido". mp4 de produção fica na Fase 8. |

---

## 5. Plano faseado

### Princípios
1. Cada fase entrega valor isolado e testável.
2. O `MotionSpec` é construído primeiro (tudo depende dele).
3. Render pesado fica por último (Fase 6 in-browser, Fase 8 cloud).
4. Reaproveitar padrões existentes, nunca inventar um segundo jeito.

---

### FASE 0 — Fundações e scaffolding
**Objetivo:** dependências, estrutura e feature flag, sem lógica.

**0.1 Dependências**
- Adicionar `remotion`, `@remotion/player`. (Adiar `@remotion/webcodecs` p/ Fase 6 e
  `@remotion/renderer`/`@remotion/lambda` p/ Fase 8.)
- Validar compatibilidade React 19 + Vite 6.

**0.2 Estrutura de pastas**
```
src/remotion/                 ← React PURO, framework-agnostic
  motion-spec.ts              ← schema Zod (Fase 1)
  MotionRoot.tsx              ← <Composition> raiz
  motion-tokens.ts            ← tradução tokens da skill → interpolate/spring
  compositions/
    SceneRenderer.tsx
    elements/{TextElement,ImageElement,ShapeElement}.tsx
src/features/motion-video/    ← React do app
  MotionVideoPage.tsx
  useMotionVideo.ts           ← Zustand store (padrão useSquadRun)
  motion-run.repository.ts    ← acesso Supabase (padrão squad-run.repository)
  PreviewPanel.tsx
  EditChatPanel.tsx
  HistoryPanel.tsx
```
Regra de ouro: `src/remotion/` não importa nada de `src/features`/`src/core`/router/Zustand.

**0.3 Feature flag**
- Estender `organization.config.enabled_features` com `motion_video`.
- Sub-tarefa: gate do item Motion no Sidebar via `useOrgStore`/`useUserOrgs` (escopo mínimo).

**Critério de aceite:** app builda com Remotion; rota stub `/motion-video` acessível; nada quebrado.

---

### FASE 1 — Contrato `MotionSpec` + biblioteca de compositions
**Objetivo:** renderizar um `MotionSpec` mockado num `<Player>` local, sem IA nem backend.

**1.1 Schema Zod (`src/remotion/motion-spec.ts`)**
- `specVersion: z.literal(1)`.
- `meta`: `fps`, `width`, `height`, `format` (`reel`/`feed`/`story` → presets de dimensão).
- `theme`: paleta, fontes (limitar a fontes carregáveis).
- `scenes[]`: `id`, `durationInFrames`, `transitionIn`, `elements[]`.
- `element` como **discriminated union** (`type: text | image | shape`), cada um com
  `enter`/`exit` usando os enums dos tokens da skill.
- Exportar `type MotionSpec = z.infer<...>` + `EXAMPLE_SPEC` (fixture).

**1.2 Tradução tokens → Remotion (`src/remotion/motion-tokens.ts`)**
- Mapear cada token p/ `interpolate`/`Easing`/`spring` (regras `timing.md`/`transitions.md`).
- Ex.: `slow` → duração em frames; `smooth` → `Easing.bezier(0.22,1,0.36,1)`; `lg` → 24px.

**1.3 Componentes de render**
- `MotionRoot.tsx`: `<Composition>` com `calculateMetadata` somando durações.
- `SceneRenderer.tsx`: `<Sequence>` por cena (`sequencing.md`) + `transitionIn`.
- `elements/*`: cada tipo anima via `useCurrentFrame` + tokens.

**1.4 Testes (Vitest)**
- `motion-spec.test.ts`: spec válido passa; easing inválido falha; spec sem cenas falha.
- Smoke test do `SceneRenderer` com `EXAMPLE_SPEC`.

**Critério de aceite:** página de dev mostra o `EXAMPLE_SPEC` rodando no `<Player>` com
controles; editar o fixture muda o vídeo. Zero backend.

**Impedimento:** fontes exigem carregamento explícito → restringir `theme.fonts` a um set
pré-carregado via `@remotion/google-fonts`.

---

### FASE 2 — Preview integrado na feature (com code-split)
**Objetivo:** `MotionVideoPage` real com o Player embutido e lazy-loaded.

**2.1 Página e rota**
- `MotionVideoPage.tsx` no layout das outras (input à esquerda / preview à direita).
- Registrar rota em `src/app/router.tsx` com `lazy()` + `<Suspense>` → Remotion fora do
  bundle principal.

**2.2 `PreviewPanel.tsx`**
- `<Player>` com `inputProps={{ spec }}` de estado local (mockado).
- Controles: play/pause, scrubber, troca de formato (reel/feed/story).

**2.3 Sidebar**
- Item "Motion Video" com gate `motion_video`, ícone `lucide-react`.

**Critério de aceite:** `/motion-video` mostra e controla um vídeo de exemplo; bundle
principal não cresce com Remotion (verificar com `vite build` + análise de chunks).

---

### FASE 3 — Pipeline de enriquecimento (Anthropic + skill)
**Objetivo:** input do usuário → `MotionSpec` gerado pela IA, via Edge Function.

**3.1 Edge Function `start-motion-run`**
- Recebe `{ input, org_id, format }`.
- System prompt: skill de motion (vocabulário) + JSON-schema do MotionSpec + "responda só JSON".
- Chama Anthropic (padrão `run-agent`); streaming SSE `data: {...}` (eventos
  `thinking`/`text`/`error`).

**3.2 Validação e reparo**
- Ao concluir, parsear + validar com o **mesmo Zod** (schema compartilhado ou paridade testada).
- Em falha: 1 retry de reparo. Persistir só spec válido.

**3.3 Integração no front**
- `useMotionVideo.ts` (Zustand): `generate(input)` chama `streamSSE(...)`, acumula, valida
  com Zod, seta `spec` → Player reflete.
- Estados: `idle → connecting → thinking → streaming → done | error`.

**Critério de aceite:** descrever uma ideia gera `MotionSpec` válido e o preview toca. Sem
persistência ainda.

**Impedimentos:** JSON inválido → Zod + retry (3.2) + teste de fixture malformado;
latência → feedback via streaming de `thinking`.

---

### FASE 4 — Persistência e histórico
**Objetivo:** runs salvos, recarregáveis, por organização.

**4.1 Schema Supabase**
- `motion_video_runs`: `id, org_id, status, input, format, motion_spec (jsonb),
  spec_version, video_url (null), error, created_at, updated_at`. RLS por org.

**4.2 Repository + React Query**
- `motion-run.repository.ts`: `createRun`, `updateSpec`, `fetchRun`, `listRunsByOrg`
  (padrão `squad-run.repository.ts`).
- `useMotionRuns()` (padrão `useUserOrgs`).
- `start-motion-run` passa a gravar o run (status + spec).

**4.3 `HistoryPanel.tsx`**
- Lista runs da org ativa; clicar restaura `spec` no preview.

**Critério de aceite:** gerar → recarregar página → run no histórico → clicar reabre o preview.

---

### FASE 5 — Chat de edição (patch-based)
**Objetivo:** ajustar o vídeo conversando, sem regenerar do zero.

**5.1 Edge Function `edit-motion-run`**
- Recebe `{ run_id, instruction, current_spec }`.
- IA devolve um **patch** (JSON Merge Patch / RFC 6902), não o spec inteiro.
- Aplica patch no servidor, revalida com Zod, salva novo spec com **versionamento**
  (nova row ou coluna `revisions jsonb[]`).

**5.2 Front**
- `EditChatPanel.tsx` reusando `shared/components/chat/*`.
- Cada mensagem → `edit-motion-run` → novo `spec` → Player re-renderiza na hora.

**Critério de aceite:** "deixa a 1ª cena mais lenta e troca a cor pra azul" altera só isso;
o resto permanece; preview atualiza instantâneo.

**Impedimento:** patch que invalida o spec → Zod rejeita com mensagem amigável; spec
anterior nunca é perdido (versionamento).

---

### FASE 6 — Export mp4 no browser (sem cloud)
**Objetivo:** baixar um arquivo, dentro da restrição "nada de cloud".

**6.1 WebCodecs**
- Instalar `@remotion/webcodecs`; `exportInBrowser(spec)` renderiza/encoda client-side.
- Botão "Exportar" com progresso; download via `web-download.ts` existente.

**6.2 Fallbacks e limites**
- Detectar suporte (`can-decode`); se ausente, desabilitar com aviso.
- Limitar resolução/duração para não travar a aba.

**Critério de aceite:** em navegador compatível, exporta `.mp4` assistível; se incompatível,
mensagem clara em vez de erro.

**Impedimento:** WebCodecs experimental → posicionar como "export rápido"; mp4 de produção
na Fase 8.

---

### FASE 7 — Polimento, gating e qualidade
- Feature-gating completo no Sidebar via `motion_video`.
- Estados de erro/vazio/loading com o UI kit (`Skeleton`, `Toast`).
- Acessibilidade: respeitar `prefers-reduced-motion` no preview.
- Testes: Vitest (schema, store, tradução de tokens) + 1 Playwright e2e
  (gerar → preview → editar).
- Limpeza: garantir `src/remotion/` sem dependências do app (lint rule/checagem).

---

### FASE 8 — (Futuro) Export de produção em cloud
**Quando aceitar infra.** Já desenhado para encaixar sem reescrever:
- O bundler do Remotion (`bundle()`) consome a mesma `src/remotion/`.
- Opções: **Remotion Lambda** (escala) ou **serviço Node dedicado** (simplicidade).
- `start-motion-run`/novo `render-motion` dispara o job; `motion_video_runs.video_url`
  é preenchido por callback; o front faz **polling** (padrão `useSquadRun`).

---

## 6. Ordem de dependência

```
F0 fundações
  └─ F1 MotionSpec + compositions  ◄── núcleo, tudo depende daqui
       └─ F2 preview no app
            └─ F3 enriquecimento IA
                 └─ F4 persistência ──┐
                      └─ F5 chat edição
                 F6 export browser ───┘ (paralela a F4/F5)
            F7 polimento (transversal)
F8 export cloud (futuro, plugável)
```

**Marco de "versão funcional mínima":** ao fim da **Fase 5**, o gerador está completo no
fluxo desejado — input → IA enriquece com a skill → vídeo renderizado (preview) → chat de
edição — rodando em Supabase + Vercel free, sem cloud. Export de arquivo entra na Fase 6
(browser); o mp4 de produção fica plugável na Fase 8.

---

## 7. Referências (skills instaladas)
- `motion-foundations` — tokens, springs, princípios (guiar atenção / comunicar estado /
  preservar continuidade), acessibilidade. **Fonte do vocabulário do `MotionSpec`.**
- `motion-patterns`, `motion-advanced` — padrões adicionais de animação.
- `remotion-video-creation` — 29 regras; relevantes aqui: `compositions`,
  `calculate-metadata`, `timing`, `sequencing`, `transitions`, `fonts`, `text-animations`,
  `can-decode`, `extract-frames`.
