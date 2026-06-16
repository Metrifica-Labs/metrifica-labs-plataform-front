# Fase 6 — Instagram N3

Equivalente a `lib/features/instagram_n3/*`. Chat com IA gerando posts estruturados em "cards", sem canvas — a ponte para o módulo Instagram Post (fase 7) é o ponto mais importante a preservar.

## 6.1 Modelos

Equivalente a `instagram_n3_card.dart`:
```ts
interface N3Card { card: number; objetivo: string; headline: string; body: string }
type N3PostType = "1/9' O Método" | "2/9' A Vida Após" | "3/9' O Contraponto" | "10/9' Aplicação Real"; // numeração inconsistente preservada do original
interface N3Post { postType: N3PostType; cards: N3Card[] }
```
- `parseN3Post(output, defaultType)`: extrai bloco JSON de dentro de ` ```json ... ``` ` e faz `JSON.parse`, esperando `{post_type, cards: [...]}`.

## 6.2 Chat

Equivalente a `instagram_n3_chat.dart`:
- Mesmo padrão de streaming SSE da fase 4/3, mas chamando **`run-flow`** com `{flow_slug: 'instagram-n3', messages: [...]}` (array de mensagens, não `user_message` único).
- Ao finalizar a resposta do assistente (`_finalize`), tentar `parseN3Post(content)`; se houver cards, anexar o `N3Post` parseado à mensagem (`msg.post`).
- Reaproveitar o `ChatScaffold` da fase 4.

## 6.3 Estado dos cards

Equivalente a `instagram_n3_notifier.dart`: store simples (`N3Post | null`) com `setPostType`, `setCards`, `updateCard(index, patch)`, `clear()`.

## 6.4 Histórico local

Equivalente a `instagram_n3_history.dart`:
- `localStorage['instagram_n3_history_v1']`, máx. 20 entradas, CRUD `add`/`remove`.
- **Sem componente Supabase** — histórico é 100% client-side, ao contrário de `generation_history`/`squad_runs`.

## 6.5 Página e ponte para Instagram Post

Equivalente a `instagram_n3_page.dart`:
- Chat tradicional (bolhas usuário/assistente).
- Por resposta com cards parseados: botão "copiar texto" e botão **"enviar para Instagram Post"**.
- `sendToPost(n3Post)`:
  1. Converte cada `N3Card` em `SlideContent` (headline + body) — ver modelo completo na fase 7.
  2. Seta um estado de "bridge" compartilhado (`pendingN3SlidesStore`, equivalente ao `pendingN3SlidesProvider` do Flutter) com a lista de slides convertida.
  3. Navega para `/instagram-post` (React Router `navigate`).
  4. Na montagem do Instagram Post (fase 7), se o bridge tiver slides pendentes, aplicá-los automaticamente e limpar o bridge.

## Critério de aceite da fase

- Gerar um post N3 completo via chat, confirmar que os cards aparecem corretamente parseados.
- Clicar "enviar para Instagram Post" e confirmar que os slides chegam corretamente convertidos no editor (headline/body certos, na ordem certa).
- Histórico local persiste entre reloads (testar com 20+ entradas para confirmar o corte no limite).
