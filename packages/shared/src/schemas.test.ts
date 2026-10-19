import { describe, it, expect } from "vitest";
import {
  AssignTenantToUnitSchema,
  CreateTenantWithLeaseSchema,
  Handle,
  SignUpSchema,
} from "./schemas";

const UNIT = "11111111-1111-4111-8111-111111111111";
const TENANT = "22222222-2222-4222-8222-222222222222";

describe("AssignTenantToUnitSchema", () => {
  it("accepts a minimal assignment and defaults the optional terms", () => {
    const parsed = AssignTenantToUnitSchema.safeParse({
      unitId: UNIT,
      tenantId: TENANT,
      startDate: "2026-01-01",
      monthlyRent: "5000",
    });
    expect(parsed.success).toBe(true);
    if (!parsed.success) return;
    expect(parsed.data.endDate === undefined || parsed.data.endDate === null).toBe(true);
    expect(parsed.data.depositAmount).toBe("0");
    expect(parsed.data.billingDay).toBe(1);
    expect(parsed.data.graceDays).toBe(5);
  });

  it("rejects a non-uuid unit and a non-ISO start date", () => {
    expect(
      AssignTenantToUnitSchema.safeParse({
        unitId: "not-a-uuid",
        tenantId: TENANT,
        startDate: "2026-01-01",
        monthlyRent: "1",
      }).success,
    ).toBe(false);

    expect(
      AssignTenantToUnitSchema.safeParse({
        unitId: UNIT,
        tenantId: TENANT,
        startDate: "01/01/2026",
        monthlyRent: "5000",
      }).success,
    ).toBe(false);
  });

  it("rejects negative or malformed money", () => {
    for (const monthlyRent of ["-1", "1.234", "abc", ""]) {
      expect(
        AssignTenantToUnitSchema.safeParse({
          unitId: UNIT,
          tenantId: TENANT,
          startDate: "2026-01-01",
          monthlyRent,
        }).success,
      ).toBe(false);
    }
  });
});

describe("CreateTenantWithLeaseSchema", () => {
  const base = {
    orgId: UNIT,
    unitId: UNIT,
    startDate: "2026-01-01",
    monthlyRent: "5000",
    tenant: { fullName: "Abebe Bikila" },
  };

  it("requires a tenant name", () => {
    expect(CreateTenantWithLeaseSchema.safeParse({ ...base, tenant: {} }).success).toBe(false);
    expect(CreateTenantWithLeaseSchema.safeParse(base).success).toBe(true);
  });

  it("rejects an Ethiopian phone that is not local", () => {
    expect(
      CreateTenantWithLeaseSchema.safeParse({
        ...base,
        tenant: { fullName: "Abebe Bikila", phone: "1234567890" },
      }).success,
    ).toBe(false);
    expect(
      CreateTenantWithLeaseSchema.safeParse({
        ...base,
        tenant: { fullName: "Abebe Bikila", phone: "0912345678" },
      }).success,
    ).toBe(true);
  });
});

describe("Handle", () => {
  it("normalises what people actually type", () => {
    expect(Handle.parse("@Abebe")).toBe("abebe");
    expect(Handle.parse("  Abebe  ")).toBe("abebe");
    expect(Handle.parse("@@abebe")).toBe("abebe");
    expect(Handle.parse("abe_be1")).toBe("abe_be1");
    expect(Handle.parse("a1b2c3")).toBe("a1b2c3");
  });

  it("rejects handles the database would reject", () => {
    for (const bad of ["ab", "1abe", "ab-cd", "ab cd", "abe.be", "a".repeat(25), "@"]) {
      expect(Handle.safeParse(bad).success, bad).toBe(false);
    }
  });
});

describe("SignUpSchema", () => {
  const valid = {
    handle: "@Abebe",
    email: "someone@example.com",
    password: "Password1",
    acceptTerms: true,
  };

  it("accepts a handle sign-up with the terms ticked", () => {
    const parsed = SignUpSchema.safeParse(valid);
    expect(parsed.success).toBe(true);
    if (!parsed.success) return;
    expect(parsed.data.handle).toBe("abebe");
    expect(parsed.data.email).toBe("someone@example.com");
  });

  it("trims the email the way the handle is trimmed", () => {
    const parsed = SignUpSchema.safeParse({ ...valid, email: "  someone@example.com " });
    expect(parsed.success).toBe(true);
    if (!parsed.success) return;
    expect(parsed.data.email).toBe("someone@example.com");
  });

  it("requires the terms to be ticked", () => {
    const parsed = SignUpSchema.safeParse({ ...valid, acceptTerms: false });
    expect(parsed.success).toBe(false);
    if (parsed.success) return;
    expect(parsed.error.issues[0]?.message).toBe("must_accept_terms");
  });

  it("names the field that is wrong", () => {
    const empty = SignUpSchema.safeParse({ ...valid, handle: "" });
    expect(empty.success).toBe(true);

    const missing = SignUpSchema.safeParse({ ...valid, handle: "1bad" });
    expect(missing.success).toBe(false);
    if (missing.success) return;
    expect(missing.error.issues[0]?.message).toBe("invalid_handle");

    const weak = SignUpSchema.safeParse({ ...valid, password: "short" });
    expect(weak.success).toBe(false);
    if (weak.success) return;
    expect(weak.error.issues[0]?.message).toBe("password_too_short");

    const noEmail = SignUpSchema.safeParse({ ...valid, email: "" });
    expect(noEmail.success).toBe(false);
    if (noEmail.success) return;
    expect(noEmail.error.issues[0]?.message).toBe("required");

    const badEmail = SignUpSchema.safeParse({ ...valid, email: "abebe(at)example" });
    expect(badEmail.success).toBe(false);
    if (badEmail.success) return;
    expect(badEmail.error.issues[0]?.message).toBe("invalid_email");
  });

  it("keeps a phone number out of the payload entirely", () => {
    const parsed = SignUpSchema.safeParse({ ...valid, phone: "0912345678" });
    expect(parsed.success).toBe(true);
    if (!parsed.success) return;
    expect("phone" in parsed.data).toBe(false);
  });
});
