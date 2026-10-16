/**
 * Minimal i18n shell. English first; adding a locale is a data change only.
 * Keys intentionally mirror the error keys in @fam/shared.
 */
export type Locale = "en" | "am" | "om";

const en = {
  "app.name": "Fam",
  "auth.signIn": "Sign in",
  "auth.signUp": "Create account",
  "auth.email": "Email",
  "auth.phone": "Phone",
  "auth.password": "Password",
  "auth.forgotPassword": "Forgot password?",
  "auth.remember": "Remember me",
  "auth.useBiometrics": "Unlock with biometrics",
  "nav.home": "Home",
  "nav.properties": "Properties",
  "nav.tenants": "Tenants",
  "nav.rent": "Rent",
  "nav.admin": "Admin",
  "error.forbidden": "You do not have permission to do that.",
  "error.mfaRequired": "Multi-factor authentication is required.",
  "error.unitNotVacant": "That unit already has an active lease.",
  "error.invalidAmount": "Enter a valid amount.",
  "error.insufficientStock": "Not enough stock available.",
  "error.negativeBalance": "Stock cannot go below zero.",
  "error.cannotDemoteLastOwner": "You cannot demote the last owner.",
  "error.rateLimited": "Too many requests. Please wait and try again.",
  "error.unknown": "Something went wrong. Please try again.",
};

export const messages: Record<Locale, Record<string, string>> = {
  en,
  // Placeholder locales fall back to English until translations are supplied.
  am: en,
  om: en,
};

let current: Locale = "en";

export function setLocale(locale: Locale): void {
  current = locale;
}

export function t(key: string, fallback?: string): string {
  return messages[current][key] ?? fallback ?? key;
}
