import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

/**
 * Service-role client for Edge Functions. Never expose the service key to a
 * client. Uses the pooled connection implicitly via PostgREST.
 */
export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("missing_supabase_env");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** Client scoped to the caller's JWT so RLS applies as the user. */
export function userClient(req: Request): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const auth = req.headers.get("Authorization") ?? "";
  if (!url || !anon) throw new Error("missing_supabase_env");
  return createClient(url, anon, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
