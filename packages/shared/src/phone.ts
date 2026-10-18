/**
 * Ethiopian mobile numbers are typed in several shapes: `0912 345 678`,
 * `+251912345678`, `251912345678`, or bare `912345678`. Supabase Auth (GoTrue)
 * only accepts E.164, and it is the sign-in identifier, so both clients must
 * normalize the same way before calling `signUp` / `signInWithPassword`.
 */
const ETHIOPIAN_E164 = /^\+251[79]\d{8}$/;

/** Normalize an Ethiopian mobile number to E.164, or `null` when invalid. */
export function toE164(input: string | null | undefined): string | null {
  if (!input) return null;
  let s = input.replace(/[\s()[\]-]/g, "");
  if (s.startsWith("+")) s = s.slice(1);
  if (s.startsWith("00")) s = s.slice(2);
  let candidate: string;
  if (s.startsWith("251")) candidate = `+${s}`;
  else if (s.startsWith("0")) candidate = `+251${s.slice(1)}`;
  else candidate = `+251${s}`;
  return ETHIOPIAN_E164.test(candidate) ? candidate : null;
}

/** True for inputs the sign-in field should treat as an email, not a phone. */
export function looksLikeEmail(identifier: string): boolean {
  return identifier.includes("@");
}
