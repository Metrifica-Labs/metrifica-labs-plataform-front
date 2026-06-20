export type SlideLayout = "textPost" | "imageCover" | "textGrid" | "imageStack";
export type ImageCoverVariant = "logoMid" | "logoTop" | "subtitleTop" | "logoTopInline";
export type TextAlignment = "left" | "center" | "right";

export const CANVAS_WIDTH = 432;
export const CANVAS_HEIGHT = 540;

export interface SlideContent {
  headline: string;
  body: string;
  imageUrl: string | null;
  imageAbove: boolean;
  showHeader: boolean;
  layout: SlideLayout;
  coverImageUrl: string | null;
  coverVariant: ImageCoverVariant;
  swipeText: string;
  gridTexts: [string, string, string, string];
  gridBolds: [boolean, boolean, boolean, boolean];
  gridSpacing: number;
  textAlign: TextAlignment;
  slideBgColor: string | null;
  slideTextColor: string | null;
  slideHeadlineColor: string | null;
  slideBodyColor: string | null;
  swipeTextColor: string | null;
  showCounter: boolean;
}

export function createSlide(partial: Partial<SlideContent> = {}): SlideContent {
  return {
    headline: "",
    body: "",
    imageUrl: null,
    imageAbove: true,
    showHeader: true,
    layout: "textPost",
    coverImageUrl: null,
    coverVariant: "logoMid",
    swipeText: "",
    gridTexts: ["", "", "", ""],
    gridBolds: [false, false, false, false],
    gridSpacing: 1.4,
    textAlign: "left",
    slideBgColor: null,
    slideTextColor: null,
    slideHeadlineColor: null,
    slideBodyColor: null,
    swipeTextColor: null,
    showCounter: true,
    ...partial,
  };
}

export interface CreatorPreset {
  name: string;
  bgColor: string;
  textColor: string;
  nameFont: string;
  handleFont: string;
  bodyFont: string;
  counterFont: string;
}

export const AVAILABLE_FONTS = [
  "Inter",
  "Poppins",
  "Montserrat",
  "Playfair Display",
  "Lora",
  "Roboto Slab",
  "Oswald",
  "Bebas Neue",
  "Archivo",
  "Space Grotesk",
  "DM Sans",
  "Libre Baskerville",
];

export const CREATOR_PRESETS: CreatorPreset[] = [
  { name: "Clean", bgColor: "#FFFFFF", textColor: "#101012", nameFont: "Inter", handleFont: "Inter", bodyFont: "Inter", counterFont: "Inter" },
  { name: "Dark", bgColor: "#0E0E12", textColor: "#F4F4F6", nameFont: "Space Grotesk", handleFont: "DM Sans", bodyFont: "DM Sans", counterFont: "Space Grotesk" },
  { name: "Editorial", bgColor: "#F5F1E8", textColor: "#1A1A1A", nameFont: "Playfair Display", handleFont: "Lora", bodyFont: "Lora", counterFont: "Playfair Display" },
  { name: "Bold Blue", bgColor: "#236BF7", textColor: "#FFFFFF", nameFont: "Montserrat", handleFont: "Montserrat", bodyFont: "Poppins", counterFont: "Montserrat" },
  { name: "Punch", bgColor: "#FCE300", textColor: "#101012", nameFont: "Oswald", handleFont: "Archivo", bodyFont: "Archivo", counterFont: "Bebas Neue" },
];

export const BACKGROUND_SWATCHES = [
  "#FFFFFF", "#0E0E12", "#236BF7", "#111B2E", "#F5F1E8",
  "#FCE300", "#FF5A5F", "#1DB954", "#6C2BD9", "#EC4899",
];

export const HIGHLIGHT_SWATCHES = [
  "#FFF176", "#FFCC80", "#A5D6A7", "#80DEEA", "#CF94DA", "#EF9A9A", "#FFFFFF", "#000000",
];

export interface PostStyle {
  avatarUrl: string | null;
  profileName: string;
  handle: string;
  avatarRadius: number;
  showVerifiedBadge: boolean;
  logoUrl: string | null;
  defaultLayout: SlideLayout;
  centerContent: boolean;
  nameFont: string;
  handleFont: string;
  bodyFont: string;
  counterFont: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  bodyBold: boolean;
  bodyItalic: boolean;
  bodyUnderline: boolean;
  highlightColor: string;
  bgColor: string;
  textColor: string;
  headlineColor: string | null;
  bodyColor: string | null;
  showArrows: boolean;
  bodyFontSize: number;
  slides: SlideContent[];
}

