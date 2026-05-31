-- Corrige encoding (mojibake) da migration anterior e garante 1 prompt de imagem por slide.
-- Reescreve o conteúdo completo dos módulos em UTF-8 limpo (dollar-quoted).
SET client_encoding TO 'UTF8';

UPDATE modules SET content = $mod$# Template de Prompt de Imagem — Metrifica Labs

## Como usar este template

1. Leia o conteúdo finalizado (post, campanha, ou briefing isolado)
2. Identifique: tipo de conteúdo, mensagem principal, conceito visual central
3. Escolha o template correspondente abaixo
4. Preencha os campos marcados com `[COLCHETES]`
5. Copie o prompt gerado e envie à IA de geração de imagem
6. O prompt deve ser em **inglês** — IAs de imagem performam melhor em inglês

---

## Template 1 — Post Conceitual (ícones iOS + logo)

> Para posts de plataforma, produto, diferencial ou conceito de marca.

```
Create an Instagram post image with a clean, minimalist Apple-inspired aesthetic.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px), mobile-first layout.

BACKGROUND: Pure white (#FFFFFF) or very light gray (#F5F5F7). Lots of negative space.

VISUAL ELEMENT (top 60% of the image):
Center: a circular logo mark — the letter "m." in serif font inside a circle that is split in half vertically: left half is white, right half is blue (#236BF7) with a subtle globe/grid wireframe pattern. The circle has a very soft shadow beneath it.
Floating around the logo: [N] iOS-style app icons with colorful gradients (blues, greens, purples, pinks), rounded corners (iOS style), and soft drop shadows. Each icon should have a simple recognizable symbol inside. Icons representing: [DESCREVA OS ÍCONES RELEVANTES AO TEMA]
The icons should float at slightly different distances from the center, creating depth and movement.

TEXT ON IMAGE (bottom 40%):
- Title (bold, large, black #000000, centered): "[MENSAGEM PRINCIPAL — MÁX 10 PALAVRAS]"
- Subtitle (regular, small, gray #6E6E73, centered below title): "[LINHA COMPLEMENTAR — MÁX 15 PALAVRAS]"

TYPOGRAPHY: Bold sans-serif for title (SF Pro Bold style), regular weight for subtitle.

MOOD: Modern, trustworthy, premium tech brand. Feels like an Apple product page.

DO NOT include: Dark backgrounds, busy patterns, corporate stock photos, clipart, watermarks, excessive shadows, 3D realistic effects, logos of other companies.
```

---

## Template 2 — Post Tipográfico Puro (frase de impacto)

```
Create a typographic Instagram post image. No illustrations, no icons — text only.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

BACKGROUND: Pure white (#FFFFFF). Maximum whitespace — the text is the only element.

LAYOUT:
- Upper 40%: Empty white space (breathing room)
- Middle area: Main bold statement, positioned left-aligned with generous left margin
- Lower area: Supporting line, smaller and in gray, positioned below or at lower-right

TEXT ON IMAGE:
- Main statement (very large, bold, black #000000, left-aligned): "[FRASE PRINCIPAL — MÁX 12 PALAVRAS]"
- Supporting line (small, regular, gray #6E6E73): "[CONTEXTO OU SUBTÍTULO — MÁX 20 PALAVRAS]"

MOOD: Direct, confident, thought-provoking. Feels editorial — like a page from a premium business book.

DO NOT include: Any visual elements beyond text. No icons, no shapes, no decorations, no gradients, no borders.
```

---

## Template 3 — Post com Objeto Aspiracional

```
Create a minimalist Instagram post image with Apple-inspired product photography aesthetic.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

BACKGROUND: Pure white (#FFFFFF). Clean studio-style lighting.

LAYOUT:
- Top section: small regular text in gray (#6E6E73), centered: "[TEXTO TOPO]"
- Middle section: bold black italic text, left-aligned: "[TEXTO PRINCIPAL EM ITÁLICO — MÁX 4 LINHAS]"
- Bottom section (40% of image): [OBJETO] photographed on pure white background, product-shot style.

OBJECT DESCRIPTION: [DESCREVA O OBJETO COM DETALHES]

MOOD: Premium, provocative, elegant.

DO NOT include: Busy backgrounds, multiple objects, text over the product.
```

---

## Template 4 — Post de Paisagem com Texto Overlay

