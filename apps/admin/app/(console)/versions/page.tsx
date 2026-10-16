import { createClient } from "@/lib/supabase/server";

export default async function VersionsPage() {
  const supabase = await createClient();
  const { data } = await supabase
    .from("app_versions")
    .select("id, platform, version, min_supported_version, force_update, is_active, released_at")
    .order("released_at", { ascending: false })
    .limit(100);

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">App versions</h1>
      <p className="text-text-muted text-sm">
        Publish new rows with the <code>admin_publish_app_version</code> RPC (requires AAL2).
      </p>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-text-muted">
            <tr className="border-b border-border">
              <th className="p-3">Platform</th>
              <th className="p-3">Version</th>
              <th className="p-3">Min supported</th>
              <th className="p-3">Force</th>
              <th className="p-3">Active</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((v) => (
              <tr key={v.id} className="border-b border-border/60">
                <td className="p-3">{v.platform}</td>
                <td className="p-3 font-semibold">{v.version}</td>
                <td className="p-3">{v.min_supported_version}</td>
                <td className="p-3">{v.force_update ? "yes" : "no"}</td>
                <td className="p-3">{v.is_active ? "yes" : "no"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
