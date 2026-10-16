/**
 * Shared error keys. RPCs raise these as the exception message with an SQLSTATE.
 * The UI maps a key to a localized message; never leak SQL internals to the UI.
 */

export const ERROR_CODES = {
  forbidden: "42501",
  notFound: "P0002",
  invalidInput: "22023",
  conflict: "23505",
} as const;

/** Canonical error keys raised by RPCs / edge functions. */
export const ERROR_KEYS = {
  forbidden: "forbidden",
  mfaRequired: "mfa_required",
  leaseNotFound: "lease_not_found",
  unitNotFound: "unit_not_found",
  unitNotVacant: "unit_not_vacant",
  invalidAmount: "invalid_amount",
  paymentNotFound: "payment_not_found",
  cannotDemoteLastOwner: "cannot_demote_last_owner",
  itemNotFound: "item_not_found",
  insufficientStock: "insufficient_stock",
  negativeBalance: "negative_balance",
  invitationNotFound: "invitation_not_found",
  invitationExpired: "invitation_expired",
  invalidToken: "invalid_token",
  alreadyMember: "already_member",
  rateLimited: "rate_limited",
} as const;

export type ErrorKey = (typeof ERROR_KEYS)[keyof typeof ERROR_KEYS];

export interface AppError {
  key: ErrorKey | string;
  code: string; // SQLSTATE
  message: string;
}

/** Build an AppError from a caught value (PostgREST error shape or string). */
export function normalizeError(err: unknown): AppError {
  if (err && typeof err === "object" && "message" in err) {
    const e = err as { message?: string; code?: string; hint?: string };
    const key = e.message ?? "unknown_error";
    const code = e.code ?? ERROR_CODES.invalidInput;
    return { key, code, message: key };
  }
  if (typeof err === "string") return { key: err, code: ERROR_CODES.invalidInput, message: err };
  return { key: "unknown_error", code: ERROR_CODES.invalidInput, message: "unknown_error" };
}

/** i18n message keys the UI should define for each error key. */
export const ERROR_I18N_KEYS: Record<string, string> = {
  [ERROR_KEYS.forbidden]: "error.forbidden",
  [ERROR_KEYS.mfaRequired]: "error.mfaRequired",
  [ERROR_KEYS.leaseNotFound]: "error.leaseNotFound",
  [ERROR_KEYS.unitNotFound]: "error.unitNotFound",
  [ERROR_KEYS.unitNotVacant]: "error.unitNotVacant",
  [ERROR_KEYS.invalidAmount]: "error.invalidAmount",
  [ERROR_KEYS.paymentNotFound]: "error.paymentNotFound",
  [ERROR_KEYS.cannotDemoteLastOwner]: "error.cannotDemoteLastOwner",
  [ERROR_KEYS.itemNotFound]: "error.itemNotFound",
  [ERROR_KEYS.insufficientStock]: "error.insufficientStock",
  [ERROR_KEYS.negativeBalance]: "error.negativeBalance",
  [ERROR_KEYS.invitationNotFound]: "error.invitationNotFound",
  [ERROR_KEYS.invitationExpired]: "error.invitationExpired",
  [ERROR_KEYS.invalidToken]: "error.invalidToken",
  [ERROR_KEYS.alreadyMember]: "error.alreadyMember",
  [ERROR_KEYS.rateLimited]: "error.rateLimited",
};
