// send-reminders — cron daily.
// Reminds for charges due today, due in 3 days, and overdue by 1/7/14 days.
// Idempotent per charge + day. Notifications are inserted with the service role
// (no user session in a cron context).
import { serviceClient } from "../_shared/supabase.ts";
import { log, newRequestId } from "../_shared/log.ts";

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

    let sent = 0;
    for (const row of (charges ?? []) as unknown as ChargeRow[]) {
      const tenant = row.leases?.tenants;
      const tenantId = row.leases?.tenant_id;
      if (!tenantId) continue;

      // idempotency: skip if a reminder for this charge was already queued today
      const { count } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("tenant_id", tenantId)
        .gte("created_at", `${today}T00:00:00Z`)
        .contains("data", { charge_id: row.id });
      if ((count ?? 0) > 0) continue;

      const { error: insErr } = await supabase.from("notifications").insert({
        org_id: row.org_id,
        user_id: tenant?.user_id ?? null,
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
      sent++;
    }

    log("info", "reminders processed", {
      function: "send-reminders",
      request_id,
      duration_ms: Date.now() - started,
      outcome: "ok",
    });
    return new Response(JSON.stringify({ ok: true, sent }), {
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

function addDays(n: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
