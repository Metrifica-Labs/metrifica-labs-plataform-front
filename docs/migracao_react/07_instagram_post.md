# Fase 7 — Instagram Post (editor de carrossel) — MÓDULO DE MAIOR RISCO

Equivalente a `lib/features/instagram_post/*`. O módulo mais complexo do app: 4 layouts de slide completamente distintos, markup customizado (não-markdown), 13 fontes Google simultâneas, export para PNG pixel-perfect. **Recomendação central: desenhar os 4 layouts direto com Canvas API 2D**, replicando a estratégia já validada no `audio_visualizer_engine.dart` — não usar `html2canvas`/`html-to-image` sobre HTML/CSS, pelo risco de infidelidade em fontes/gradientes/clipping.

> Antes de integrar histórico/auto-save/geração por IA, fazer um **protótipo isolado de fidelidade visual**: renderizar os 4 tipos de slide num canvas standalone, comparar pixel a pixel (ou visualmente lado a lado) com o app Flutter atual. Só seguir para o resto do módulo depois de aprovado.

## 7.1 Constantes e modelo de dados

- `kCanvasWidth = 432`, `kCanvasHeight = 540` (proporção 4:5). Export final com `pixelRatio = 2.5` → ~1080×1350px. **Manter esse canvas lógico fixo** e escalar só no momento do export (`ctx.scale(pixelRatio, pixelRatio)` antes de desenhar, ou desenhar em resolução final direto — decidir conforme performance).

### Enums
```ts
type SlideLayout = 'textPost' | 'imageCover' | 'textGrid' | 'imageStack'; // Tipo 1-4
type ImageCoverVariant = 'logoMid' | 'logoTop' | 'subtitleTop' | 'logoTopInline'; // só Tipo 2
```

### `SlideContent`
Campos por slide: `headline, body, imageBytes?, imageAbove, showHeader, layout, coverImageBytes?, coverVariant, swipeText, gridTexts: string[4], gridBolds: boolean[4], gridSpacing, textAlign, slideBgColor?, slideTextColor?, slideHeadlineColor?, slideBodyColor?, swipeTextColor?, showCounter`.
- Funções `resolvedBg(slide, style)`, `resolvedText(...)`, `resolvedHeadlineFor(...)`, `resolvedBodyFor(...)`: fallback hierárquico slide → global (style).

### `PostStyle`
Estado global do editor: perfil (avatar, nome, handle, badge verificado), logo (Tipo 2), 4 fontes Google independentes (name/handle/body/counter), ênfases (bold/italic/underline para headline e separadamente para body), `highlightColor`, cores globais (bg/text/headline/body), `showArrows`, `bodyFontSize`, `centerContent`, `slides: SlideContent[]`.

### Constantes fixas
- `kAvailableFonts`: 13 fontes (Inter, Poppins, Montserrat, "Sequel Sans" [verificar disponibilidade real no Google Fonts — pode precisar de fallback ou fonte própria hospedada], Playfair Display, Lora, Roboto Slab, Oswald, Bebas Neue, Archivo, Space Grotesk, DM Sans, Libre Baskerville).
- `kCreatorPresets`: 5 presets visuais completos (Clean, Dark, Editorial, Bold Blue, Punch) — cor + fontes.
- `kBackgroundSwatches` / `kHighlightSwatches`: paletas fixas de cores rápidas.

### Parser de slides a partir do output da IA
`parseSlides(output, defaultLayout)`:
1. Tenta extrair primeiro bloco de código JSON contendo `"slides"` (regex de bloco markdown).
2. Se falhar, fallback: divide o texto em parágrafos por linha vazia, primeira linha = headline (remove `#` markdown), resto = body.
3. Trata `swipeText`/`swipe_text` (ambas as chaves possíveis vindas da IA).

## 7.2 Store (Zustand) — substitui `instagram_post_notifier.dart`

Setters granulares por slide: `updateSlide`, `setSlideImage`, `setSlideImageAbove`, `setSlideShowHeader`, `setSlideShowCounter`, `setSlideLayout`, `setSlideCoverImage`, `setSlideCoverVariant`, `setSlideSwipeText`, `setSlideBgColor/TextColor/HeadlineColor/BodyColor/SwipeTextColor`, `clearSlideColors`, `setGridBold`, `setGridSpacing`, `setGridText`, `setSlideTextAlign`.

