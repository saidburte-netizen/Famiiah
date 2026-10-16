import { getSupabase } from "./supabase";
import type { CreatePropertyInput, RecordPaymentInput } from "@fam/shared";

/**
 * Typed wrappers over supabase-js and RPCs. All writes that are multi-step or
 * transactional go through RPCs; simple reads use table selects.
 */

export async function listPropertiesWithStats(orgId: string, opts?: { type?: string; search?: string }) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("list_properties_with_stats", {
    p_org: orgId,
    p_type: (opts?.type ?? null) as never,
    p_search: opts?.search ?? null,
    p_limit: 20,
    p_offset: 0,
  });
  if (error) throw error;
  return data ?? [];
}

export async function dashboardSummary(orgId: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("dashboard_summary", { p_org: orgId });
  if (error) throw error;
  return data;
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

export async function listTenantsWithStatus(orgId: string, filter = "all", search?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("list_tenants_with_status", {
    p_org: orgId,
    p_filter: filter,
    p_search: search ?? null,
    p_limit: 20,
    p_offset: 0,
  });
  if (error) throw error;
  return data ?? [];
}

export async function rentOverview(orgId: string, month: string, status?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("rent_overview", {
    p_org: orgId,
    p_month: month,
    p_status: (status ?? null) as never,
    p_search: null,
    p_limit: 50,
    p_offset: 0,
  });
  if (error) throw error;
  return data as { rows: unknown[]; expected: number; collected: number; outstanding: number };
}

export async function recordPayment(input: RecordPaymentInput) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("record_payment", {
    p_lease: input.leaseId,
    p_amount: Number(input.amount),
    p_method: input.method,
    p_reference: input.reference ?? null,
    p_paid_at: input.paidAt ?? new Date().toISOString(),
    p_notes: input.notes ?? null,
    p_idempotency_key: input.idempotencyKey ?? null,
  });
  if (error) throw error;
  return data;
}

export async function stockAdjust(itemId: string, type: "in" | "out" | "adjustment", qty: string, reason?: string) {
  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("stock_adjust", {
    p_item: itemId,
    p_type: type,
    p_qty: Number(qty),
    p_reason: reason ?? null,
    p_unit: null,
  });
  if (error) throw error;
  return data;
}

export async function markAllNotificationsRead(orgId: string) {
  const supabase = getSupabase();
  const { error } = await supabase.rpc("mark_all_notifications_read", { p_org: orgId });
  if (error) throw error;
}
