import { getSupabase } from "@/lib/supabase";
import type {
  CreatePropertyInput,
  CreateTenantWithLeaseInput,
  RecordPaymentInput,
} from "@fam/shared";

/**
 * Typed wrappers over the Supabase client.
 *
 * Reads use the auto-generated REST layer (RLS enforces access); every
 * mutation goes through a SECURITY DEFINER RPC so business rules and the
 * audit trail stay server-side. Parameter names must match the SQL RPC
 * definitions exactly (see supabase/migrations/0009..0014).
 */

// ---------------------------------------------------------------- Dashboard

export interface DashboardSummary {
  collected_month: string;
  expected_month: string;
  collection_rate: number;
  properties_count: number;
  units_total: number;
  units_rented: number;
  units_vacant: number;
  active_tenants: number;
  overdue_count: number;
  overdue_amount: string | number;
  unread_notifications: number;
  due_this_week?: Array<{
    id: string;
    amount: string | number;
    due_date: string;
    tenant_name: string;
    unit_code: string;
  }>;
}

export async function dashboardSummary(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("dashboard_summary", { p_org: orgId });
  if (error) throw error;
  return data as unknown as DashboardSummary;
}

// --------------------------------------------------------------- Properties

export interface PropertyStatsRow {
  id: string;
  name: string;
  type: string;
  city: string | null;
  units_total: number;
  units_rented: number;
  occupancy_pct: number;
  monthly_total: string;
}

export async function listPropertiesWithStats(orgId: string, opts?: { type?: string; search?: string }) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("list_properties_with_stats", {
    p_org: orgId,
    p_type: (opts?.type ?? null) as never,
    p_search: opts?.search ?? null,
    p_limit: 50,
    p_offset: 0,
  });
  if (error) throw error;
  return (data ?? []) as unknown as PropertyRow[];
}

export interface PropertyRow {
  id: string;
  name: string;
  type: string;
  city: string | null;
  cover_image_path: string | null;
  units_total: number;
  units_rented: number;
  occupancy_pct: number;
  monthly_total: string;
  created_at: string;
}

