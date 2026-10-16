// invite-member — called by the app.
// Verifies the caller's role, creates an invitation row (hashed token), and
// emails the deep link. Uses the service key server-side only.
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { json, error } from "../_shared/response.ts";
import { log, newRequestId } from "../_shared/log.ts";

interface Body {
  org_id: string;
  email?: string;
  phone?: string;
  role: "owner" | "manager" | "staff" | "viewer";
}

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const pf = preflight(req);
  if (pf) return pf;

  const request_id = newRequestId(req);
  if (req.method !== "POST") return error("method_not_allowed", 405, origin);

  try {
    const body = (await req.json()) as Body;
    if (!body.org_id || (!body.email && !body.phone)) {
      return error("invalid_input", 400, origin);
    }

    // verify caller's role via the user-scoped client (RLS applies)
    const asUser = userClient(req);
    const { data: canInvite } = await asUser.rpc("has_org_role", {
      p_org: body.org_id,
      p_roles: ["owner", "manager"],
    });
    if (!canInvite) return error("forbidden", 403, origin);

    const rawToken = crypto.randomUUID() + crypto.randomUUID();
    const tokenHash = await sha256Hex(rawToken);

    const admin = serviceClient();
    const { data: inv, error: insErr } = await admin.rpc("invite_member", {
      p_org: body.org_id,
      p_email: body.email ?? null,
      p_phone: body.phone ?? null,
      p_role: body.role ?? "staff",
      p_token_hash: tokenHash,
    });
    if (insErr) {
      log("warn", "invite insert failed", { function: "invite-member", request_id, outcome: "insert_failed" });
      return error("insert_failed", 400, origin);
    }

    // send the email (provider integration behind EMAIL_PROVIDER_KEY)
    const link = `fam://invite?token=${rawToken}`;
    if (Deno.env.get("EMAIL_PROVIDER_KEY") && body.email) {
      await sendEmail(body.email, link);
    }

    log("info", "invitation created", {
      function: "invite-member",
      request_id,
      org_id: body.org_id,
      outcome: "ok",
    });

    return json({ ok: true, invitation_id: (inv as { id?: string })?.id, link });
  } catch {
    log("error", "invite-member failed", { function: "invite-member", request_id, outcome: "error" });
    return error("internal", 500, origin);
  }
});

async function sendEmail(to: string, link: string): Promise<void> {
  const key = Deno.env.get("EMAIL_PROVIDER_KEY");
  if (!key) return;
  // provider-agnostic placeholder; wire the real provider here and never log the key.
  await fetch("https://api.example-email-provider.test/send", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      to,
      subject: "You're invited to Fam",
      text: `Join your organization on Fam: ${link}`,
    }),
  });
}
