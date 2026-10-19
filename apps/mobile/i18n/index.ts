/**
 * Small message catalogue. `en` is the source of truth; other locales fall back
 * until translations land. Error keys mirror `@fam/shared` `ERROR_I18N_KEYS`.
 */
export type Locale = "en" | "am" | "om";

const en = {
  "app.name": "Fam",
  "auth.signIn": "Sign in",
  "auth.signUp": "Create account",
  "auth.handle": "@handle",
  "auth.acceptTerms": "I accept the terms",
  "auth.email": "Email",
  "auth.phone": "Phone",
  "auth.phoneOrEmail": "Phone or email",
  "auth.password": "Password",
  "auth.forgotPassword": "Forgot password?",
  "auth.remember": "Remember me",
  "auth.useBiometrics": "Unlock with biometrics",
  "auth.verifyPhoneTitle": "Confirm your phone",
  "auth.verifyPhoneBody": "Enter the 6-digit code we sent to",
  "auth.otpCode": "Code",
  "auth.verify": "Verify",
  "auth.resendCode": "Send a new code",
  "auth.codeSent": "A new code is on its way.",
  "auth.confirmEmail": "Check your email — we sent a confirmation link to finish signing up.",
  "auth.changeNumber": "Use a different number",
  "auth.resetPasswordTitle": "Choose a new password",
  "auth.newPassword": "New password",
  "auth.updatePassword": "Update password",
  "auth.passwordUpdated": "Your password has been updated.",
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
  "error.invalidCredentials": "Incorrect phone/email or password.",
  "error.emailNotConfirmed": "Confirm your email before signing in.",
  "error.phoneNotConfirmed": "Confirm your phone number before signing in.",
  "error.alreadyRegistered": "That account already exists. Try signing in.",
  "error.weakPassword": "Choose a stronger password.",
  "error.emailInvalid": "That email address was rejected. Check it and try again.",
  "error.invalidPhone": "Enter a valid phone number (09… or +251…).",
  "error.handleInvalid": "@handles are 3–24 letters, numbers or underscores and start with a letter.",
  "error.handleTaken": "That @handle is taken. Try another one.",
  "error.acceptTerms": "Accept the terms to create your account.",
  "error.signupDisabled": "New sign-ups are turned off for this app.",
  "error.phoneProviderDisabled": "Phone sign-up is not enabled for this app.",
  "error.smsFailed": "We could not send the SMS. Please try again.",

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
