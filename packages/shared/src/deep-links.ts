/**
 * Deep-link parsing for the authentication callbacks GoTrue emails.
 *
 * The password-recovery email (and, if confirmations are ever switched on, the
 * sign-up confirmation email) links back to `fam://reset-password` with the
 * classic *implicit* grant: the tokens ride in the URI **fragment**
 * (`#access_token=…&refresh_token=…&type=recovery`), which a browser never sends
 * to a server. Both clients therefore have to read the fragment themselves and
 * hand the tokens to their auth SDK (`setSession`).
 *
 * Kept in the shared package so the React Native and Flutter clients use one
 * implementation and the parsing is unit-tested without a device.
 */

export interface RecoveryTokens {
  accessToken: string;
  refreshToken: string;
  /** `recovery` for a reset link; absent for some providers. */
  type?: string;
}

/** Auth parameters that mark a deep link as an auth callback. */
const AUTH_PARAM_KEYS = [
  "access_token",
  "refresh_token",
  "code",
  "error",
  "error_code",
  "error_description",
] as const;

/**
 * True when a link carries auth callback parameters, in the query *or* the
 * fragment. Used to tell a recovery link apart from the invitation link
 * (`fam://invite?token=…`), which the router handles itself.
 */
export function isAuthCallbackUrl(url: string): boolean {
  const query = url.split("#")[0]?.split("?")[1] ?? "";
  const fragment = url.split("#")[1] ?? "";
  return [...AUTH_PARAM_KEYS].some(
    (key) => query.includes(`${key}=`) || fragment.includes(`${key}=`),
  );
}

/**
 * Extract the implicit-grant tokens from a recovery/confirmation link, or null
 * when the link carries none (an expired or already-used link arrives bare, or
 * with an `error_description` instead). Tolerates both the fragment form and a
 * query string, and ignores anything else on the URI.
 */
export function parseRecoveryTokens(url: string): RecoveryTokens | null {
  const fragment = url.split("#")[1] ?? "";
  const query = url.split("#")[0]?.split("?")[1] ?? "";
  // Prefer the fragment (implicit grant); fall back to the query for links that
  // put the tokens there.
  const params = fragment.length > 0 ? fragment : query;
  const parsed = new URLSearchParams(params);
  const accessToken = parsed.get("access_token");
  const refreshToken = parsed.get("refresh_token");
  if (!accessToken || !refreshToken) return null;
  const type = parsed.get("type") ?? undefined;
  return { accessToken, refreshToken, ...(type ? { type } : {}) };
}
