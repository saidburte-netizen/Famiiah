import { describe, it, expect } from "vitest";
import {
  toMinorUnits,
  fromMinorUnits,
  normalizeAmount,
  addAmounts,
  subtractAmounts,
  compareAmounts,
  allocateProportionally,
  formatMoney,
} from "./money";

describe("money", () => {
  it("parses and formats minor units round-trip", () => {
    expect(toMinorUnits("1234.56")).toBe(123456n);
    expect(fromMinorUnits(123456n)).toBe("1234.56");
    expect(toMinorUnits("0.05")).toBe(5n);
    expect(fromMinorUnits(5n)).toBe("0.05");
  });

  it("normalizes to 2 decimals", () => {
    expect(normalizeAmount("12")).toBe("12.00");
    expect(normalizeAmount("12.5")).toBe("12.50");
    expect(normalizeAmount("1234.5")).toBe("1234.50");
  });

  it("rejects excess precision", () => {
    expect(() => normalizeAmount("12.567")).toThrow("too_many_decimals");
  });

  it("rejects non-numeric input", () => {
    expect(() => toMinorUnits("abc")).toThrow("invalid_amount");
    expect(() => toMinorUnits("")).toThrow("empty_amount");
    expect(() => toMinorUnits("1,000.00")).toThrow("invalid_amount");
  });

  it("adds and subtracts exactly without float error", () => {
    expect(addAmounts("0.10", "0.20")).toBe("0.30");
    expect(subtractAmounts("1.00", "0.90")).toBe("0.10");
    expect(subtractAmounts("0.10", "0.20")).toBe("-0.10");
  });

  it("compares amounts", () => {
    expect(compareAmounts("1.00", "2.00")).toBe(-1);
    expect(compareAmounts("2.00", "2.00")).toBe(0);
    expect(compareAmounts("3.00", "2.00")).toBe(1);
  });

  it("allocates proportionally with remainder to last part", () => {
    const parts = allocateProportionally("100.00", [1, 1, 1]);
    expect(parts).toHaveLength(3);
    expect(parts.reduce((s, p) => s + Number(p), 0)).toBe(100);
  });

  it("formats with thousands separators", () => {
    expect(formatMoney("12345.5")).toBe("12,345.50 ETB");
  });

  it("formats numeric input from Postgres numeric columns", () => {
    expect(formatMoney(12345.5)).toBe("12,345.50 ETB");
    expect(formatMoney(0)).toBe("0.00 ETB");
    expect(formatMoney(1234567.891)).toBe("1,234,567.89 ETB");
  });
});
