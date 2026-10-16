import { createClient } from "@/lib/supabase/server";

export default async function OrganizationsPage() {
  const supabase = await createClient();
  const { data } = await supabase
    .from("organizations")
    .select("id, name, slug, currency, timezone, created_at")
    .order("created_at", { ascending: false })
    .limit(100);

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Organizations</h1>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-text-muted">
            <tr className="border-b border-border">
              <th className="p-3">Name</th>
              <th className="p-3">Slug</th>
              <th className="p-3">Currency</th>
              <th className="p-3">Timezone</th>
              <th className="p-3">Created</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((o) => (
              <tr key={o.id} className="border-b border-border/60">
                <td className="p-3 font-semibold">{o.name}</td>
                <td className="p-3">{o.slug}</td>
                <td className="p-3">{o.currency}</td>
                <td className="p-3">{o.timezone}</td>
                <td className="p-3 whitespace-nowrap">{new Date(o.created_at).toLocaleDateString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
