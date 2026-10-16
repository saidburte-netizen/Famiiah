/**
 * Money helpers. All monetary values are handled as integer cents internally to
 * avoid floating-point error. Storage in the DB is `numeric(14,2)`; the DB layer
 * is the source of truth, these helpers are for client-side math/formatting.
 *
 * ETB uses 2 decimals. Never use JS floats for money.
 */

export const CURRENCY_DECIMALS: Record<string, number> = {
  ETB: 2,
  USD: 2,
  EUR: 2,
};

export type MinorUnit = bigint;

/** Parse a decimal string ("1234.56") into integer minor units (123456n). */
export function toMinorUnits(value: string, decimals = 2): MinorUnit {
  const trimmed = value.trim();
  if (trimmed === "") throw new Error("empty_amount");
  if (!/^-?\d+(\.\d+)?$/.test(trimmed)) throw new Error("invalid_amount");
  const negative = trimmed.startsWith("-");
  const [wholeRaw = "0", fracRaw = ""] = trimmed.replace("-", "").split(".");
  const frac = (fracRaw + "0".repeat(decimals)).slice(0, decimals);
  // Reject more precision than we can represent.
  if (fracRaw.length > decimals && /[1-9]/.test(fracRaw.slice(decimals))) {
    throw new Error("too_many_decimals");
  }
  const combined = BigInt(wholeRaw + frac);
  return negative ? -combined : combined;
}

/** Format integer minor units back into a canonical decimal string. */
export function fromMinorUnits(minor: MinorUnit, decimals = 2): string {
  const negative = minor < 0n;
  const abs = negative ? -minor : minor;
  const s = abs.toString().padStart(decimals + 1, "0");
  const whole = s.slice(0, s.length - decimals);
  const frac = s.slice(s.length - decimals);
  const out = decimals > 0 ? `${whole}.${frac}` : whole;
  return negative ? `-${out}` : out;
}

/**
 * Parse a user-entered amount into a canonical decimal string with exactly
 * `decimals` places, suitable for sending to an RPC as a numeric arg.
 */
export function normalizeAmount(value: string, decimals = 2): string {
  return fromMinorUnits(toMinorUnits(value, decimals), decimals);
}

export function addAmounts(a: string, b: string, decimals = 2): string {
  return fromMinorUnits(toMinorUnits(a, decimals) + toMinorUnits(b, decimals), decimals);
}

export function subtractAmounts(a: string, b: string, decimals = 2): string {
  return fromMinorUnits(toMinorUnits(a, decimals) - toMinorUnits(b, decimals), decimals);
}

export function compareAmounts(a: string, b: string, decimals = 2): -1 | 0 | 1 {
  const ma = toMinorUnits(a, decimals);
  const mb = toMinorUnits(b, decimals);
  if (ma < mb) return -1;
  if (ma > mb) return 1;
  return 0;
}

export function isZero(a: string, decimals = 2): boolean {
  return toMinorUnits(a, decimals) === 0n;
}

/** Split `amount` across `weights` proportionally, remainder to the last part. */
export function allocateProportionally(amount: string, weights: number[], decimals = 2): string[] {
  const totalWeight = weights.reduce((s, w) => s + w, 0);
  if (totalWeight <= 0) return weights.map(() => fromMinorUnits(0n, decimals));
  const minor = toMinorUnits(amount, decimals);
  const results: MinorUnit[] = [];
  let allocated = 0n;
  for (let i = 0; i < weights.length - 1; i++) {
    const part = (minor * BigInt(Math.round(weights[i]! * 1000))) / BigInt(Math.round(totalWeight * 1000));
    results.push(part);
    allocated += part;
  }
  results.push(minor - allocated);
  return results.map((r) => fromMinorUnits(r, decimals));
}

export interface MoneyFormatOptions {
  currency?: string;
  locale?: string;
  decimals?: number;
}

/** Format a decimal string for display, e.g. "12,345.50 ETB". */
export function formatMoney(value: string, opts: MoneyFormatOptions = {}): string {
  const { currency = "ETB", locale = "en-ET", decimals = CURRENCY_DECIMALS[currency] ?? 2 } = opts;
  const minor = toMinorUnits(value, decimals);
  const negative = minor < 0n;
  const abs = negative ? -minor : minor;
  const s = abs.toString().padStart(decimals + 1, "0");
  const whole = s.slice(0, s.length - decimals).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  const frac = decimals > 0 ? `.${s.slice(s.length - decimals)}` : "";
  const num = `${negative ? "-" : ""}${whole}${frac}`;
  void locale; // locale-aware grouping can be layered in later via Intl.
  return `${num} ${currency}`;
}
