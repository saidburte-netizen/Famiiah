// payment-webhook — HTTP endpoint for Chapa/Telebirr callbacks.
// Verifies the signature, matches the reference, and calls record_payment as
// service role using the provider reference as the idempotency key.
// Behind the `online_payments` feature flag. Responds 200 fast.
import { serviceClient } from "../_shared/supabase.ts";
import { log, newRequestId } from "../_shared/log.ts";

interface WebhookBody {
  tx_ref?: string; // our reference
  reference?: string;
  status?: string;
  amount?: number;
  currency?: string;
  id?: string; // provider transaction id
}

async function hmacHex(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  const request_id = newRequestId(req);
  if (req.method !== "POST") return new Response("ok", { status: 200 });

  try {
    const secret = Deno.env.get("CHAPA_WEBHOOK_SECRET");
    const raw = await req.text();
    if (!secret) {
      log("error", "webhook secret missing", { function: "payment-webhook", request_id, outcome: "misconfigured" });
      // Do not reveal config state to the caller; ack to avoid retries storms.
      return new Response("ok", { status: 200 });
    }

    const signature =
      req.headers.get("x-chapa-signature") ??
      req.headers.get("x-webhook-signature") ??
      "";
    const expected = await hmacHex(secret, raw);
    if (!timingSafeEqual(signature, expected)) {
      log("warn", "webhook signature mismatch", {
        function: "payment-webhook",
        request_id,
        outcome: "bad_signature",
      });
      return new Response("invalid signature", { status: 401 });
    }

    const body = JSON.parse(raw) as WebhookBody;
    const status = (body.status ?? "").toLowerCase();
    if (status !== "success" && status !== "successful" && status !== "paid") {
      return new Response("ok", { status: 200 });
    }

    const ref = body.tx_ref ?? body.reference ?? "";
    const amount = Number(body.amount ?? 0);
    if (!ref || !(amount > 0)) {
      log("warn", "webhook missing ref/amount", {
        function: "payment-webhook",
        request_id,
        outcome: "invalid_payload",
      });
      return new Response("ok", { status: 200 });
    }

    const admin = serviceClient();

    // feature flag gate
    const { data: flag } = await admin
      .from("feature_flags")
      .select("enabled")
      .eq("key", "online_payments")
      .is("org_id", null)
      .maybeSingle();
    if (!flag?.enabled) {
      log("info", "online_payments disabled; ignoring", {
        function: "payment-webhook",
        request_id,
        outcome: "flag_off",
      });
      return new Response("ok", { status: 200 });
    }

    // resolve the lease from the pending payment reference. The reference is the
    // provider transaction ref; we recorded it on a pending row at init time.
    const { data: pending } = await admin
      .from("payments")
      .select("id, org_id, lease_id, tenant_id")
      .eq("reference", ref)
      .maybeSingle();

    if (!pending?.lease_id) {
      log("warn", "no pending payment for reference", {
        function: "payment-webhook",
        request_id,
        outcome: "no_match",
      });
      return new Response("ok", { status: 200 });
    }

    // Never trust the client-supplied amount; validate it is positive and use the
    // provider value. record_payment is idempotent on the provider reference.
    const { error: rpcErr } = await admin.rpc("record_payment", {
      p_lease: pending.lease_id,
      p_amount: amount,
      p_method: "chapa",
      p_reference: ref,
      p_paid_at: new Date().toISOString(),
      p_notes: `provider tx ${body.id ?? ref}`,
      p_idempotency_key: `chapa:${ref}`,
    });
    if (rpcErr) {
      log("error", "record_payment failed from webhook", {
        function: "payment-webhook",
        request_id,
        org_id: pending.org_id,
        outcome: "rpc_error",
      });
      // ack anyway; the provider will not help, but we avoid infinite retries
      return new Response("ok", { status: 200 });
    }

    log("info", "webhook payment recorded", {
      function: "payment-webhook",
      request_id,
      org_id: pending.org_id,
      outcome: "ok",
    });
    return new Response("ok", { status: 200 });
  } catch {
    log("error", "payment-webhook failed", { function: "payment-webhook", request_id, outcome: "error" });
    return new Response("ok", { status: 200 });
  }
});

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
