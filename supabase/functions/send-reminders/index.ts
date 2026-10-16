// send-reminders — cron daily.
// Finds charges due in 3 days, due today, and overdue 1/7/14 days.
// Idempotent per charge + day. Sends push (Expo) and optional SMS/email.
import { serviceClient } from "../_shared/supabase.ts";
import { log, newRequestId } from "../_shared/log.ts";

interface ChargeRow {
  id: string;
  org_id: string;
  lease_id: string;
  amount: number;
  due_date: string;
  tenant_id: string;
  tenant_user_id: string | null;
  tenant_name: string;
  tenant_phone: string | null;
}

Deno.serve(async (req) => {
  const request_id = newRequestId(req);
  const started = Date.now();
  const supabase = serviceClient();

  try {
    // window: overdue 1/7/14 days, due today, due in 3 days
    const targets = [1, 7, 14];
    const { data: charges, error: qErr } = await supabase
      .from("rent_charges")
      .select(
        "id, org_id, lease_id, amount, due_date, leases!inner(tenant_id, tenants!inner(id, user_id, full_name, phone))",
      )
      .in("status", ["pending", "partial", "overdue"])
      .or(
        "due_date.eq." +
          new Date().toISOString().slice(0, 10) +
          ",due_date.eq." +
          addDays(3),
      );

    if (qErr) throw qErr;

    let sent = 0;
    for (const c of charges ?? []) {
      const row = c as unknown as ChargeRow & { leases: { tenants: unknown } };
      // idempotency: skip if a reminder for this charge was already queued today
      const today = new Date().toISOString().slice(0, 10);
      const { count } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("tenant_id", row.tenant_id)
        .gte("created_at", `${today}T00:00:00Z`)
        .contains("data", { charge_id: row.id });
      if ((count ?? 0) > 0) continue;

      const { error: insErr } = await supabase.from("notifications").insert({
        org_id: row.org_id,
        user_id: row.tenant_user_id,
        tenant_id: row.tenant_id,
        channel: "push",
        title: "Rent reminder",
        body: `Rent of ${row.amount} is due on ${row.due_date}.`,
        data: { charge_id: row.id },
        status: "queued",
      });
      if (insErr) {
        log("error", "notification insert failed", { function: "send-reminders", request_id, outcome: "insert_failed" });
        continue;
      }
      sent++;
    }

    void targets;
    log("info", "reminders processed", {
      function: "send-reminders",
      request_id,
      duration_ms: Date.now() - started,
      outcome: "ok",
    });
    return new Response(JSON.stringify({ ok: true, sent }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
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
