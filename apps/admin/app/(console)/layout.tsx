import Link from "next/link";
import type { ReactNode } from "react";
import { createClient } from "@/lib/supabase/server";

const NAV = [
  { href: "/dashboard", label: "Overview" },
  { href: "/members", label: "Users & roles" },
  { href: "/properties", label: "Organizations" },
  { href: "/stock", label: "Stock" },
  { href: "/rent", label: "Rent & payments" },
  { href: "/reports", label: "Reports" },
  { href: "/audit", label: "Audit log" },
  { href: "/events", label: "Event logs" },
  { href: "/versions", label: "App versions" },
  { href: "/flags", label: "Feature flags" },
];

export default async function ConsoleLayout({ children }: { children: ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="min-h-screen flex">
      <aside className="w-64 bg-midnight text-white p-6 flex flex-col gap-2">
        <Link href="/dashboard" className="font-display text-2xl mb-4">
          Fam
        </Link>
        <nav className="flex flex-col gap-1">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-lg px-3 py-2 text-sm hover:bg-white/10"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="mt-auto text-xs text-ice/80">
          <p className="truncate">{user?.email}</p>
          <SignOutButton />
        </div>
      </aside>
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}

function SignOutButton() {
  return (
    <form action="/auth/signout" method="post" className="mt-2">
      <button type="submit" className="text-ice underline text-xs">
        Sign out
      </button>
    </form>
  );
}
