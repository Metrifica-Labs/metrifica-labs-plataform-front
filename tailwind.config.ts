import type { Config } from "tailwindcss";
import typography from "@tailwindcss/typography";

export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#5B5FEF",
          hover: "#4C4FE0",
          soft: "#5B5FEF1A",
        },
        accent: "#14B8A6",
        dark: {
          surface: "#121214",
          card: "#1A1A1F",
          raised: "#212126",
          border: "#28282F",
          onSurface: "#F3F3F5",
        },
        light: {
          surface: "#F7F7F9",
          card: "#FFFFFF",
          raised: "#FCFCFD",
          border: "#E7E7EC",
          "border-strong": "#D3D4DC",
          onSurface: "#16161A",
        },
      },
      fontFamily: {
        sans: ["Plus Jakarta Sans", "sans-serif"],
        mono: ["JetBrains Mono", "monospace"],
      },
      borderRadius: {
        md: "8px",
        lg: "10px",
        xl: "14px",
        "2xl": "18px",
      },
      boxShadow: {
        soft: "0 1px 2px 0 rgb(15 15 20 / 0.04), 0 1px 1px 0 rgb(15 15 20 / 0.03)",
        panel: "0 4px 16px -2px rgb(15 15 20 / 0.08), 0 1px 2px 0 rgb(15 15 20 / 0.04)",
        floating: "0 12px 32px -8px rgb(15 15 20 / 0.18), 0 2px 6px -1px rgb(15 15 20 / 0.06)",
        "glow-primary": "0 0 0 1px rgb(91 95 239 / 0.4), 0 4px 20px -4px rgb(91 95 239 / 0.45)",
      },
    },
  },
  plugins: [typography],
} satisfies Config;
