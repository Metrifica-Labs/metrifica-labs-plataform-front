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
  };
}
