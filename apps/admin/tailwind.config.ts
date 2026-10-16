import type { Config } from "tailwindcss";

/** Design tokens from the approved design (section 6 of the brief). */
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        midnight: "#061538",
        navy: "#0A2260",
        royal: "#1D4ED8",
        "royal-mid": "#123A9C",
        ice: "#BFD4FF",
        tint: "#E6EEFF",
        background: "#F4F7FE",
        border: "#DDE5F5",
        text: "#0B1B3F",
        "text-muted": "#4A5B82",
        danger: "#B42318",
        "danger-bg": "#FDECEC",
        chip: "#3D4E78",
        "chip-bg": "#EEF1F8",
      },
      fontFamily: {
        sans: ["Manrope", "system-ui", "sans-serif"],
        display: ["Playfair Display", "Georgia", "serif"],
      },
      borderRadius: {
        card: "20px",
        btn: "16px",
      },
      boxShadow: {
        card: "0 12px 30px rgba(10,34,96,0.10)",
      },
    },
  },
  plugins: [],
};

export default config;