export async function createProperty(orgId: string, input: CreatePropertyInput) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("properties")
    .insert({
      org_id: orgId,
      name: input.name,
      type: input.type,
      address_line: input.addressLine ?? null,
      sub_city: input.subCity ?? null,
      city: input.city ?? null,
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      floors: input.floors ?? null,
      notes: input.notes ?? null,
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function getProperty(id: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.from("properties").select("*").eq("id", id).single();
  if (error) throw error;
  return data;
}

export async function listUnits(propertyId: string, status?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("list_units", {
    p_property: propertyId,
    p_status: (status ?? null) as never,
    p_search: null,
    p_limit: 100,
    p_offset: 0,
  });
  if (error) throw error;
  return (data ?? []) as unknown as UnitRow[];
}

export interface UnitRow {
  id: string;
  code: string;
  kind: string | null;
  floor_label: string | null;
  monthly_rent: string | null;
  status: string;
  tenant_name: string | null;
  overdue: boolean | null;
}

export async function createUnit(
  orgId: string,
  input: {
    propertyId: string;
    code: string;
    kind: string;
    floorLabel?: string;
    areaSqM?: number | null;
    monthlyRent: string;
    hasSeparateMeter?: boolean;
    hasStorage?: boolean;
  },
) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("units")
    .insert({
      org_id: orgId,
      property_id: input.propertyId,
      code: input.code,
      kind: input.kind,
      floor_label: input.floorLabel ?? null,
      area_sqm: input.areaSqM ?? null,
      monthly_rent: input.monthlyRent,
      has_separate_meter: input.hasSeparateMeter ?? false,
      has_storage: input.hasStorage ?? false,
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ------------------------------------------------------------------ Tenants

export interface VacantUnit {
  id: string;
  code: string;
  property_id: string;
  property_name: string | null;
  monthly_rent: string;
}

export async function listVacantUnits(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("units")
    .select("id, code, monthly_rent, property_id, properties(name)")
    .eq("org_id", orgId)
    .eq("status", "vacant")
    .is("deleted_at", null)
    .order("code")
    .limit(200);
  if (error) throw error;
  return ((data ?? []) as unknown as Array<Record<string, unknown>>).map((r) => {
    const props = r.properties as { name?: string } | null | undefined;
    return {
      id: String(r.id),
      code: String(r.code),
      property_id: String(r.property_id),
      property_name: props?.name ?? null,
      monthly_rent: String(r.monthly_rent ?? "0"),
    } satisfies VacantUnit;
  });
}

export interface TenantRow {
  id: string;
  full_name: string;
  phone: string | null;
  unit_code: string | null;
  monthly_rent: string | null;
  lease_end: string | null;
  overdue_days: number;
  status: string;
}

export async function listTenantsWithStatus(orgId: string, filter = "all", search?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("list_tenants_with_status", {
    p_org: orgId,
    p_filter: filter,
    p_search: search ?? null,
    p_limit: 50,
    p_offset: 0,
  });
  if (error) throw error;
  return (data ?? []) as unknown as TenantRow[];
}

export async function createTenantWithLease(input: CreateTenantWithLeaseInput) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("create_tenant_with_lease", {
    p_org: input.orgId,
    p_unit: input.unitId,
    p_start: input.startDate,
    p_end: input.endDate ?? null,
    p_rent: input.monthlyRent,
    p_deposit: input.depositAmount,
    p_billing_day: input.billingDay,
    p_grace_days: input.graceDays,
    p_tenant: input.tenant as never,
  });
  if (error) throw error;
  return data;
}

export async function getTenant(id: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.from("tenants").select("*").eq("id", id).single();
  if (error) throw error;
  return data;
}

export async function assignTenantToUnit(input: {
  unitId: string;
  tenantId: string;
  startDate: string;
  endDate?: string | null;
  monthlyRent: string;
  depositAmount?: string;
  billingDay?: number;
  graceDays?: number;
}) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("assign_tenant_to_unit", {
    p_unit: input.unitId,
    p_tenant: input.tenantId,
    p_start: input.startDate,
    p_end: input.endDate ?? null,
    p_rent: input.monthlyRent,
    p_deposit: input.depositAmount ?? "0",
    p_billing_day: input.billingDay ?? 1,
    p_grace_days: input.graceDays ?? 5,
  });
  if (error) throw error;
  return data;
}

// -------------------------------------------------------------------- Leases

export async function terminateLease(leaseId: string, endDate: string, reason?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("terminate_lease", {
    p_lease: leaseId,
    p_end_date: endDate,
    p_reason: reason ?? null,
  });
  if (error) throw error;
  return data;
}

export async function renewLease(leaseId: string, newEnd: string, newRent?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("renew_lease", {
    p_lease: leaseId,
    p_new_end: newEnd,
    p_new_rent: newRent ?? null,
  });
  if (error) throw error;
  return data;
}

export interface LeaseRow {
  id: string;
  unit_id: string;
  tenant_id: string;
  start_date: string;
  end_date: string | null;
  monthly_rent: string;
  deposit_amount: string | null;
  status: string;
  ended_reason: string | null;
}

export async function listLeases(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("leases")
    .select("id, unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount, status, ended_reason")
    .eq("org_id", orgId)
    .order("start_date", { ascending: false })
    .limit(100);
  if (error) throw error;
  return (data ?? []) as unknown as LeaseRow[];
}

export async function listTenantLeases(tenantId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("leases")
    .select("id, unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount, status, ended_reason, units(code)")
    .eq("tenant_id", tenantId)
    .order("start_date", { ascending: false });
  if (error) throw error;
  return ((data ?? []) as unknown as Array<LeaseRow & { units: { code?: string } | null }>).map((l) => ({
    ...l,
    unit_code: l.units?.code ?? null,
  }));
}

export interface ChargeRow {
  id: string;
  period_start: string;
  due_date: string;
  amount: string;
  amount_paid: string;
  status: string;
}

export async function listLeaseCharges(leaseId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("rent_charges")
    .select("id, period_start, due_date, amount, amount_paid, status")
    .eq("lease_id", leaseId)
    .order("due_date", { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as unknown as ChargeRow[];
}

// ---------------------------------------------------------------------- Rent

export interface RentChargeRow {
  id: string;
  amount: string;
  amount_paid: string;
  status: string;
  due_date: string;
  tenant_name: string;
  unit_code: string;
  lease_id: string;
}

export async function rentOverview(orgId: string, month: string, status?: string, search?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("rent_overview", {
    p_org: orgId,
    p_month: month,
    p_status: (status ?? null) as never,
    p_search: search ?? null,
    p_limit: 100,
    p_offset: 0,
  });
  if (error) throw error;
  return data as unknown as {
    rows: RentChargeRow[];
    expected: number;
    collected: number;
    outstanding: number;
  };
}

// ------------------------------------------------------------------ Payments

export async function recordPayment(input: RecordPaymentInput) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("record_payment", {
    p_lease: input.leaseId,
    p_amount: input.amount,
    p_method: input.method,
    p_reference: input.reference ?? null,
    p_paid_at: input.paidAt ?? new Date().toISOString(),
    p_notes: input.notes ?? null,
    p_idempotency_key: input.idempotencyKey ?? null,
  });
  if (error) throw error;
  return data as unknown as {
    id?: string;
    receipt_no?: string;
    amount?: string;
    unallocated_amount?: string;
  };
}

export async function voidPayment(paymentId: string, reason: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("void_payment", {
    p_payment: paymentId,
    p_reason: reason,
  });
  if (error) throw error;
  return data;
}

export async function listPayments(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("payments")
    .select("id, receipt_no, amount, unallocated_amount, method, paid_at, voided_at, reference")
    .eq("org_id", orgId)
    .order("paid_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as unknown as Array<{
    id: string;
    receipt_no: string | null;
    amount: string;
    unallocated_amount: string | null;
    method: string;
    paid_at: string;
    voided_at: string | null;
    reference: string | null;
  }>;
}

// --------------------------------------------------------------------- Stock

export interface StockItemRow {
  id: string;
  name: string;
  sku: string | null;
  category: string | null;
  uom: string;
  quantity: string;
  min_quantity: string;
  is_rentable: boolean;
  rental_rate: string | null;
  deleted_at: string | null;
}

export async function listStockItems(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("stock_items")
    .select("id, name, sku, category, uom, quantity, min_quantity, is_rentable, rental_rate, deleted_at")
    .eq("org_id", orgId)
    .is("deleted_at", null)
    .order("name")
    .limit(100);
  if (error) throw error;
  return (data ?? []) as unknown as StockItemRow[];
}

export async function listLowStock(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("list_low_stock", { p_org: orgId });
  if (error) throw error;
  return (data ?? []) as unknown as StockItemRow[];
}

export async function stockAdjust(itemId: string, type: string, qty: string, reason?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("stock_adjust", {
    p_item: itemId,
    p_type: type as never,
    p_qty: qty,
    p_reason: reason ?? null,
    p_unit: null,
  });
  if (error) throw error;
  return data;
}

export async function rentStockItem(input: {
  itemId: string;
  tenantId: string;
  qty: string;
  rate?: string;
  due?: string;
}) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("rent_stock_item", {
    p_item: input.itemId,
    p_tenant: input.tenantId,
    p_qty: input.qty,
    p_rate: input.rate ?? null,
    p_due: input.due ?? null,
  });
  if (error) throw error;
  return data;
}

export async function returnStockItem(rentalId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("return_stock_item", { p_rental: rentalId });
  if (error) throw error;
  return data;
}

// ------------------------------------------------------------- Notifications

export interface NotificationRow {
  id: string;
  title: string;
  body: string | null;
  channel: string;
  status: string;
  created_at: string;
  read_at: string | null;
}

export async function listNotifications(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("notifications")
    .select("id, title, body, channel, status, created_at, read_at")
    .eq("org_id", orgId)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as unknown as NotificationRow[];
}

export async function markNotificationRead(id: string) {
  const supabase = getSupabase();
  const { error } = await supabase.rpc("mark_notification_read", { p_id: id });
  if (error) throw error;
}

export async function markAllNotificationsRead(orgId: string) {
  const supabase = getSupabase();
  const { error } = await supabase.rpc("mark_all_notifications_read", { p_org: orgId });
  if (error) throw error;
}

export async function sendReminder(chargeId: string, channel = "in_app") {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("send_reminder", {
    p_charge: chargeId,
    p_channel: channel as never,
  });
  if (error) throw error;
  return data;
}

// -------------------------------------------------------------------- Reports

export async function reportCollections(orgId: string, from: string, to: string, groupBy = "month") {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("report_collections", {
    p_org: orgId,
    p_from: from,
    p_to: to,
    p_group_by: groupBy,
  });
  if (error) throw error;
  return (data ?? []) as Array<{ bucket: string; expected: number; collected: number; outstanding: number }>;
}

export async function reportOccupancy(orgId: string, from: string, to: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("report_occupancy", {
    p_org: orgId,
    p_from: from,
    p_to: to,
  });
  if (error) throw error;
  return (data ?? []) as Array<{
    bucket: string;
    total_units: number;
    rented_units: number;
    occupancy_pct: number;
  }>;
}

export async function reportOverdueAgeing(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("report_overdue_ageing", { p_org: orgId });
  if (error) throw error;
  return (data ?? []) as Array<{ ageing: string; charges: number; amount: string }>;
}

// --------------------------------------------------------------- Membership

export async function listMembers(orgId: string, search?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("admin_list_members", {
    p_org: orgId,
    p_search: search ?? null,
    p_limit: 100,
    p_offset: 0,
  });
  if (error) throw error;
  return (data ?? []) as unknown as Array<{
    user_id: string;
    full_name: string | null;
    phone: string | null;
    email: string | null;
    role: string;
    status: string;
    created_at: string;
  }>;
}

// ----------------------------------------------------------------- Invitations

/** Accept an invitation. `tokenHash` is the SHA-256 hex of the raw deep-link token. */
export async function acceptInvitation(tokenHash: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("accept_invitation", {
    p_token_hash: tokenHash,
  });
  if (error) throw error;
  return data;
}

