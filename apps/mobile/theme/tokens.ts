/**
 * Design tokens from the approved design (section 6 of the brief).
 * Light theme first; dark theme is a later option.
 */
export const colors = {
  midnight: "#061538",
  navy: "#0A2260",
  royal: "#1D4ED8",
  royalMid: "#123A9C",
  ice: "#BFD4FF",
  tint: "#E6EEFF",
  background: "#F4F7FE",
  white: "#FFFFFF",
  border: "#DDE5F5",
  text: "#0B1B3F",
  textMuted: "#4A5B82",
  danger: "#B42318",
  dangerBg: "#FDECEC",
  chip: "#3D4E78",
  chipBg: "#EEF1F8",
} as const;

export const radius = {
  card: 20,
  button: 16,
  pill: 999,
} as const;

export const spacing = (n: number) => n * 4;

export const font = {
  display: "PlayfairDisplay_700Bold",
  regular: "Manrope_400Regular",
  medium: "Manrope_500Medium",
  semibold: "Manrope_600SemiBold",
  bold: "Manrope_700Bold",
  extrabold: "Manrope_800ExtraBold",
} as const;

export const gradients = {
  primary: ["#1D4ED8", "#0A2260"] as const,
} as const;

/** Minimum touch target per accessibility guidance. */
export const MIN_TOUCH = 44;
