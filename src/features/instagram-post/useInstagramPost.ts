import { useState } from "react";
import {
  createPostStyle,
  createSlide,
  parseSlides,
  type PostStyle,
  type SlideContent,
} from "@/features/instagram-post/instagram-post-style";

export function useInstagramPost() {
  const [style, setStyle] = useState<PostStyle>(() => ({
    ...createPostStyle(),
    slides: [createSlide({ headline: "Seu título aqui", body: "Texto de apoio." })],
  }));
  const [activeIndex, setActiveIndex] = useState(0);

  function updateStyle(patch: Partial<PostStyle>) {
    setStyle((s) => ({ ...s, ...patch }));
  }

  function updateSlide(index: number, patch: Partial<SlideContent>) {
    setStyle((s) => ({
      ...s,
      slides: s.slides.map((slide, i) => (i === index ? { ...slide, ...patch } : slide)),
    }));
  }

  function addSlide() {
    setStyle((s) => ({ ...s, slides: [...s.slides, createSlide({ layout: s.defaultLayout })] }));
    setActiveIndex(style.slides.length);
  }

  function removeSlide(index: number) {
    setStyle((s) => ({ ...s, slides: s.slides.filter((_, i) => i !== index) }));
    setActiveIndex((i) => Math.max(0, Math.min(i, style.slides.length - 2)));
  }

  function loadFromGeneration(output: string) {
    const slides = parseSlides(output, style.defaultLayout);
    if (slides.length > 0) {
      setStyle((s) => ({ ...s, slides }));
      setActiveIndex(0);
    }
  }

  function loadSlides(slides: SlideContent[]) {
    setStyle((s) => ({ ...s, slides }));
    setActiveIndex(0);
  }

  function updateGridText(index: number, blockIdx: number, text: string) {
    setStyle((s) => {
      const slide = s.slides[index];
      if (!slide) return s;
      const gridTexts = [...slide.gridTexts] as SlideContent["gridTexts"];
      gridTexts[blockIdx] = text;
      const slides = [...s.slides];
      slides[index] = { ...slide, gridTexts };
      return { ...s, slides };
    });
  }

  function updateGridBold(index: number, blockIdx: number, bold: boolean) {
    setStyle((s) => {
      const slide = s.slides[index];
      if (!slide) return s;
      const gridBolds = [...slide.gridBolds] as SlideContent["gridBolds"];
      gridBolds[blockIdx] = bold;
      const slides = [...s.slides];
      slides[index] = { ...slide, gridBolds };
      return { ...s, slides };
    });
  }

  return {
    style,
    activeIndex,
    setActiveIndex,
    updateStyle,
    updateSlide,
    addSlide,
    removeSlide,
    loadFromGeneration,
    loadSlides,
    updateGridText,
    updateGridBold,
  };
}
