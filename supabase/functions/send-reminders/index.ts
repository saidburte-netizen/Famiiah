// send-reminders — cron daily.
// Two phases:
//   1. Queue reminders for charges due today, due in 3 days, overdue 1/7/14 days
//      (idempotent per charge + day).
//   2. Dispatch any *queued* push notifications to the recipients' devices via
//      the Expo push API, then mark them sent/failed.
// Runs with the service role (no user session in a cron context).
import { serviceClient } from "../_shared/supabase.ts";
import { log, newRequestId } from "../_shared/log.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

interface ChargeRow {
  id: string;
  org_id: string;
  lease_id: string;
  amount: number;
  due_date: string;
  leases: {
    tenant_id: string;
    tenants: { id: string; user_id: string | null; full_name: string; phone: string | null };
  };
}

interface QueuedNotification {
  id: string;
  user_id: string;
  title: string;
  body: string | null;
  data: Record<string, unknown> | null;
}

interface PushMessage {
  to: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  sound?: "default";
}

Deno.serve(async (req) => {
  const request_id = newRequestId(req);
  const started = Date.now();
  const supabase = serviceClient();

  try {
    const today = new Date().toISOString().slice(0, 10);
    // days relative to today: overdue 1/7/14, due today, due in 3 days
    const offsets = [-14, -7, -1, 0, 3];
    const dueFilter = offsets.map((d) => `due_date.eq.${addDays(d)}`).join(",");

    const { data: charges, error: qErr } = await supabase
      .from("rent_charges")
      .select(
        "id, org_id, lease_id, amount, due_date, leases!inner(tenant_id, tenants!inner(id, user_id, full_name, phone))",
      )
      .in("status", ["pending", "partial", "overdue"])
      .or(dueFilter);
    if (qErr) throw qErr;

    let queued = 0;
    for (const row of (charges ?? []) as unknown as ChargeRow[]) {
      const tenantId = row.leases?.tenant_id;
      if (!tenantId) continue;

      // Idempotent per charge + day.
      const { count } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .contains("data", { charge_id: row.id })
        .gte("created_at", `${today}T00:00:00Z`);
      if (count && count > 0) continue;

      const { error: insErr } = await supabase.from("notifications").insert({
        org_id: row.org_id,
        user_id: row.leases.tenants?.user_id ?? null,
        tenant_id: tenantId,
        channel: "push",
        title: "Rent reminder",
        body: `Rent of ${row.amount} is due on ${row.due_date}.`,
        data: { charge_id: row.id },
        status: "queued",
      });
      if (insErr) {
        log("error", "notification insert failed", {
          function: "send-reminders",
          request_id,
          outcome: "insert_failed",
        });
        continue;
      }
      queued++;
    }

    const { sent, failed } = await dispatchQueued(supabase);

    log("info", "reminders processed", {
      function: "send-reminders",
      request_id,
      duration_ms: Date.now() - started,
      outcome: "ok",
    });
    return new Response(JSON.stringify({ ok: true, queued, sent, failed }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    log("error", "send-reminders failed", {
      function: "send-reminders",
      request_id,
      duration_ms: Date.now() - started,
      outcome: "error",
    });
    return new Response(JSON.stringify({ error: "internal" }), { status: 500 });
  }
});

/**
 * Send every queued push notification to the recipient's registered devices and
 * mark each one sent (at least one ticket accepted) or failed (no device, or
 * the provider rejected every ticket).
 */
async function dispatchQueued(
  supabase: SupabaseClient,
): Promise<{ sent: number; failed: number }> {
  const { data, error } = await supabase
    .from("notifications")
    .select("id, user_id, title, body, data")
    .eq("status", "queued")
    .eq("channel", "push")
    .not("user_id", "is", null)
    .lte("scheduled_at", new Date().toISOString())
    .order("scheduled_at", { ascending: true })
    .limit(100);
  if (error) throw error;

  const pending = (data ?? []) as QueuedNotification[];
  if (pending.length === 0) return { sent: 0, failed: 0 };

  const userIds = [...new Set(pending.map((n) => n.user_id))];
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("user_id, token")
    .in("user_id", userIds);

  const byUser = new Map<string, string[]>();
  for (const t of (tokens ?? []) as Array<{ user_id: string; token: string }>) {
    const list = byUser.get(t.user_id) ?? [];
    list.push(t.token);
    byUser.set(t.user_id, list);
  }

  const messages: Array<{ notificationId: string; message: PushMessage }> = [];
  const noDevice: string[] = [];
  for (const n of pending) {
    const devices = byUser.get(n.user_id) ?? [];
    if (devices.length === 0) {
      noDevice.push(n.id);
      continue;
    }
    for (const to of devices) {
      messages.push({
        notificationId: n.id,
        message: {
          to,
          title: n.title,
          body: n.body ?? "",
          data: n.data ?? undefined,
          sound: "default",
        },
      });
    }
  }

  // A notification with no device can never be delivered; fail it rather than
  // retrying forever.
  if (noDevice.length > 0) {
    await supabase.from("notifications").update({ status: "failed" }).in("id", noDevice);
  }

  const delivered = new Set<string>();
  const rejected = new Set<string>();
  const endpoint = "https://exp.host/--/api/v2/push/send";
  const accessToken = Deno.env.get("EXPO_ACCESS_TOKEN");

  for (let i = 0; i < messages.length; i += 100) {
    const chunk = messages.slice(i, i + 100);
    let tickets: Array<{ status?: string }> = [];
    let ok = false;
    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        },
        body: JSON.stringify(chunk.map((c) => c.message)),
      });
      ok = res.ok;
      const payload = (await res.json().catch(() => null)) as
        | { data?: Array<{ status?: string }> }
        | null;
      tickets = payload?.data ?? [];
    } catch {
      ok = false;
    }

    chunk.forEach((c, idx) => {
      if (ok && tickets[idx]?.status === "ok") delivered.add(c.notificationId);
      else rejected.add(c.notificationId);
    });
  }

  // If a notification reached at least one device, count it as sent.
  const sentIds = [...delivered].filter((id) => !rejected.has(id));
  const failedIds = [...rejected].filter((id) => !delivered.has(id));

  if (sentIds.length > 0) {
    await supabase
      .from("notifications")
      .update({ status: "sent", sent_at: new Date().toISOString() })
      .in("id", sentIds);
  }
  if (failedIds.length > 0) {
    await supabase.from("notifications").update({ status: "failed" }).in("id", failedIds);
  }

  return { sent: sentIds.length, failed: failedIds.length + noDevice.length };
}

function addDays(n: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