Globais: `setAvatar`, `setLogo`, `setProfileName`, `setHandle`, `setAvatarRadius`, `toggleVerifiedBadge`, `setDefaultLayout`, `toggleCenterContent`, setters de fontes, ênfases, `setHighlightColor`, cores, `toggleArrows`, `setBodyFontSize`, `applyPreset`.

- `restoreFromHistory(savedStyle)`: **não restaura binários** (avatar/logo) — comportamento intencional do original (histórico local não persiste bytes binários).
- `restoreStyleOnly(savedStyle)`: preserva slides/binários atuais, só troca config visual (cores/fontes/preset).
- `pendingN3SlidesStore`: ponte com o módulo Instagram N3 (fase 6) — slides pendentes a aplicar na montagem.

## 7.3 Histórico local — `ig_post_history.dart`

- `localStorage['ig_post_history_v1']`, máx. 15 entradas; `localStorage['ig_post_saved_style_v1']` para preferências de estilo.
- Serializa `PostStyle` para JSON (cores como inteiro ARGB32 — em React/CSS usar string hex `#RRGGBBAA` ou objeto `{r,g,b,a}`, decisão de implementação, mas manter compatibilidade se for reaproveitar dados salvos — **decisão: começar histórico zerado no React, já que o formato Dart não é diretamente compatível com JS sem um migrador**).
- **Bytes binários (avatar/logo/imagens de slide) nunca são persistidos** — perdidos ao reabrir do histórico. Replicar esse comportamento (não é bug a corrigir, é como o Flutter atual funciona).

## 7.4 Markup customizado inline (headline/body)

Não é markdown — é um mini-parser tipo BBCode, usado em `post_canvas.dart` (Tipo 1):
- Regex: `\[(hl(?:=#hex)?|i|u|b)\](.*?)\[/(hl|i|u|b)\]`, com suporte a tags aninhadas recursivamente.
- Tags: `[hl]`/`[hl=#hex]` (highlight, cor configurável global ou inline), `[i]` itálico, `[u]` sublinhado, `[b]` negrito.
- **Implementação em React/Canvas**: escrever `parseMarkup(text): Span[]` retornando uma árvore/lista plana de spans com estilos resolvidos (cor, itálico, sublinhado, negrito), e uma função de desenho que itera os spans desenhando com `ctx.fillText` calculando largura acumulada (`ctx.measureText`) para line-wrap manual — não existe primitiva nativa de rich text em canvas, precisa ser feito à mão (igual ao Flutter, que usa `RichText` internamente mas a lógica de parsing é equivalente).

## 7.5 Os 4 layouts de canvas

Todos desenhados num único `<canvas width=432 height=540>` (mesma canvas lógica reaproveitada ao trocar de slide ativo — replicar o padrão de "single canvas, redesenha conteúdo" usado no Flutter via `RepaintBoundary` reaproveitado).

### Tipo 1 — `textPost` (`post_canvas.dart`)
- Header opcional (avatar circular + nome + badge verificado + handle).
- Imagem opcional (posição acima ou abaixo do texto, conforme `imageAbove`).
- Headline (markup customizado, seção 7.4).
- Body (markup customizado).
- Footer fixo na base: contador "X/N" + seta de avançar (exceto no último slide).
- `centerContent`: controla se o bloco header+headline+body fica centralizado verticalmente; footer **sempre** fixo na base independente disso.
- Fonte resolvida com fallback para "DM Sans" se a fonte escolhida falhar ao carregar.

### Tipo 2 — `imageCover` (`post_canvas_type2.dart`)
- Imagem de fundo full-bleed (`drawImage` com crop "cover" manual — replicar `_drawCover`: centraliza e recorta mantendo aspect ratio).
- Gradiente preto de baixo para cima sobreposto (`createLinearGradient`, stops `[0.35, 1.0]`, transparent → black 75%).
- Conteúdo varia por `ImageCoverVariant`:
  - `logoMid`: logo central → cards de texto (título+subtítulo) → footer.
  - `logoTop`: logo topo-esquerda → spacer → cards → footer.
  - `subtitleTop`: logo topo → spacer → cards invertidos (subtítulo antes do título) → footer.
  - `logoTopInline`: logo topo + texto direto sobre o gradiente sem cards brancos (com sombra de texto para legibilidade — `ctx.shadowColor`/`shadowBlur`).
- Logo com fallback: se não houver logo, desenhar "pill" de texto com o handle.
- Footer usa `resolvedBg` da slide para contrastar com a imagem.

