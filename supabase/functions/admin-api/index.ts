// admin-api — platform-admin-only actions that cannot run as RPC
// (e.g. inviting/mutating auth users). Verifies JWT, loads profile, requires
// is_platform_admin + AAL2, then acts and writes an audit row.
import { serviceClient } from "../_shared/supabase.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { json, error } from "../_shared/response.ts";
import { log, newRequestId } from "../_shared/log.ts";

interface Body {
  action: "list_users" | "delete_user" | "promote_platform_admin";
  user_id?: string;
  email?: string;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const pf = preflight(req);
  if (pf) return pf;

  const request_id = newRequestId(req);
  if (req.method !== "POST") return error("method_not_allowed", 405, origin);

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const jwt = auth.replace(/^Bearer\s+/i, "");
    if (!jwt) return error("forbidden", 401, origin);

    const admin = serviceClient();
    const { data: claimData, error: claimErr } = await admin.auth.getUser(jwt);
    if (claimErr || !claimData.user) return error("forbidden", 401, origin);

    // require AAL2 (MFA) for the platform console
    const aal = decodeJwtAal(jwt);
    if (aal !== "aal2") {
      // allow without MFA only if the deployment disables it (ADMIN_REQUIRE_MFA=false)
      if ((Deno.env.get("ADMIN_REQUIRE_MFA") ?? "true") !== "false") {
        return error("mfa_required", 403, origin);
      }
    }

    const { data: profile } = await admin
      .from("profiles")
      .select("is_platform_admin")
      .eq("id", claimData.user.id)
      .maybeSingle();
    if (!profile?.is_platform_admin) return error("forbidden", 403, origin);

    const body = (await req.json()) as Body;

    switch (body.action) {
      case "list_users": {
        const { data, error: lErr } = await admin.auth.admin.listUsers({ page: 1, perPage: 100 });
        if (lErr) return error("list_failed", 400, origin);
        return json({
          ok: true,
          users: data.users.map((u) => ({ id: u.id, email: u.email, created_at: u.created_at })),
        });
      }
      case "promote_platform_admin": {
        if (!body.user_id) return error("invalid_input", 400, origin);
        const { error: uErr } = await admin
          .from("profiles")
          .update({ is_platform_admin: true })
          .eq("id", body.user_id);
        if (uErr) return error("update_failed", 400, origin);
        await admin.from("audit_logs").insert({
          actor_id: claimData.user.id,
          action: "platform_admin.promote",
          table_name: "profiles",
          record_id: body.user_id,
        });
        return json({ ok: true });
      }
      case "delete_user": {
        if (!body.user_id) return error("invalid_input", 400, origin);
        const { error: dErr } = await admin.auth.admin.deleteUser(body.user_id);
        if (dErr) return error("delete_failed", 400, origin);
        await admin.from("audit_logs").insert({
          actor_id: claimData.user.id,
          action: "auth_user.delete",
          table_name: "auth.users",
          record_id: body.user_id,
        });
        return json({ ok: true });
      }
      default:
        return error("unknown_action", 400, origin);
    }
  } catch {
    log("error", "admin-api failed", { function: "admin-api", request_id, outcome: "error" });
    return error("internal", 500, origin);
  }
});

function decodeJwtAal(jwt: string): string | null {
  try {
    const payload = jwt.split(".")[1];
    if (!payload) return null;
    const padded = payload.replace(/-/g, "+").replace(/_/g, "/");
    const decoded = JSON.parse(atob(padded));
    return typeof decoded.aal === "string" ? decoded.aal : "aal1";
  } catch {
    return null;
  }
}
