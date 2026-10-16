import { createClient } from "@/lib/supabase/server";

export default async function FlagsPage() {
  const supabase = await createClient();
  const { data } = await supabase
    .from("feature_flags")
    .select("key, org_id, enabled, description, updated_at")
    .order("key");

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Feature flags</h1>
      <p className="text-text-muted text-sm">
        Toggle global flags with <code>admin_set_feature_flag</code> (requires AAL2).
      </p>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-text-muted">
            <tr className="border-b border-border">
              <th className="p-3">Key</th>
              <th className="p-3">Scope</th>
              <th className="p-3">Enabled</th>
              <th className="p-3">Description</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((f) => (
              <tr key={`${f.key}:${f.org_id ?? "global"}`} className="border-b border-border/60">
                <td className="p-3 font-semibold">{f.key}</td>
                <td className="p-3">{f.org_id ? "org" : "global"}</td>
                <td className="p-3">{f.enabled ? "on" : "off"}</td>
                <td className="p-3">{f.description}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
