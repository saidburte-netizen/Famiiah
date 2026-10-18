import { ERROR_I18N_KEYS, normalizeError } from "@fam/shared";
import { t } from "@/i18n";

const NETWORK_RE =
  /network request failed|failed to fetch|network error|timed?\s*out|timeout|offline|socket|connection (?:refused|reset|closed)/i;

/** Supabase *auth* error codes (distinct from SQLSTATE) → i18n keys. */
const AUTH_CODES: Record<string, string> = {
const AUTH_CODES: Record<string, string> = {
  invalid_credentials: "error.invalidCredentials",
  email_not_confirmed: "error.emailNotConfirmed",
  phone_not_confirmed: "error.phoneNotConfirmed",
  email_exists: "error.alreadyRegistered",
  phone_exists: "error.alreadyRegistered",
  user_already_exists: "error.alreadyRegistered",
  weak_password: "error.weakPassword",
  over_email_send_rate_limit: "error.rateLimited",
  over_sms_send_rate_limit: "error.rateLimited",
  over_request_rate_limit: "error.rateLimited",
  session_not_found: "error.sessionExpired",
  refresh_token_not_found: "error.sessionExpired",
  session_expired: "error.sessionExpired",
  // Sign-up failures worth naming instead of "Something went wrong": a rejected
  // address (Supabase validates the domain) or sign-ups/providers switched off.
  email_address_invalid: "error.emailInvalid",
  signup_disabled: "error.signupDisabled",
  email_provider_disabled: "error.signupDisabled",
  phone_provider_disabled: "error.phoneProviderDisabled",
  sms_send_failed: "error.smsFailed",
  validation_failed: "error.invalidInput",
  otp_expired: "error.invalidToken",
};

function rawMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (typeof err === "string") return err;
  if (err && typeof err === "object" && "message" in err) {
    const m = (err as { message?: unknown }).message;
    if (typeof m === "string") return m;
  }
  return "";
}

/** fetch/Realtime failures surface as TypeError on RN; also catch by text. */
export function isNetworkError(err: unknown): boolean {
  if (err instanceof TypeError) return true;
  return NETWORK_RE.test(rawMessage(err));
}

/** SQLSTATE → message, for codes that aren't tied to a specific error key. */
const SQLSTATE_I18N: Record<string, string> = {
  "42501": "error.forbidden",
  "23505": "error.conflict",
  "23514": "error.invalidInput",
  "22023": "error.invalidInput",
  P0002: "error.notFound",
  PGRST301: "error.sessionExpired",
};

/**
 * Turn anything a Supabase/PostgREST/fetch call threw into a short, localized
 * message. RPCs raise a canonical error key as the message (see `@fam/shared`
 * errors); we translate that. Everything else degrades to a generic string so
 * SQL internals never reach the user.
 */
export function userMessage(err: unknown): string {
  if (!err) return t("error.unknown");
  if (isNetworkError(err)) return t("error.network");

  const { key, code } = normalizeError(err);
  const byKey = ERROR_I18N_KEYS[key];
  if (byKey) return t(byKey);

  const auth = AUTH_CODES[key] ?? AUTH_CODES[code];
  if (auth) return t(auth);

  const fallback = SQLSTATE_I18N[key] ?? SQLSTATE_I18N[code];
  return fallback ? t(fallback) : t("error.unknown");
}

/** Non-PII tag for logs/Sentry; never the raw message. */
export function errorTag(err: unknown): string {
  if (isNetworkError(err)) return "network";
  const { key, code } = normalizeError(err);
  return key && key !== "unknown_error" ? key : code;
}
