# Blueprint: Consolidated UI Component Library + UX Redesign

- **Branch:** `redesign/component-library-ux` (created from `migration/vite-react-ts`, which already holds a complete Flutter→React+Vite+TS port with 65 passing Vitest tests).
- **Mode:** Direct mode — no `gh` CLI available in this environment. All steps land as commits on this single branch; no automated PR workflow. User pushes/opens PR manually when ready.
- **Repo:** Flutter app under `lib/` stays untouched. All work happens under `src/` (React 19 + Vite 6 + TS strict + Tailwind v3 + shadcn-style primitives).
- **Non-goal:** This is NOT a rewrite and NOT a scope-expansion to close the known fidelity gaps (Instagram Post tipos 2/4 variants, Audio Visualizer knob parity, Video Caption draggable timeline) documented in the prior migration. Those stay out of scope unless explicitly requested later — don't silently fix them while refactoring nearby code.

## Why this shape

Current state (verified by reading the branch, not assumed):
- `src/shared/components/ui/` has only 4 primitives: `Button.tsx`, `Card.tsx`, `Field.tsx`, `Controls.tsx` (the last is a grab-bag: `SectionCard`, `Chip`, `Stepper`, `Toggle`, `ImagePicker`, `ColorInput` all in one file).
- No `Dialog`, `Tabs`, `Select`, `Toast`, `Tooltip`, `Skeleton`, `EmptyState`, `Badge`, `DropdownMenu` exist anywhere. Every feature improvises its own inline markup/error states.
- Feature pages are wildly uneven in size: `InstagramPostPage.tsx` is 868 lines, `AudioVisualizerPage.tsx` is 401, vs `ModulePage.tsx` at 36. The big ones mix layout, state, and business logic in one file.
- Design tokens exist (`tokens.css`, Tailwind theme) but are only partially formalized — many components hardcode hex/opacity values instead of using the scale.
- `package.json` scripts: `npm run typecheck` (`tsc -b --noEmit`), `npm run lint` (`eslint .`), `npm test` (`vitest run`), `npm run build`.

## Dependency graph

```
Step 1 (tokens)
  ├─> Step 2 (feedback/layout primitives)  ─┐
  └─> Step 3 (form/overlay primitives)     ─┴─> Step 4 (shell/IA + FeaturePageLayout)
                                                      │
        ┌───────────────┬───────────────┬────────────┼───────────────┐
        v               v               v             v               v
   Step 5 (simple)  Step 6 (chat)  Step 7 (audio-viz) Step 8 (ig-post) Step 9 (video-caption)
        └───────────────┴───────────────┴─────────────┴───────────────┘
                                      v
                              Step 10 (final UX + verification pass)
```

Steps 2+3 run in parallel (disjoint new files, both depend only on Step 1's token names). Steps 5–9 run in parallel (disjoint feature directories, all depend on Step 4's shell + primitive APIs being final). Use separate git worktrees per parallel branch of work if dispatching sub-agents concurrently, then merge back into `redesign/component-library-ux` sequentially to avoid clobbering shared files (`router.tsx`, `Sidebar.tsx` are only touched in Step 4 — no other step should touch them).

**Caveat (verified, not just assumed):** `Controls.tsx` (rewritten in Step 3) has exactly two importers in the whole tree: `src/features/audio-visualizer/AudioVisualizerPage.tsx` (Step 7's file) and `src/features/instagram-post/controls.tsx` (Step 8's file). So Step 3 writes into Step 7's and Step 8's directories before they start — Step 3 must fully land (not just Steps 2+3+4) before Steps 7 and 8 begin, and Steps 7/8 should build on the import paths Step 3 already chose rather than re-migrating them.

## Verification policy: live-backend checks are best-effort, not exit-blocking

