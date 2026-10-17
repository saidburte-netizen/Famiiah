import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

interface MemberRow {
  user_id: string;
  full_name: string | null;
  phone: string | null;
  email: string | null;
  role: string;
  status: string;
  created_at: string;
}

/**
 * Platform-admin view of one organization's members. Reads through
 * `admin_list_members`, which authorises owners/managers *and* platform
 * admins, and runs SECURITY DEFINER so the caller need not be a member.
 */
export default async function OrgMembersPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: org }, { data, error }] = await Promise.all([
    supabase.from("organizations").select("id, name").eq("id", id).maybeSingle(),
    supabase.rpc("admin_list_members", {
      p_org: id,
      p_search: null,
      p_limit: 100,
      p_offset: 0,
    }),
  ]);

  const members = (data ?? []) as MemberRow[];

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Link href="/members" className="text-sm text-royal hover:underline">
          ← Users &amp; roles
        </Link>
      </div>
      <h1 className="font-display text-3xl text-midnight">{org?.name ?? "Organization"}</h1>

      {error && (
        <p className="card p-4 text-danger" role="alert">
          {error.message}
        </p>
      )}

      {!error && members.length === 0 && (
        <p className="text-text-muted text-sm">No members yet.</p>
      )}

      {members.length > 0 && (
        <div className="card overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-text-muted">
              <tr className="border-b border-border">
                <th className="p-3">Member</th>
                <th className="p-3">Email</th>
                <th className="p-3">Phone</th>
                <th className="p-3">Role</th>
                <th className="p-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {members.map((m) => (
                <tr key={m.user_id} className="border-b border-border/60">
                  <td className="p-3 font-semibold">{m.full_name ?? m.user_id.slice(0, 8)}</td>
                  <td className="p-3">{m.email ?? "—"}</td>
                  <td className="p-3">{m.phone ?? "—"}</td>
                  <td className="p-3">{m.role}</td>
                  <td className="p-3">{m.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
