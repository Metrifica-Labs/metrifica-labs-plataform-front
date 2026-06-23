import type {
  ImageCoverVariant,
  SlideLayout,
} from "@/features/instagram-post/instagram-post-style";

export const FLOW_SLUG = "instagram-text-post";

export const LAYOUT_LABELS: Record<SlideLayout, string> = {
  textPost: "Tipo 1 — Texto",
  imageCover: "Tipo 2 — Capa",
  textGrid: "Tipo 3 — Grade",
  imageStack: "Tipo 4 — Empilhado",
  freestyle: "Tipo 5 — Freestyle",
};

export const LAYOUT_SUBTITLES: Record<SlideLayout, string> = {
  textPost: "Texto + perfil",
  imageCover: "Imagem de fundo",
  textGrid: "Grade de textos",
  imageStack: "Pilha de imagens",
  freestyle: "Sem header, imagem no meio",
};

export const COVER_VARIANT_LABELS: Record<ImageCoverVariant, string> = {
  logoMid: "Logo + título em card",
  logoTop: "Logo topo + cards",
  subtitleTop: "Subtítulo antes",
  logoTopInline: "Texto sobre imagem",
};

export const STATUS_LABELS: Record<string, string> = {
  connecting: "Conectando ao modelo...",
  thinking: "Pensando...",
  streaming: "Gerando conteúdo...",
};

export const IMAGE_COVER_PROMPT_SUFFIX = `

---
TIPO DE LAYOUT SELECIONADO: Tipo 2 — Image Cover (imagem de fundo full-bleed)
Adapte os slides para este formato:
- "headline": título curto e impactante (máximo 7 palavras) — aparece em card sobre a imagem
- "body": subtítulo breve e opcional (máximo 20 palavras, pode ser string vazia "")
- "swipeText": texto de swipe opcional em português (ex: "Arraste para o lado →", ou "" para omitir)
O JSON de cada slide deve ter os três campos: headline, body, swipeText.`;
