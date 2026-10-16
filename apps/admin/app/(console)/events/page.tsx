import { createClient } from "@/lib/supabase/server";

/**
 * Event logs — platform-admin only (RLS + AAL2 on the RPC). Reads through RPC so
 * AAL2 is enforced server-side rather than relying on the UI.
 */
export default async function EventsPage() {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_event_logs", {
    p_level: null,
    p_from: null,
    p_to: null,
    p_limit: 100,
    p_offset: 0,
  });

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Event logs</h1>
      {error && (
        <p className="card p-4 text-danger bg-danger-bg" role="alert">
          {error.message === "mfa_required"
            ? "MFA (AAL2) is required. Enroll a TOTP factor to view event logs."
            : error.message}
        </p>
      )}
      {data && (
        <div className="card overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-text-muted">
              <tr className="border-b border-border">
                <th className="p-3">When</th>
                <th className="p-3">Level</th>
                <th className="p-3">Source</th>
                <th className="p-3">Message</th>
              </tr>
            </thead>
            <tbody>
              {data.map((row) => (
                <tr key={row.id} className="border-b border-border/60">
                  <td className="p-3 whitespace-nowrap">{new Date(row.created_at).toLocaleString()}</td>
                  <td className="p-3">{row.level}</td>
                  <td className="p-3">{row.source}</td>
                  <td className="p-3">{row.message}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
