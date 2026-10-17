/**
 * Small message catalogue. `en` is the source of truth; other locales fall back
 * until translations land. Error keys mirror `@fam/shared` `ERROR_I18N_KEYS`.
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

  // ---- errors: result codes raised by RPCs / edge functions ----
  "error.forbidden": "You do not have permission to do that.",
  "error.mfaRequired": "Multi-factor authentication is required.",
  "error.unitNotVacant": "That unit already has an active lease.",
  "error.invalidAmount": "Enter a valid amount.",
  "error.insufficientStock": "Not enough stock available.",
  "error.negativeBalance": "Stock cannot go below zero.",
  "error.cannotDemoteLastOwner": "You cannot demote the last owner.",
  "error.rateLimited": "Too many requests. Please wait and try again.",
  "error.leaseNotFound": "That lease no longer exists.",
  "error.unitNotFound": "That unit no longer exists.",
  "error.paymentNotFound": "That payment no longer exists.",
  "error.itemNotFound": "That item no longer exists.",
  "error.invitationNotFound": "That invitation could not be found.",
  "error.invitationExpired": "That invitation has expired. Ask for a new one.",
  "error.invalidToken": "That link is no longer valid.",
  "error.alreadyMember": "This person is already a member.",
  "error.unknown": "Something went wrong. Please try again.",

  // ---- auth (Supabase AuthError codes) ----
  "error.invalidCredentials": "Incorrect email or password.",
  "error.emailNotConfirmed": "Confirm your email before signing in.",
  "error.alreadyRegistered": "That account already exists. Try signing in.",
  "error.weakPassword": "Choose a stronger password.",

  // ---- errors: transport / protocol level ----
  "error.network": "No connection. Check your network and try again.",
  "error.conflict": "That action conflicts with existing data.",
  "error.invalidInput": "Check the details and try again.",
  "error.notFound": "We could not find what you were looking for.",
  "error.conflictDuplicate": "That already exists.",
  "error.sessionExpired": "Your session has expired. Please sign in again.",
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

export function getLocale(): Locale {
  return current;
}

export function t(key: string, fallback?: string): string {
  return messages[current][key] ?? fallback ?? key;
}
