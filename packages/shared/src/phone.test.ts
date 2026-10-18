import { describe, it, expect } from "vitest";
import { looksLikeEmail, toE164 } from "./phone";

describe("toE164", () => {
  it("normalises the shapes people actually type", () => {
    expect(toE164("0912345678")).toBe("+251912345678");
    expect(toE164("+251912345678")).toBe("+251912345678");
    expect(toE164("251912345678")).toBe("+251912345678");
    expect(toE164("912345678")).toBe("+251912345678");
    expect(toE164("09 12 34 56 78")).toBe("+251912345678");
    expect(toE164("+251 91 234 5678")).toBe("+251912345678");
    expect(toE164("(0912) 345-678")).toBe("+251912345678");
    expect(toE164("+251712345678")).toBe("+251712345678");
  });

  it("rejects anything that is not an Ethiopian mobile number", () => {
    for (const bad of ["", "  ", "12345", "0812345678", "+14155552671", "091234567", "09123456789", "abc"]) {
      expect(toE164(bad)).toBeNull();
    }
  });
});

describe("looksLikeEmail", () => {
  it("separates email identifiers from phone numbers", () => {
    expect(looksLikeEmail("owner@fam.et")).toBe(true);
    expect(looksLikeEmail("0912345678")).toBe(false);
  });
});