### Tipo 3 — `textGrid` (`post_canvas_type3.dart`)
- Imagem de fundo full-bleed.
- Grade 2×2 de blocos de texto sobrepostos (índices: 0=topLeft, 1=topRight, 2=botLeft, 3=botRight), cada bloco com bold/alinhamento configuráveis individualmente (`gridTexts`, `gridBolds`, `gridSpacing`).
- Footer.

### Tipo 4 — `imageStack` (`post_canvas_type4.dart`)
- Duas metades empilhadas (50/50 da altura): superior = `imageBytes` + `headline`; inferior = `coverImageBytes` + `body`.
- Cada metade com sua própria imagem + gradiente + texto sobreposto.
- **Overlap de 1px entre as metades** para eliminar linha de costura (`height = half + 1`, ajuste de posição) — detalhe sutil a replicar exatamente, senão aparece uma linha visível na junção.

## 7.6 Logo/imagem — detecção SVG

Equivalente a `logo_image.dart`: detectar SVG pela assinatura de bytes (`isSvg`, fase 2) e desenhar via `Image()`/`drawImage` apontando para um Blob URL do SVG — funciona nativamente em canvas (`ctx.drawImage(svgImageElement, ...)`), sem necessidade de componente separado.

## 7.7 Exportação PNG

Equivalente a `post_export.dart`:
- `capturePng(canvas, pixelRatio=2.5)`: se desenhar direto em resolução final (canvas físico já em `432*2.5 x 540*2.5` com `ctx.scale(2.5,2.5)` aplicado antes dos desenhos lógicos), basta `canvas.toBlob('image/png')`. Validar qual abordagem dá melhor fidelidade de fonte (testar ambas no protótipo da seção inicial).
- `downloadFile` (fase 2) para o blob resultante.
- `pickFile('image/*')` (fase 2) para seleção de imagens.

## 7.8 Página — `instagram_post_page.dart`

- Auto-save de estilo a cada 1 minuto (`setInterval`) em `localStorage`.
- Ao montar, restaurar estilo salvo do usuário (`restoreStyleOnly`) preservando slides atuais.
- Bridge com N3 (fase 6): se há slides pendentes no `pendingN3SlidesStore`, aplicar automaticamente no mount (`useEffect`) e limpar o bridge.
- `generate()`: dispara o motor de geração genérico (fase 3) com `flowSlug: 'instagram-text-post'`. Se o layout padrão é `imageCover` (Tipo 2), injetar contexto extra na mensagem instruindo a IA a gerar JSON com `headline`/`body`/`swipeText` adaptados a esse formato.
- Ao completar geração (`status === 'done'`): `parseSlides(output, defaultLayout)` → popular store; salvar no histórico local **uma única vez** (flag para evitar duplicar).
- `exportCurrent()`: exporta o slide atualmente ativo.
- `exportAll(total)`: itera todos os slides, trocando o slide ativo e aguardando o próximo paint (`requestAnimationFrame` + pequeno delay, ex. 60ms) antes de capturar cada um — necessário porque é o mesmo canvas reaproveitado, não um canvas por slide.
- Layout responsivo: `wide` (>900px) controles + preview lado a lado (preview com largura fixa 412px); `narrow` empilha tudo em scroll único.
- Seletor de slide ativo + navegação prev/next.

## Critério de aceite da fase

1. **Protótipo de fidelidade visual aprovado** antes de prosseguir com o resto (comparação lado a lado dos 4 tipos com o Flutter atual, incluindo fontes, gradientes, markup `[hl]`/`[b]`/`[i]`/`[u]`).
2. Gerar um post via IA, ver os 4 tipos de layout renderizando corretamente a partir do mesmo conteúdo gerado.
3. Exportar PNG individual e "exportar todos" — confirmar resolução final (~1080×1350) e nitidez equivalente ao app atual.
4. Bridge Instagram N3 → Instagram Post funcionando (slides corretos, na ordem certa).
5. Auto-save de estilo confirmado entre reloads (esperar 1 min ou forçar save, recarregar página, confirmar estilo restaurado mas slides/binários não persistidos — comportamento esperado).
6. Validar visualmente as 13 fontes carregando corretamente (atenção especial a "Sequel Sans", que pode não existir no Google Fonts público — verificar e decidir fallback/hospedagem própria se necessário).
