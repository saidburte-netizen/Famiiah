import { createClient } from "@/lib/supabase/server";

export default async function StockPage() {
  const supabase = await createClient();
  const { data } = await supabase
    .from("stock_items")
    .select("id, name, sku, quantity, min_quantity, is_rentable, org_id")
    .order("name")
    .limit(200);

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Stock</h1>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-text-muted">
            <tr className="border-b border-border">
              <th className="p-3">Name</th>
              <th className="p-3">SKU</th>
              <th className="p-3">Qty</th>
              <th className="p-3">Min</th>
              <th className="p-3">Rentable</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((s) => {
              const low = Number(s.quantity) <= Number(s.min_quantity);
              return (
                <tr key={s.id} className="border-b border-border/60">
                  <td className="p-3 font-semibold">{s.name}</td>
                  <td className="p-3">{s.sku}</td>
                  <td className={`p-3 ${low ? "text-danger font-bold" : ""}`}>{s.quantity}</td>
                  <td className="p-3">{s.min_quantity}</td>
                  <td className="p-3">{s.is_rentable ? "yes" : "no"}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