Several steps' verification sections call for a Playwright MCP walkthrough against `npm run dev` with a real Supabase session, or against the local video-caption Node API. These environments may not have a logged-in test session or a running local API available at execution time. For every step: the `npm run typecheck && npm run lint && npm test [&& npm run build]` gate is always exit-blocking — it must pass before the step is considered done. The live-backend/Playwright behavioral checks are best-effort: attempt them, but if no authenticated session or live backend is reachable, note "behavioral check not run — no live backend available, needs manual QA" in the commit message instead of blocking on it. Don't fabricate a passing visual check that wasn't actually run.

---

## Step 1 — Design token consolidation

**Depends on:** nothing. **Model:** strongest (architecture/naming decisions ripple through every later step). **Parallel group:** solo.

**Context brief:** The app already has a light/dark token system (`src/core/theme/tokens.css`, Tailwind `theme.extend` in `tailwind.config.ts`, semantic classes like `light-onSurface`, `dark-border`, `primary-soft`, `shadow-soft`, `shadow-glow-primary`). The gap is consistency: spacing, radius, and font-size are hardcoded ad hoc per component (e.g. `Button.tsx` uses `h-8`/`h-9`, `Controls.tsx` uses `text-[11px]`/`text-[13px]` magic values). This step formalizes the scale so every primitive built in Steps 2–3 pulls from the same source instead of inventing new magic numbers.