```
Create an Instagram post image with cinematic photography and text overlay.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

IMAGE: Full-bleed photograph of [DESCRIÇÃO DA PAISAGEM/CENA]. The scene should evoke [EMOÇÃO]. Dramatic cinematic lighting, rich colors, high dynamic range.

TEXT OVERLAY: White text, centered: "[TEXTO — MÁX 10 PALAVRAS]"
Font: semi-bold sans-serif (SF Pro Semibold style). Apply subtle dark vignette if needed for legibility.

LANDSCAPE OPTIONS:
- Deep green canyon with a winding river and moss-covered cliffs
- Dramatic sunset/sunrise sky with stars and shooting star
- Vast mountain range with golden hour lighting
- Aerial view of a coastline with turquoise water

DO NOT include: People, animals, man-made structures, watermarks.
```

---

## Template 5 — Post Provocativo / Desafiador

```
Create an editorial-style Instagram post image that challenges common misconceptions.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

BACKGROUND: White or very light gray (#F5F5F7).

VISUAL ELEMENT (center): [DESCRIÇÃO DO PERSONAGEM/CENA PROVOCATIVA]

SPEECH BUBBLES: [N] speech bubbles in blue (#236BF7) with white bold text:
[LISTA DE FRASES/MITOS]

MOOD: Slightly humorous but professional. Editorial satire.

DO NOT include: Offensive imagery, real people, real company logos.
```

---

## Template 6 — Post Infográfico / Framework

```
Create a minimalist infographic-style Instagram post image.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

BACKGROUND: Very light gray (#F5F5F7) or white (#FFFFFF).

VISUAL ELEMENT (top 55%): [ESCOLHA: Growth Chart / Step-by-Step / Comparison Split]

TEXT ON IMAGE (bottom 45%):
- Title (bold, large, black): "[TÍTULO DO FRAMEWORK — MÁX 10 PALAVRAS]"
- Subtitle (regular, small, gray): "[SUBTÍTULO — MÁX 15 PALAVRAS]"

MOOD: Educational, structured, authoritative. Feels like a premium consulting deck.

DO NOT include: Too many colors (max 3: black, gray, blue), excessive data, pie charts.
```

---

## Template 7 — Post Educativo Denso

```
Create an educational Instagram post image with a clean, structured layout.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

LAYOUT (top to bottom):
- Top section (30%): [ELEMENTO VISUAL]
- Middle section (50%): Body text with key phrases highlighted in blue (#236BF7 at 15% opacity)
- Bottom section (20%): Empty or subtle separator

TEXT: "[CONCEITO]" as large bold title. Body text: "[TEXTO EXPLICATIVO — MÁX 80 PALAVRAS]"

MOOD: Educational, credible, like a well-designed article page.

DO NOT include: Walls of text, small unreadable fonts, busy backgrounds.
```

---

## Template 8 — Slide Institucional (logo + tagline + CTA)

```
Create a clean, minimalist Instagram post image for a brand closing slide.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

BACKGROUND: Pure white (#FFFFFF). Maximum whitespace.

LAYOUT (centered):
- Center: Metrifica Labs logo — "m." in serif font inside circle split: left half white, right half blue (#236BF7) with globe/grid pattern. ~200-250px diameter. Soft shadow.
- Tagline (bold black, centered): "[TAGLINE]"
- CTA (regular gray #6E6E73, smaller, centered): "[CTA]"

MOOD: Premium, confident, clean. Simplicity communicates confidence.

DO NOT include: Any elements beyond logo, tagline and CTA.
```

---

## Template 9 — Post de Transição Narrativa

```
Create a minimalist Instagram post image with a narrative text layout.

FORMAT: Portrait orientation, 4:5 ratio (1080x1350px).

BACKGROUND: Pure white (#FFFFFF).

TEXT BLOCKS (vertically distributed):
- Block 1 (top, smaller, gray): "[SETUP/CONTEXTO]"
- Block 2 (middle, large bold black): "[FRASE DE IMPACTO]"
- Block 3 (lower, medium bold): "[CONCLUSÃO/REFRAME]"

MOOD: Narrative tension. Each line hits harder than the last.

DO NOT include: Any visual elements — text rhythm IS the design.
```

---

## Guia rápido de qual template usar

| Tipo de conteúdo | Template recomendado |
|---|---|
| Post de produto, diferencial ou conceito | Template 1 — Conceitual (ícones + logo) |
| Frase forte, opinião, provocação direta | Template 2 — Tipográfico puro |
| Post de dor com metáfora visual | Template 3 — Objeto aspiracional |
| Slide emocional, inspiracional | Template 4 — Paisagem com overlay |
| Post desafiando mitos ou crenças | Template 5 — Provocativo/desafiador |
| Framework, processo, comparação | Template 6 — Infográfico/framework |
| Explicação aprofundada de conceito | Template 7 — Educativo denso |
| Último slide do carrossel | Template 8 — Institucional |
| Slide de virada narrativa | Template 9 — Transição narrativa |
| Criativo para campanha (Meta Ads) | Template 2 ou 3 |

