import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const supabase = await createClient();

  const [{ count: orgs }, { count: users }, { count: events }] = await Promise.all([
    supabase.from("organizations").select("*", { count: "exact", head: true }),
    supabase.from("profiles").select("*", { count: "exact", head: true }),
    supabase
      .from("app_event_logs")
      .select("*", { count: "exact", head: true })
      .gte("created_at", new Date(Date.now() - 24 * 3600 * 1000).toISOString()),
  ]);

  const stats = [
    { label: "Organizations", value: orgs ?? 0 },
    { label: "Users", value: users ?? 0 },
    { label: "Events (24h)", value: events ?? 0 },
  ];

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Overview</h1>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {stats.map((s) => (
          <div key={s.label} className="card p-6">
            <p className="text-text-muted text-sm font-semibold">{s.label}</p>
            <p className="text-3xl font-extrabold text-navy mt-2">{s.value}</p>
          </div>
        ))}
      </div>
      <p className="text-text-muted text-sm">
        Metrics are computed under RLS as the signed-in platform admin.
      </p>
    </section>
  );
}
