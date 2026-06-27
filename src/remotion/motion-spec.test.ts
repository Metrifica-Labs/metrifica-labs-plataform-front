import { describe, expect, it } from "vitest";
import {
  EXAMPLE_SPEC,
  FORMAT_DIMENSIONS,
  Meta,
  SPEC_VERSION,
  resolveDimensions,
  totalDurationInFrames,
  validateMotionSpec,
} from "./motion-spec";

describe("MotionSpec", () => {
  it("aceita o fixture canônico", () => {
    const result = validateMotionSpec(EXAMPLE_SPEC);
    expect(result.success).toBe(true);
  });

  it("aplica defaults nos campos omitidos", () => {
    const result = validateMotionSpec({
      specVersion: SPEC_VERSION,
      scenes: [
        {
          id: "s1",
          durationInFrames: 30,
          elements: [{ type: "text", id: "t1", content: "oi" }],
        },
      ],
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    const el = result.data.scenes[0].elements[0];
    expect(el.type).toBe("text");
    // defaults vindos do schema
    expect(el.enter.kind).toBe("fade");
    expect(el.enter.token).toBe("normal");
    expect(el.position.anchor).toBe("center");
    expect(result.data.meta.format).toBe("reel");
    expect(result.data.meta.fps).toBe(30);
  });

  it("rejeita easing fora do vocabulário da skill", () => {
    const result = validateMotionSpec({
      specVersion: SPEC_VERSION,
      scenes: [
        {
          id: "s1",
          durationInFrames: 30,
          elements: [
            {
              type: "text",
              id: "t1",
              content: "oi",
              enter: { easing: "ease-in-out" },
            },
          ],
        },
      ],
    });
    expect(result.success).toBe(false);
  });

  it("rejeita um vídeo sem cenas", () => {
    const result = validateMotionSpec({ specVersion: SPEC_VERSION, scenes: [] });
    expect(result.success).toBe(false);
  });

  it("rejeita specVersion diferente do suportado", () => {
    const result = validateMotionSpec({
      specVersion: 999,
      scenes: [{ id: "s1", durationInFrames: 30, elements: [] }],
    });
    expect(result.success).toBe(false);
  });

  it("rejeita cor hex inválida", () => {
    const result = validateMotionSpec({
      specVersion: SPEC_VERSION,
      meta: { backgroundColor: "blue" },
      scenes: [{ id: "s1", durationInFrames: 30, elements: [] }],
    });
    expect(result.success).toBe(false);
  });

  it("rejeita elemento de tipo desconhecido (união discriminada)", () => {
    const result = validateMotionSpec({
      specVersion: SPEC_VERSION,
      scenes: [
        {
          id: "s1",
          durationInFrames: 30,
          elements: [{ type: "video", id: "v1", src: "https://x.test/a.mp4" }],
        },
      ],
    });
    expect(result.success).toBe(false);
  });
});

describe("totalDurationInFrames", () => {
  it("soma a duração de todas as cenas", () => {
    expect(totalDurationInFrames(EXAMPLE_SPEC)).toBe(60 + 75);
  });
});

describe("resolveDimensions", () => {
  it("deriva dimensões do formato quando width/height ausentes", () => {
    const meta = Meta.parse({ format: "square" });
    expect(resolveDimensions(meta)).toEqual(FORMAT_DIMENSIONS.square);
  });

  it("respeita width/height explícitos sobre o formato", () => {
    const meta = Meta.parse({ format: "reel", width: 720, height: 1280 });
    expect(resolveDimensions(meta)).toEqual({ width: 720, height: 1280 });
  });
});