## Regras globais de imagem

- Prompt **sempre em inglês**
- Sempre especificar formato exato (px e proporção)
- Sempre incluir "Apple-inspired", "clean", "minimalist"
- Texto na imagem: máximo **10 palavras no título**, **15 no subtítulo**
- Cores: branco (#FFFFFF), cinza (#F5F5F7, #6E6E73), preto (#000000), azul Metrifica (#236BF7, #3C99F7)
- Exceção: objetos aspiracionais podem ter cor própria
- Máximo **3 elementos visuais** por imagem

---

## Regra obrigatória para carrosséis (um prompt por slide)

Quando o conteúdo for um carrossel com N slides, gere N prompts de imagem completos — UM para CADA slide, na ordem dos slides. Nunca gere um único prompt cobrindo só o slide principal.

Para cada slide:
- Escolha o template visual adequado ao papel daquele slide (hook, dado, dor, virada, solução, apresentação, CTA) usando o "Guia rápido de qual template usar".
- Preencha todos os campos entre [COLCHETES] com o conteúdo real do slide.
- Escreva o prompt em inglês.

Formato de saída obrigatório: cada prompt deve vir isolado em seu próprio bloco de código (``` ... ```), contendo SOMENTE o prompt. Nada de juntar vários slides no mesmo bloco. N slides = N blocos de código, na ordem.$mod$ WHERE slug = 'template-prompt-imagem';

UPDATE modules SET content = $mod$# Regras de Post — Instagram Metrifica Labs

## Formatos de post

### Carrossel (formato principal)
- **Quantidade de slides:** 5 a 10 por carrossel
- **Proporção:** 4:5 (1080 x 1350px) para feed
- **Estrutura narrativa obrigatória:**

```
Slide 1 — Hook (pergunta provocativa ou frase de impacto + "Arraste pro lado")
Slides 2-N — Desenvolvimento (dor → agravamento → virada → solução)
Penúltimo slide — Apresentação da Metrifica Labs (logo + tagline)
Último slide — CTA
```

### Post estático (formato secundário)
- Imagem única com frase de impacto
- Funciona bem para frases curtas e memoráveis
- Exemplo: paisagem + texto overlay branco

## Regras visuais

- **Fundo predominante:** branco (#FFFFFF)
- **Tipografia:** bold, preta, grande, sans-serif para frases de impacto
- **Subtítulos/complementos:** regular, cinza (#6E6E73), menor
- **Imagens aspiracionais como metáfora visual** — objetos de alto padrão que representam conceitos (ex: Porsche = velocidade, carteira = dinheiro, volante = controle)
- **Imagens de paisagem/natureza** para slides emocionais ou de transição
- **Logo "m."** aparece no slide de apresentação da empresa
- **Máximo 3 elementos visuais** por slide
- **Muito espaço negativo** — estilo Apple

## Regras de texto nos slides

- **Título:** máximo 15 palavras por slide (frases curtas, impacto)
- **Texto complementar:** máximo 2 linhas abaixo do título
- **Palavras-chave em negrito** para ênfase
- **Itálico** para listas de problemas/dores
- **Nunca:** blocos longos de texto (exceção: slides educativos tipo post 3 — no-code)

## Legenda do post

- Tom consultivo e direto conforme `core/tom-de-voz.md`
- Deve complementar o carrossel, não repetir
- Incluir CTA no final
- Hashtags relevantes (máximo 15)

## CTA padrão

> Clique no link na bio e agende uma consultoria gratuita de viabilidade do seu sistema ou app.

## Tagline recorrente (usar no slide de apresentação)

> Para identificar, implementar e escalar o seu negócio com tecnologia. Independente do nicho.

## Checklist antes de publicar

- [ ] Hook do slide 1 é provocativo e gera curiosidade?
- [ ] A narrativa segue a estrutura Dor → Agravamento → Virada → Solução → CTA?
- [ ] O conteúdo está alinhado com um dos 4 pilares?
- [ ] O tom está consultivo e sério (não agressivo, não informal)?
- [ ] A identidade visual está consistente (branco, preto, azul)?
- [ ] O CTA está presente no último slide?
- [ ] A legenda complementa (não repete) o conteúdo dos slides?

## Imagens do carrossel

Gere um prompt de imagem completo para CADA slide do carrossel, na ordem, cada prompt em seu próprio bloco de código (``` ... ```). Use o módulo "Template de Prompt de Imagem" para escolher o template de cada slide. Um carrossel de 8 slides deve produzir 8 prompts de imagem.$mod$ WHERE slug = 'regras-post-instagram';