export function createPostStyle(): PostStyle {
  return {
    avatarUrl: null,
    profileName: "Seu Nome",
    handle: "@seuperfil",
    avatarRadius: 26,
    showVerifiedBadge: false,
    logoUrl: null,
    defaultLayout: "textPost",
    centerContent: true,
    nameFont: "Inter",
    handleFont: "Inter",
    bodyFont: "Inter",
    counterFont: "Inter",
    bold: true,
    italic: false,
    underline: false,
    bodyBold: false,
    bodyItalic: false,
    bodyUnderline: false,
    highlightColor: "#FFF176",
    bgColor: "#FFFFFF",
    textColor: "#101012",
    headlineColor: null,
    bodyColor: null,
    showArrows: true,
    bodyFontSize: 30,
    slides: [],
  };
}

export function resolveBg(slide: SlideContent, style: PostStyle): string {
  return slide.slideBgColor ?? style.bgColor;
}

export function resolveText(slide: SlideContent, style: PostStyle): string {
  return slide.slideTextColor ?? style.textColor;
}

export function resolveHeadlineColor(slide: SlideContent, style: PostStyle): string {
  return slide.slideHeadlineColor ?? slide.slideTextColor ?? style.headlineColor ?? style.textColor;
}

export function resolveBodyColor(slide: SlideContent, style: PostStyle): string {
  return (
    slide.slideBodyColor ??
    (slide.slideTextColor ? withAlpha(slide.slideTextColor, 0.72) : null) ??
    style.bodyColor ??
    withAlpha(style.textColor, 0.72)
  );
}

export function withAlpha(hex: string, alpha: number): string {
  const clean = hex.replace("#", "");
  const r = parseInt(clean.slice(0, 2), 16);
  const g = parseInt(clean.slice(2, 4), 16);
  const b = parseInt(clean.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// ── Parser de slides gerados pela IA ──────────────────────────────────────────

export function parseSlides(output: string, defaultLayout: SlideLayout = "textPost"): SlideContent[] {
  const block = firstJsonBlock(output) ?? output.trim();
  try {
    const decoded = JSON.parse(block);
    if (decoded && Array.isArray(decoded.slides)) {
      const slides: SlideContent[] = [];
      for (const raw of decoded.slides) {
        if (raw && typeof raw === "object") {
          const headline = String(raw.headline ?? "").trim();
          const body = String(raw.body ?? "").trim();
          const swipeText = String(raw.swipeText ?? raw.swipe_text ?? "").trim();
          if (headline || body) {
            slides.push(createSlide({ headline, body, layout: defaultLayout, swipeText }));
          }
        } else if (typeof raw === "string" && raw.trim()) {
          slides.push(createSlide({ headline: raw.trim(), layout: defaultLayout }));
        }
      }
      if (slides.length > 0) return slides;
    }
  } catch {
    // fall through to heuristic fallback
  }
  return fallbackSlides(output, defaultLayout);
}

function firstJsonBlock(text: string): string | null {
  const matches = [...text.matchAll(/```(?:\w*\n)?([\s\S]+?)```/g)];
  if (matches.length === 0) return null;
  for (const m of matches) {
    const content = m[1]?.trim() ?? "";
    if (content.startsWith("{") && content.includes('"slides"')) return content;
  }
  return matches[0][1]?.trim() ?? null;
}

function fallbackSlides(output: string, defaultLayout: SlideLayout): SlideContent[] {
  const cleaned = output.replace(/```[\s\S]*?```/g, "").trim();
  if (!cleaned) return [];
  const chunks = cleaned
    .split(/\n\s*\n/)
    .map((c) => c.trim())
    .filter(Boolean);
  if (chunks.length === 0) return [createSlide({ headline: cleaned })];
  return chunks.map((chunk) => {
    const lines = chunk.split("\n");
    const headline = lines[0].replace(/^#+\s*/, "").trim();
    const body = lines.slice(1).join("\n").trim();
    return createSlide({ headline, body, layout: defaultLayout });
  });
}
