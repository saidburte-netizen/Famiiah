import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

interface CollectionRow {
  bucket: string;
  expected: number;
  collected: number;
  outstanding: number;
}
interface OccupancyRow {
  bucket: string;
  total_units: number;
  rented_units: number;
  occupancy_pct: number;
}
interface AgeingRow {
  ageing: string;
  charges: number;
  amount: number;
}

function n(v: unknown): number {
  return Number(v ?? 0);
}

/**
 * Platform-admin report for a single organization: collections (monthly bucket
 * for the last six months), occupancy per property, and overdue ageing.
 */
export default async function OrgReportsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const to = new Date();
  const from = new Date();
  from.setMonth(from.getMonth() - 5);
  from.setDate(1);
  const iso = (d: Date) => d.toISOString().slice(0, 10);

  const [{ data: org }, collectionsRes, occupancyRes, ageingRes] = await Promise.all([
    supabase.from("organizations").select("id, name").eq("id", id).maybeSingle(),
    supabase.rpc("report_collections", {
      p_org: id,
      p_from: iso(from),
      p_to: iso(to),
      p_group_by: "month",
    }),
    supabase.rpc("report_occupancy", { p_org: id, p_from: iso(from), p_to: iso(to) }),
    supabase.rpc("report_overdue_ageing", { p_org: id }),
  ]);

  const error = collectionsRes.error ?? occupancyRes.error ?? ageingRes.error;
  const collections = (collectionsRes.data ?? []) as CollectionRow[];
  const occupancy = (occupancyRes.data ?? []) as OccupancyRow[];
  const ageing = (ageingRes.data ?? []) as AgeingRow[];

  return (
    <section className="flex flex-col gap-6">
      <Link href="/reports" className="text-sm text-royal hover:underline">
        ← Reports
      </Link>
      <h1 className="font-display text-3xl text-midnight">{org?.name ?? "Reports"}</h1>

      {error && (
        <p className="card p-4 text-danger" role="alert">
          {error.message}
        </p>
      )}

      {!error && (
        <>
          <div className="card p-5 flex flex-col gap-2">
            <h2 className="font-semibold text-navy">Collections (last 6 months)</h2>
            {collections.length === 0 ? (
              <p className="text-text-muted text-sm">No data.</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="text-left text-text-muted">
                  <tr className="border-b border-border">
                    <th className="p-2">Month</th>
                    <th className="p-2">Expected</th>
                    <th className="p-2">Collected</th>
                    <th className="p-2">Outstanding</th>
                  </tr>
                </thead>
                <tbody>
                  {collections.map((r) => (
                    <tr key={r.bucket} className="border-b border-border/60">
                      <td className="p-2">{r.bucket}</td>
                      <td className="p-2">{n(r.expected).toFixed(2)}</td>
                      <td className="p-2">{n(r.collected).toFixed(2)}</td>
                      <td className="p-2">{n(r.outstanding).toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          <div className="card p-5 flex flex-col gap-2">
            <h2 className="font-semibold text-navy">Occupancy</h2>
            {occupancy.length === 0 ? (
              <p className="text-text-muted text-sm">No data.</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="text-left text-text-muted">
                  <tr className="border-b border-border">
                    <th className="p-2">Property</th>
                    <th className="p-2">Units</th>
                    <th className="p-2">Rented</th>
                    <th className="p-2">Occupancy</th>
                  </tr>
                </thead>
                <tbody>
                  {occupancy.map((r) => (
                    <tr key={r.bucket} className="border-b border-border/60">
                      <td className="p-2">{r.bucket}</td>
                      <td className="p-2">{r.total_units}</td>
                      <td className="p-2">{r.rented_units}</td>
                      <td className="p-2">{n(r.occupancy_pct).toFixed(1)}%</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          <div className="card p-5 flex flex-col gap-2">
            <h2 className="font-semibold text-navy">Overdue ageing</h2>
            {ageing.length === 0 ? (
              <p className="text-text-muted text-sm">Nothing overdue.</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="text-left text-text-muted">
                  <tr className="border-b border-border">
                    <th className="p-2">Bucket</th>
                    <th className="p-2">Charges</th>
                    <th className="p-2">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {ageing.map((r) => (
                    <tr key={r.ageing} className="border-b border-border/60">
                      <td className="p-2">{r.ageing} days</td>
                      <td className="p-2">{r.charges}</td>
                      <td className="p-2">{n(r.amount).toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </section>
  );
}
