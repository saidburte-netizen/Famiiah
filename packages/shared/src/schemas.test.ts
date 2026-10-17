import { describe, it, expect } from "vitest";
import {
  AssignTenantToUnitSchema,
  CreateTenantWithLeaseSchema,
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