**Tasks:**
1. Read `tailwind.config.ts` and `src/core/theme/tokens.css` fully; list every hardcoded hex/px/opacity value currently duplicated across `src/shared/components/ui/*.tsx` and feature files (grep for `text-\[`, `#[0-9a-fA-F]{3,6}`, inline `style={{`).
2. Extend `tailwind.config.ts` `theme.extend` with a formal spacing/radius/font-size scale that covers the values already in use (don't invent new values — codify what's already there, e.g. confirm Tailwind's default `text-sm`/`text-xs` already cover the `11px`/`13px` cases before adding custom scale entries).
3. Add any missing semantic color tokens needed by Steps 2–3 (e.g. a `danger`/`warning`/`success` semantic pair for Toast/Badge, on top of the existing `primary`/`secondary`).
4. This step is purely additive — do not rename or remove any existing token/class name, only add new ones. Do not change any existing component's rendered output. No `.tsx` files change, only `tailwind.config.ts` and `tokens.css`.

**Files touched:** `tailwind.config.ts`, `src/core/theme/tokens.css`.

**Verification:** `npm run typecheck && npm run lint && npm test` (all must stay green — no `.tsx` changed, so this should be a no-op risk-wise). `npm run build` to confirm Tailwind config is still valid.

**Exit criteria:** New tokens exist and are documented (short comment block at top of `tailwind.config.ts` theme.extend listing the semantic groups). Zero visual regressions because zero components changed.

**Rollback:** `git revert` this commit; nothing downstream depends on removed tokens because nothing consumes them yet.

---

## Step 2 — Feedback & layout primitives

**Depends on:** Step 1. **Model:** default. **Parallel group:** A (with Step 3).

**Context brief:** No toast/notification system exists anywhere in the app — errors today are rendered as inline ad-hoc divs per feature (verify by grepping each feature for error-state JSX before assuming the pattern). This step builds the primitives that Steps 5–9 will use to replace those inline patterns, but does NOT wire them into any feature yet — that happens in Steps 5–9.

**Tasks:**
1. `src/shared/components/ui/Toast.tsx` + `src/shared/hooks/useToast.ts`: a zustand-backed toast store (mirror the pattern already used in `src/core/theme/theme-store.ts` for consistency) with `success`/`error`/`info` variants, auto-dismiss, and a `<ToastViewport />` mounted in `src/App.tsx` inside `<ThemeProvider>` and above `<RouterProvider>` (verified: the actual provider stack is `QueryClientProvider > ThemeProvider > RouterProvider` in `src/App.tsx`; `ShellScaffold` is only the authenticated-routes layout inside `router.tsx` and does NOT wrap `/login`/`/org-picker` — mounting there would mean toasts never show on those two routes, which Step 5 needs).
2. `src/shared/components/ui/Skeleton.tsx`: a simple pulsing placeholder block, sized via `className`.
3. `src/shared/components/ui/EmptyState.tsx`: icon + title + description + optional action button, for "no items yet" states (post list empty, persona list empty, history empty, etc.).
4. `src/shared/components/ui/Badge.tsx` (renamed/promoted): a generic badge plus a `StatusPill` variant for `posts.status` (draft/approved/scheduled/published) and `instagram_connections.status` (pending/active/disabled/error) — read `PostStatus` type in `src/features/editorial/posts.repository.ts` first so the variant names match exactly.
5. `src/shared/components/ui/Tooltip.tsx`: lightweight hover tooltip (no new dependency — implement with CSS/positioning consistent with the rest of the lib, which has no Radix dependency today; check `package.json` before reaching for a new library).

**Files touched:** new files only under `src/shared/components/ui/` and `src/shared/hooks/`; one mount point added to the app shell entry (`src/app/router.tsx` or wherever `ShellScaffold` is rendered — confirm exact location by reading it first, don't guess).

**Verification:** `npm run typecheck && npm run lint && npm test`. Manually mount each new primitive in a scratch location (e.g. temporarily in `ModulePage.tsx`) to eyeball it, then remove the scratch usage before committing — Steps 5-9 own the real integration.

**Exit criteria:** All 5 primitives exist, typecheck, and render without runtime errors when smoke-tested. Not yet consumed by any feature.

**Rollback:** `git revert`; nothing depends on these files until Step 4+.

---

## Step 3 — Form & overlay primitives

**Depends on:** Step 1. **Model:** default. **Parallel group:** A (with Step 2).

**Context brief:** `Field.tsx` and `Controls.tsx` already hold partial form primitives (`Toggle`, `ColorInput`, `Stepper`, `Chip` live in `Controls.tsx`; check `Field.tsx` for whatever input/label wrapper already exists). This step finishes the set and *consolidates* — it does not leave duplicate copies. Existing call sites of `Controls.tsx` exports get updated in this same step (small blast radius — confirm with `grep -rl "from .*Controls" src/` before starting) so there's no transitional dual-API period.

**Tasks:**
1. Read `Field.tsx` and `Controls.tsx` completely (already partially read — `Controls.tsx` has `SectionCard`, `Chip`, `Stepper`, `Toggle`, `ImagePicker`, `ColorInput`). Decide final file boundaries: e.g. `Select.tsx`, `Switch.tsx` (renamed from `Toggle`), `Stepper.tsx`, `ColorInput.tsx`, `ImagePicker.tsx` each as their own file under `ui/`; `SectionCard` and `Chip` are layout/display, consider whether they belong in `Card.tsx`/`Badge.tsx` instead of staying in a catch-all.
2. Add what's missing: `Dialog.tsx` (modal with backdrop, focus trap, Esc-to-close — needed by Step 8 for the Instagram publish/schedule flow and Step 9 for delete confirmations), `Tabs.tsx` (needed by Step 6's Copy page Personagens/Ferramentas tabs and Step 9's video-caption editor tabs), `DropdownMenu.tsx` (needed by Step 4's org switcher, currently a raw popup-style pattern per the Flutter docs — confirm current React equivalent before replacing it).
3. Update every existing import of `Controls.tsx`/`Field.tsx` exports to the new file locations in the same commit (no re-export shims — grep for all call sites first, this is a mechanical rename, not a redesign of the components' behavior).

**Files touched:** `src/shared/components/ui/{Select,Switch,Stepper,ColorInput,ImagePicker,Dialog,Tabs,DropdownMenu}.tsx` (new/split), deletes old `Controls.tsx` once empty, and its two confirmed importers: `src/features/audio-visualizer/AudioVisualizerPage.tsx` and `src/features/instagram-post/controls.tsx` (verified via grep — these are the only two files in the tree that import from `Controls.tsx`; re-grep before starting in case the tree has moved since this plan was written). Note: these two files are also the main subjects of Steps 7 and 8 — this step only updates their `Controls.tsx` imports to the new primitive paths, it does not do the broader layout refactor those steps own.

**Verification:** `npm run typecheck && npm run lint && npm test && npm run build`. Build must stay green since this step touches real call sites, not just additive files.

**Exit criteria:** No file still imports from a deleted `Controls.tsx`/old `Field.tsx` API shape. All existing tests pass unchanged (this step must not alter component behavior, only its file location/API ergonomics).

**Rollback:** `git revert`; since this step rewires real imports, revert restores the prior single-file API cleanly because it's one commit.

---

## ACTUAL STATE after Steps 1-4 landed (read this before Steps 5-9)

Steps 1-4 are committed on `redesign/component-library-ux`. Reality deviated from the original plan in ways that matter for Steps 5-9:

- **No `FeaturePageLayout` was built.** `PageHeader` already existed in `Card.tsx` (title/subtitle/eyebrow/actions) and is already used by `squad/SquadPage.tsx`, `flow/FlowPage.tsx`, and `instagram-post/InstagramPostPage.tsx`. Steps 5-9: adopt this existing `PageHeader` in pages that don't use it yet, don't build a new layout wrapper.
- **`Badge`, `EmptyState` already existed** in `Card.tsx` (not built fresh in Step 2). `Badge` now also accepts an optional `color` prop to override its built-in status map.
- **`Select`/`Textarea`/`Input`/`Label` already existed** in `Field.tsx` (not built fresh in Step 3).
- **`Controls.tsx` is deleted.** Its contents are now `ui/{SectionCard→moved into Card.tsx, Chip, Stepper, ImagePicker, ColorInput, Switch}.tsx`. The two files that imported it (`AudioVisualizerPage.tsx`, `instagram-post/controls.tsx`) were repointed to the new files but kept the old `Toggle` name via `export { Switch as Toggle }` / `import { Switch as Toggle }` — Steps 7 and 8 may rename these call sites to `Switch` directly while restructuring, or leave the alias; either is fine.
- **New primitives available:** `ui/Toast.tsx` + `hooks/useToast.ts` (mounted in `App.tsx`, use via `useToast().success/error/info(message)`), `ui/Skeleton.tsx`, `ui/Tooltip.tsx`, `ui/Dialog.tsx`, `ui/Tabs.tsx`, `ui/DropdownMenu.tsx`.
- **Sidebar footer** now has a real org switcher (didn't exist before) and tooltips on the theme/logout buttons.
- **No sidebar collapse/breakpoint exists** in this React port (contrary to what the Flutter docs describe) — this is a pre-existing gap, not something to fix as part of Steps 5-9 unless asked.

---

## Step 4 — Shell & navigation IA redesign (COMPLETED — see actual-state note above)

**Depends on:** Steps 2, 3. **Model:** strongest (UX/information-architecture judgment calls). **Parallel group:** solo (touches the only shared shell files — no other step may touch `Sidebar.tsx` or `router.tsx`).

**Context brief:** Per `docs/features-e-capacidades.md`, the sidebar is the only "chrome" (no separate topbar) and already groups Flows/Modules/Squads dynamically plus a fixed "Ferramentas" section gated by feature flags. The ask is to "organize the UI much better to facilitate use" — read as: reduce visual clutter, make every feature page's header consistent, and make the org/theme/logout controls in the sidebar footer use the new `DropdownMenu`/`Tooltip` from Step 3 instead of the current raw button row.

**Tasks:**
1. Build `src/shared/components/FeaturePageLayout.tsx`: a consistent wrapper every feature page adopts — title, optional description, primary action slot (top-right), optional breadcrumb/back-link, content slot. This is the single biggest lever for "organize a UI muito melhor" since today each page (`EditorialPage.tsx`, `VideoCaptionPage.tsx`, etc.) builds its own header markup independently.
2. Redesign `Sidebar.tsx` footer (org switcher, theme toggle, logout) using `DropdownMenu` for the org switcher (replacing whatever ad-hoc popup exists) and `Tooltip` on icon-only buttons.
3. Re-check collapse/expand behavior (220px/68px breakpoint at 960px per the docs) still works after the footer rework — don't regress responsive behavior while touching this file.
4. Do NOT add new routes, a command palette, or restructure `router.tsx`'s route table unless a concrete IA problem is found during this step — keep scope to chrome/layout, not routing.

**Files touched:** `src/shared/components/Sidebar.tsx`, new `src/shared/components/FeaturePageLayout.tsx`, possibly `src/shared/components/ShellScaffold.tsx`.

**Verification:** `npm run typecheck && npm run lint && npm test && npm run build`. Visual check: run `npm run dev`, use the Playwright MCP tool to navigate to at least 3 routes and screenshot the shell (sidebar collapsed and expanded) to confirm no layout breakage.

**Exit criteria:** `FeaturePageLayout` exists and is ready for Steps 5–9 to adopt; sidebar footer uses new primitives; collapse/expand still works at the documented breakpoint.

**Rollback:** `git revert`; Steps 5–9 haven't started consuming `FeaturePageLayout` yet if this is reverted before they land.

---

## Step 5 — Migrate simple pages (auth, module, flow, editorial)

**Depends on:** Step 4. **Model:** default. **Parallel group:** B (with Steps 6, 7, 8, 9).

**Context brief:** These are the smallest, lowest-risk pages (36–218 lines). `EditorialPage.tsx` is the most substantive of the four — it has a linear status pipeline (Rascunho→Aprovado→Agendado→Publicado), a pillar dashboard, and status filter chips, all good candidates for the new `Badge`/`StatusPill`/`Tabs`/`EmptyState` primitives.

**Tasks:**
1. Wrap each of `LoginPage.tsx`, `OrgPickerPage.tsx`, `ModulePage.tsx`, `FlowPage.tsx`, `EditorialPage.tsx` in `FeaturePageLayout` where it makes sense (Login/OrgPicker are pre-shell, full-screen flows — confirm whether `FeaturePageLayout` even applies to them or if they stay bespoke; don't force-fit it).
2. `EditorialPage.tsx`: replace inline status chip markup with `StatusPill`, replace the 30-day pillar count chips with `Badge`, add `EmptyState` for zero-posts case, add `Toast` calls on approve/schedule/delete success and failure (check current error handling first — likely silent or console-only today).
3. `ModulePage.tsx`/`FlowPage.tsx`: light touch — adopt `FeaturePageLayout`, replace any raw loading text with `Skeleton`.

**Files touched:** `src/features/auth/*.tsx`, `src/features/module/ModulePage.tsx`, `src/features/flow/FlowPage.tsx`, `src/features/editorial/EditorialPage.tsx`.

**Verification:** `npm run typecheck && npm run lint && npm test`. Playwright walkthrough of `/login`, `/org-picker`, `/editorial`, a `/modules/:slug`, a `/flows/:slug` — confirm the approve/schedule/delete actions in Editorial still work end to end against the dev Supabase instance and that toasts fire.

**Exit criteria:** All 5 pages typecheck/build, no behavior change to data flow (same repository calls), only presentation + new feedback states.

**Rollback:** `git revert` this commit independently — no other parallel step (6/7/8/9) touches these files.

---

## Step 6 — Migrate chat-style features (copy, instagram-n3, squad, generation)

**Depends on:** Step 4. **Model:** default. **Parallel group:** B.

**Context brief:** Four features share a "streaming chat" shape: `CopyPage.tsx` (192 lines, two tabs: Personagens/Ferramentas), `InstagramN3Page.tsx` (90 lines), `SquadPage.tsx` (75 lines, has its own Execução/Calibração/Histórico tabs per the docs), `GenerationPanel.tsx` (137 lines, embedded in `FlowPage.tsx`). All of them stream SSE responses and show a "typing" indicator per the docs — check whether that's already a shared piece of code or duplicated 4 times before deciding whether to extract a shared `ChatMessage`/`TypingIndicator`/`StreamingMarkdown` component.

**Tasks:**
1. Grep all 4 files for duplicated "typing indicator" / message-bubble markup; if duplicated, extract one shared set of chat primitives (location: `src/shared/components/chat/` since this is chat-shape, not generic enough for `ui/`).
2. Replace `CopyPage.tsx`'s and `SquadPage.tsx`'s hand-rolled tab switches with the new `Tabs` primitive from Step 3.
3. Add `Skeleton` for initial history load (personas list, copy sessions, squad run history) and `EmptyState` for zero-history cases.
4. Add `Toast` on stream/connection errors (check current error handling in `useCopyChat.ts`, `useN3Chat.ts`, `useSquadRun.ts`, `useGeneration.ts` — likely inline error state today).

**Files touched:** `src/features/copy/CopyPage.tsx`, `src/features/instagram-n3/InstagramN3Page.tsx`, `src/features/squad/SquadPage.tsx`, `src/features/generation/GenerationPanel.tsx`, `src/features/generation/HistoryPanel.tsx`, possibly new `src/shared/components/chat/*`.

**Verification:** `npm run typecheck && npm run lint && npm test` — confirm `src/core/sse/sse-client.test.ts` stays green as the non-visual safety net for streaming logic. Playwright (best-effort, see verification policy above): drive at least one full chat turn on `/copy` and `/instagram-n3` against a real flow to confirm SSE streaming still renders correctly through the refactored markup (streaming UI is the highest regression risk here — a misplaced `key` or remount can break incremental rendering).

**Exit criteria:** Streaming still renders token-by-token (not just on completion) after refactor; all 4 pages typecheck/build.

**Rollback:** `git revert`; isolated from Steps 5/7/8/9.

---

## Step 7 — Migrate audio-visualizer page

**Depends on:** Step 4. **Model:** default. **Parallel group:** B.

**Context brief:** `AudioVisualizerPage.tsx` (401 lines) is UI/controls only — `audio-visualizer-engine.ts` (the actual canvas rendering) and `captions.ts` (tested, has `captions.test.ts`) must NOT change in this step. The page has many numeric controls (bar count, radius, sensitivity, rotation speed, glow) that map directly to `Stepper`/`ColorInput`/`Switch` from Step 3, and 3 caption modes (segmento completo/karaokê/palavra a palavra) that map to `Tabs`.

**Tasks:**
1. Split `AudioVisualizerPage.tsx` into composable sections: an uploads section, a ring-controls section, a background section, a captions section, a presets section — using the new form primitives instead of raw inputs.
2. Confirm zero changes to `audio-visualizer-engine.ts`, `captions.ts`, `audio-visualizer-config.ts`, `audio-visualizer-presets.ts`, `transcription.service.ts`, `web-download.ts` — this step is page-layer only.
3. Add `EmptyState` for "no audio uploaded yet", `Skeleton` during transcription.

**Files touched:** `src/features/audio-visualizer/AudioVisualizerPage.tsx` only (plus possibly new sub-component files within the same feature directory, e.g. `AudioVisualizerControls.tsx`).

**Verification:** `npm run typecheck && npm run lint && npm test` (existing `captions.test.ts` must stay green untouched). Playwright: upload a test audio file, confirm the frequency ring still renders and reacts, confirm an export still produces a video file.

**Exit criteria:** Engine/logic files have zero diff (`git diff` on those specific files should be empty); only the page/controls layer changed.

**Rollback:** `git revert`; isolated from Steps 5/6/8/9.

---

## Step 8 — Migrate instagram-post page (highest risk)

**Depends on:** Step 4. **Model:** strongest (largest file, most business logic interleaved with UI — 868 lines). **Parallel group:** B.

**Context brief:** This is the riskiest step. `InstagramPostPage.tsx` is 868 lines and per `docs/features-e-capacidades.md` covers 5 slide layout types, an inline markup language (`[hl]`/`[c]`/`[b]`/`[i]`/`[u]`), font/preset selection, history with auto-save, Instagram OAuth connection state, and publish/schedule flows. There is no `PostCanvasType1.tsx` file — Type 1 (and the Type 5/Freestyle variant) render directly inside `PostCanvas.tsx`; only Types 2/3/4 have their own `PostCanvasType{2,3,4}.tsx` files. All of `PostCanvas.tsx`/`PostCanvasType2/3/4.tsx` render the actual exported visuals and must not change pixel output. `markup.tsx` has a documented historical bug fix (shared-regex `lastIndex` corruption, now fixed with a fresh `RegExp` per call per the migration memory) — do not touch `markup.tsx`'s regex instantiation pattern while refactoring around it. Note: Step 3 already updated this feature's `controls.tsx` imports from the old `Controls.tsx` to the new primitive paths — build on that, don't re-migrate those imports.

**Tasks:**
1. Split `InstagramPostPage.tsx` by responsibility, not by line count: a style/preset editor panel, a slide list/reorder panel, a canvas preview wrapper (delegates to the existing `PostCanvas*` components unchanged), a publish/schedule `Dialog` (using Step 3's `Dialog`), a connection-status indicator (using Step 2's `StatusPill`), a history panel (using Step 2's `EmptyState`/`Skeleton`).
2. Do NOT change `PostCanvas.tsx` (covers Types 1 and 5/Freestyle), `PostCanvasType2/3/4.tsx`, `markup.tsx`, `post-export.ts`, `instagram-post-style.ts`, `ig-post-history.ts`, `pick-image.ts` — these are rendering/export/data logic, out of scope for a UI-layer refactor.
3. Replace the existing `controls.tsx` (112 lines, feature-local controls) call sites with Step 2/3 primitives where they're equivalent; keep feature-specific controls that have no generic equivalent (e.g. slide-type-specific options) local to the feature.
4. Wire `Toast` for publish success/failure (the docs note publish enforces `created_by === auth.uid()` server-side — a failed publish due to that check needs a clear toast, not a silent failure).

**Files touched:** `src/features/instagram-post/InstagramPostPage.tsx`, `src/features/instagram-post/controls.tsx`, possibly new sub-component files in the same directory. Explicitly NOT: `PostCanvas*.tsx`, `markup.tsx`, `post-export.ts`, `instagram-post-style.ts`, `ig-post-history.ts`.

**Verification:** `npm run typecheck && npm run lint && npm test` — `markup.test.tsx`, `instagram-post-style.test.ts`, `ig-post-history.test.ts` must all pass unchanged. Playwright: create a post with at least 2 of the 5 slide types, apply inline markup tags, export to PNG, confirm visual output matches pre-refactor (screenshot diff if feasible) before/after.

**Exit criteria:** `git diff` on the excluded files (`PostCanvas.tsx`, `PostCanvasType2/3/4.tsx`, `markup.tsx`, `post-export.ts`, `instagram-post-style.ts`, `ig-post-history.ts`) is empty. All Instagram-post tests green. Export still produces correct pixel output.

**Rollback:** `git revert`; isolated from Steps 5/6/7/9, but verify no other step's commit landed on top of it before reverting (check `git log --oneline` ordering).

---

## Step 9 — Migrate video-caption editor

**Depends on:** Step 4. **Model:** default. **Parallel group:** B.

**Context brief:** `VideoCaptionPage.tsx` (231 lines) is the one feature that talks to a local Node API instead of Supabase, with 5 tabs (Cortes/Legendas/Segmentos/Análise/Estilo) per the docs. `video-caption-models.ts` (has `video-caption-models.test.ts`) holds the reflow/gap-detection logic and must not change.

**Tasks:**
1. Replace whatever tab-switching markup currently exists with Step 3's `Tabs` primitive.
2. Add `Dialog` for destructive actions (deleting a cut/caption) if not already confirmed some other way — check current delete UX first, don't add a confirmation step that wasn't there if it would slow down an already-deliberate user action; only add `Dialog` if today's delete is a single accidental-prone click.
3. Add `EmptyState` for "no cuts/captions yet", style-tab inputs (font/size/position/color) onto Step 3's `Select`/`ColorInput`.
4. Do NOT change `video-caption-models.ts`, `video-caption-api.ts`, `api-base-url.ts`.

**Files touched:** `src/features/video-caption/VideoCaptionPage.tsx` only (plus possible new sub-components in the same directory).

**Verification:** `npm run typecheck && npm run lint && npm test` (`video-caption-models.test.ts` must stay green). Playwright: load a transcribed video fixture if one exists in `test/` fixtures, exercise the 5 tabs, confirm export still calls the local API correctly (mock/check network call shape if no live local API server is running in this environment).

**Exit criteria:** Model/API files have zero diff; tabs and forms use new primitives; existing tests green.

**Rollback:** `git revert`; isolated from Steps 5/6/7/8.

---

## Step 10 — Final UX pass + full verification

**Depends on:** Steps 5, 6, 7, 8, 9 (all must have landed on the branch). **Model:** strongest (cross-cutting review, easiest place for inconsistencies to hide). **Parallel group:** solo.

**Context brief:** This step is a deliberate "look at the whole thing together" pass — the previous 5 parallel steps each had a narrow, isolated context brief and could not see each other's decisions. This step catches drift between them (e.g. two features inventing slightly different empty-state copy, inconsistent toast durations, inconsistent dialog button ordering).

**Tasks:**
1. Grep across all of `src/features/` for any remaining inline error-state `<div>`s that should be `Toast` calls, and any remaining raw `<input>`/loading-text patterns that should be `Skeleton`/the new form primitives — Steps 5–9 should have caught most of these, but verify nothing was missed.
2. Confirm no orphaned files/symbols remain from the Step 3 `Controls.tsx`/`Field.tsx` split (grep for any lingering import of a deleted symbol name) and that the new primitive set (`ui/Toast`, `Skeleton`, `EmptyState`, `Badge`, `Tooltip`, `Select`, `Switch`, `Stepper`, `ColorInput`, `ImagePicker`, `Dialog`, `Tabs`, `DropdownMenu`, plus `FeaturePageLayout` and any `src/shared/components/chat/*`) is each used by at least one feature — an unused primitive is a sign a migration step missed it.
3. Audit keyboard interaction consistency: every `Dialog` closes on Esc, every chat composer submits on Cmd/Ctrl+Enter (check which features already had this — e.g. `copy`'s chat — before adding it elsewhere so behavior is consistent, not just present).
4. Run the full gate: `npm run typecheck && npm run lint && npm test && npm run build`.
5. Launch `npm run dev`, use Playwright MCP (best-effort, see verification policy above) to walk all 11 routes (`/login` excluded since it needs no auth state changes, but `/org-picker`, `/flows/:slug`, `/modules/:slug`, `/squads/:slug`, `/copy`, `/editorial`, `/instagram-post`, `/instagram-n3`, `/audio-visualizer`, `/video-caption`), screenshot each, and check for visual regressions or console errors.
6. Confirm the two known untracked files from before this work started (`docs/features-e-capacidades.md`, `supabase/migrations/20260622010000_add_luizpaulo_to_metrifica.sql`) were never touched by this redesign — they're unrelated in-flight work and should be left alone.

**Files touched:** Whatever small inconsistencies surface in step 1 of this task — expect minor edits across multiple feature files, not new architecture.

**Verification:** Full gate above, plus the Playwright walkthrough.

**Exit criteria:** Full gate green. No console errors during the Playwright walkthrough. No unintended diff on `docs/features-e-capacidades.md` or the untracked migration SQL file.

**Rollback:** Each fix in this step should be a small, separately revertable commit if anything goes wrong — don't squash this step into one giant commit.

---

## Explicitly out of scope (do not drift into these)

- Fixing the documented fidelity gaps (Instagram Post tipo 2/4 cover variants, Audio Visualizer knob parity, Video Caption draggable timeline) — these are pre-existing, separately tracked, and not part of "consolidate the component library + improve UX."
- Any change to Supabase schema, Edge Functions, or RLS policies.
- Any change to `lib/` (the Flutter app) — it stays as reference/fallback until a separate cutover decision.
- Introducing a new component library dependency (Radix, MUI, etc.) — the existing shadcn-style/Tailwind-native approach stays; primitives are hand-built to match the existing `cn()` + `tailwind-merge` pattern already in use.
