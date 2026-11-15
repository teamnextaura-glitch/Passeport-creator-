import type { Config } from "tailwindcss";

// Design tokens figés (document de conception, §0.1 et §8.4)
const config: Config = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "rgb(var(--bg) / <alpha-value>)",
        text: "rgb(var(--text) / <alpha-value>)",
        muted: "rgb(var(--muted) / <alpha-value>)",
        primary: "#7C5CFF",
        secondary: "#3DF5FF",
        gold: "#E8C77A",
        demo: { base: "#8E88A8", soft: "#C9C5DA" }, // palette désaturée des démos
      },
      fontFamily: {
        display: ["var(--font-clash)", "system-ui", "sans-serif"],
        sans: ["var(--font-satoshi)", "system-ui", "sans-serif"],
      },
      fontSize: {
        sm: ["0.8rem", { lineHeight: "1.5" }],
        base: ["1rem", { lineHeight: "1.6" }],
        lg: ["1.25rem", { lineHeight: "1.5" }],
        xl: ["1.563rem", { lineHeight: "1.4" }],
        "2xl": ["1.953rem", { lineHeight: "1.3" }],
        "3xl": ["2.441rem", { lineHeight: "1.2" }],
        "4xl": ["3.052rem", { lineHeight: "1.1" }],
        hero: ["clamp(3rem, 9vw, 10rem)", { lineHeight: "0.95", letterSpacing: "-0.03em" }],
      },
      borderRadius: { card: "12px", section: "24px", pill: "999px" },
      boxShadow: { premium: "0 24px 80px rgba(124,92,255,0.15)" },
      transitionTimingFunction: { premium: "cubic-bezier(0.16,1,0.3,1)" },
      transitionDuration: { premium: "600ms" },
      backgroundImage: {
        halo: "radial-gradient(60% 50% at 50% 0%, rgba(124,92,255,0.25), transparent 70%)",
      },
      keyframes: {
        drift: { "0%": { backgroundPosition: "0 0" }, "100%": { backgroundPosition: "48px 48px" } },
        pulseHalo: { "0%,100%": { opacity: "0.55" }, "50%": { opacity: "0.9" } },
      },
      animation: {
        drift: "drift 12s linear infinite",
        "pulse-halo": "pulseHalo 8s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
export default config;
