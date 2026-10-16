import { createClient } from "@/lib/supabase/server";

export default async function AuditPage() {
  const supabase = await createClient();
  // Reads audit_logs directly; RLS limits to orgs the caller owns/manages, and
  // platform admins see all.
  const { data } = await supabase
    .from("audit_logs")
    .select("id, action, table_name, record_id, actor_id, created_at")
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Audit log</h1>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-text-muted">
            <tr className="border-b border-border">
              <th className="p-3">When</th>
              <th className="p-3">Action</th>
              <th className="p-3">Table</th>
              <th className="p-3">Record</th>
              <th className="p-3">Actor</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((row) => (
              <tr key={row.id} className="border-b border-border/60">
                <td className="p-3 whitespace-nowrap">{new Date(row.created_at).toLocaleString()}</td>
                <td className="p-3 font-semibold">{row.action}</td>
                <td className="p-3">{row.table_name}</td>
                <td className="p-3 font-mono text-xs">{row.record_id}</td>
                <td className="p-3 font-mono text-xs">{row.actor_id}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
