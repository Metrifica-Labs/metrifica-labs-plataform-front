import { useEffect, type ReactNode } from "react";
import { useThemeStore } from "@/core/theme/theme-store";

export function ThemeProvider({ children }: { children: ReactNode }) {
  const mode = useThemeStore((s) => s.mode);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", mode === "dark");
  }, [mode]);

  return children;
}
