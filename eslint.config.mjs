// Flat ESLint config shared by the workspace packages (ESLint 9).
// Next.js admin uses `next lint` with eslint-config-next and ignores this.
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import globals from "globals";

export default tseslint.config(
  { ignores: ["**/dist/**", "**/.next/**", "**/.expo/**", "**/node_modules/**", "**/*.config.*"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      globals: { ...globals.node, ...globals.browser },
    },
    rules: {
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
      "@typescript-eslint/no-explicit-any": "warn",
    },
  },
  // Edge Functions run on Deno with its own globals.
  {
    files: ["supabase/functions/**/*.ts"],
    languageOptions: { globals: { Deno: "readonly" } },
  },
);
