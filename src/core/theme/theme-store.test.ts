import { describe, it, expect, beforeEach } from "vitest";
import { useThemeStore } from "@/core/theme/theme-store";

beforeEach(() => {
  localStorage.clear();
  useThemeStore.setState({ mode: "light" });
});

describe("useThemeStore", () => {
  it("defaults to light mode", () => {
    expect(useThemeStore.getState().mode).toBe("light");
  });

  it("toggles between light and dark", () => {
    useThemeStore.getState().toggle();
    expect(useThemeStore.getState().mode).toBe("dark");
    useThemeStore.getState().toggle();
    expect(useThemeStore.getState().mode).toBe("light");
  });
});
