import { describe, it, expect } from "vitest";
import { render } from "@testing-library/react";
import { renderMarkup } from "@/features/instagram-post/markup";

function Wrapper({ text, highlight = "#FFF176" }: { text: string; highlight?: string }) {
  return <div data-testid="root">{renderMarkup(text, {}, highlight)}</div>;
}

describe("renderMarkup", () => {
  it("renders plain text untouched", () => {
    const { getByTestId } = render(<Wrapper text="hello world" />);
    expect(getByTestId("root").textContent).toBe("hello world");
  });

  it("applies italic style for [i] tags", () => {
    const { container } = render(<Wrapper text="this is [i]italic[/i] text" />);
    const styled = Array.from(container.querySelectorAll("span")).find(
      (el) => el.textContent === "italic"
    );
    expect(styled?.style.fontStyle).toBe("italic");
  });

  it("applies underline for [u] tags", () => {
    const { container } = render(<Wrapper text="[u]underlined[/u]" />);
    const styled = Array.from(container.querySelectorAll("span")).find(
      (el) => el.textContent === "underlined"
    );
    expect(styled?.style.textDecoration).toBe("underline");
  });

  it("applies bold weight for [b] tags", () => {
    const { container } = render(<Wrapper text="[b]bold[/b]" />);
    const styled = Array.from(container.querySelectorAll("span")).find(
      (el) => el.textContent === "bold"
    );
    expect(styled?.style.fontWeight).toBe("700");
  });

  it("highlights [hl] with the default highlight color", () => {
    const { container } = render(<Wrapper text="[hl]marked[/hl]" highlight="#FFF176" />);
    const styled = Array.from(container.querySelectorAll("span")).find(
      (el) => el.textContent === "marked"
    );
    expect(styled?.style.backgroundColor).toBe("rgba(255, 241, 118, 0.6)");
  });

  it("supports an explicit hex color in [hl=#RRGGBB]", () => {
    const { container } = render(<Wrapper text="[hl=#FF0000]red[/hl]" />);
    const styled = Array.from(container.querySelectorAll("span")).find(
      (el) => el.textContent === "red"
    );
    expect(styled?.style.backgroundColor).toBe("rgba(255, 0, 0, 0.6)");
  });

  it("matches the outer tag to the first closing tag of the same type it finds", () => {
    // Non-backtracking pairing: content is matched non-greedily up to the
    // first closing tag of ANY type, so genuinely mixed-tag nesting
    // (e.g. [i][u]x[/u][/i]) does not pair correctly and falls through as
    // literal text. This mirrors the original Dart parseMarkup exactly.
    const { getByTestId } = render(<Wrapper text="[i][u]both[/u][/i]" />);
    expect(getByTestId("root").textContent).toBe("[i][u]both[/u][/i]");
  });

  it("ignores mismatched open/close tags", () => {
    const { getByTestId } = render(<Wrapper text="[i]oops[/u]" />);
    expect(getByTestId("root").textContent).toBe("[i]oops[/u]");
  });
});
