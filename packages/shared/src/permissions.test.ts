import { describe, it, expect } from "vitest";
import { can, canSeeAdminTab, isPlatformAdmin } from "./permissions";

describe("permissions", () => {
  it("gates capabilities by role", () => {
    expect(can("owner", "manageProperties")).toBe(true);
    expect(can("manager", "manageProperties")).toBe(true);
    expect(can("staff", "manageProperties")).toBe(false);
    expect(can("viewer", "recordPayment")).toBe(false);
    expect(can("staff", "recordPayment")).toBe(true);
  });

  it("hides the admin tab from staff and viewer", () => {
    expect(canSeeAdminTab("owner")).toBe(true);
    expect(canSeeAdminTab("manager")).toBe(true);
    expect(canSeeAdminTab("staff")).toBe(false);
    expect(canSeeAdminTab("viewer")).toBe(false);
    expect(canSeeAdminTab(null)).toBe(false);
  });

  it("denies unknown or missing roles", () => {
    expect(can(null, "viewDashboard")).toBe(false);
    expect(can(undefined, "viewDashboard")).toBe(false);
    expect(can("superuser", "viewDashboard")).toBe(false);
  });

  it("grants everything to platform_admin", () => {
    expect(can("platform_admin", "manageProperties")).toBe(true);
  });

  it("recognizes platform admin flag", () => {
    expect(isPlatformAdmin({ is_platform_admin: true })).toBe(true);
    expect(isPlatformAdmin({ is_platform_admin: false })).toBe(false);
    expect(isPlatformAdmin(null)).toBe(false);
  });
});
