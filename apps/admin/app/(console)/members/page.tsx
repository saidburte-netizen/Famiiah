import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

/**
 * Users & roles. This page lists organizations and lets a platform admin drill
 * into members via the admin_list_members RPC (RLS + role check server-side).
 */
export default async function MembersPage() {
  const supabase = await createClient();
  const { data: orgs } = await supabase
    .from("organizations")
    .select("id, name")
    .order("name")
    .limit(100);

  return (
    <section className="flex flex-col gap-6">
      <h1 className="font-display text-3xl text-midnight">Users &amp; roles</h1>
      <p className="text-text-muted text-sm">
        Select an organization to review its members and roles.
      </p>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {(orgs ?? []).map((o) => (
          <Link key={o.id} href={`/members/${o.id}`} className="card p-5 hover:border-royal">
            <p className="font-semibold text-navy">{o.name}</p>
            <p className="text-xs text-text-muted mt-1">{o.id}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}
