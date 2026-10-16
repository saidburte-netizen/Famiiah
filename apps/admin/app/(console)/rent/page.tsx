import { createClient } from "@/lib/supabase/server";

export default async function RentPage() {
  const supabase = await createClient();
  const { data } = await supabase
    .from("payments")
    .select("id, org_id, receipt_no, amount, method, paid_at, voided_at")
    .order("paid_at", { ascending: false })
    .limit(200);

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Rent &amp; payments</h1>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-text-muted">
            <tr className="border-b border-border">
              <th className="p-3">Receipt</th>
              <th className="p-3">Amount</th>
              <th className="p-3">Method</th>
              <th className="p-3">Paid</th>
              <th className="p-3">Status</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((p) => (
              <tr key={p.id} className="border-b border-border/60">
                <td className="p-3 font-mono text-xs">{p.receipt_no}</td>
                <td className="p-3">{p.amount}</td>
                <td className="p-3">{p.method}</td>
                <td className="p-3 whitespace-nowrap">{new Date(p.paid_at).toLocaleString()}</td>
                <td className={`p-3 ${p.voided_at ? "text-danger" : "text-navy"}`}>
                  {p.voided_at ? "voided" : "valid"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
