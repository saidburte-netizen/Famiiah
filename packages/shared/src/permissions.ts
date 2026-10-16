/**
 * Org roles and the permission matrix. Mirrors the DB enums and the role checks
 * used in RLS policies and `admin_*` RPCs. The DB is authoritative; this is the
 * client-side mirror used for UI gating and tests.
 */

export const ORG_ROLES = ["owner", "manager", "staff", "viewer"] as const;
export type OrgRole = (typeof ORG_ROLES)[number];

export const ORG_MEMBER_STATUSES = ["pending", "active", "suspended"] as const;
export type OrgMemberStatus = (typeof ORG_MEMBER_STATUSES)[number];

/** A tenant is not an org role; it is a `tenants` row linked to a user. */
export type ActorRole = OrgRole | "tenant" | "anon" | "platform_admin";

/** Capabilities checked by the UI. Each maps to a role set. */
export const CAPABILITIES = {
  viewDashboard: ["owner", "manager", "staff", "viewer"],
  manageProperties: ["owner", "manager"],
  manageUnits: ["owner", "manager"],
  manageTenants: ["owner", "manager", "staff"],
  manageLeases: ["owner", "manager"],
  recordPayment: ["owner", "manager", "staff"],
  voidPayment: ["owner", "manager"],
  manageStock: ["owner", "manager", "staff"],
  manageRentals: ["owner", "manager", "staff"],
  viewReports: ["owner", "manager"],
  manageMembers: ["owner", "manager"],
  viewAuditLog: ["owner", "manager"],
  viewAdminTab: ["owner", "manager"],
} as const;

export type Capability = keyof typeof CAPABILITIES;

const ROLES = new Set<string>(ORG_ROLES);

export function can(role: string | null | undefined, capability: Capability): boolean {
  if (!role) return false;
  if (role === "platform_admin") return true;
  if (!ROLES.has(role)) return false;
  return (CAPABILITIES[capability] as readonly string[]).includes(role);
}

/** True when the role should see the Admin bottom tab. */
export function canSeeAdminTab(role: string | null | undefined): boolean {
  return can(role, "viewAdminTab");
}

/** Roles allowed on the login role picker. */
export const LOGIN_ROLE_CHIPS = ["owner", "manager", "staff"] as const;

/** Platform admin console is gated by profiles.is_platform_admin + AAL2. */
export function isPlatformAdmin(profile: { is_platform_admin?: boolean } | null | undefined): boolean {
  return !!profile?.is_platform_admin;
}
