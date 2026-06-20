import type { Config } from "tailwindcss";

export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#6366F1",
        secondary: "#0EA5A4",
        dark: {
          surface: "#0F0F14",
          card: "#16161F",
          border: "#1E1E2E",
        },
        light: {
          surface: "#F1F5F9",
          card: "#FFFFFF",
          border: "#E2E8F0",
          "border-strong": "#CBD5E1",
          onSurface: "#0F172A",
        },
      },
      fontFamily: {
        sans: ["Inter", "sans-serif"],
      },
    },
  },
  plugins: [],
} satisfies Config;
