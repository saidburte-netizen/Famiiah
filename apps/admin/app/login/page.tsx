"use client";

import { Suspense, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(
    params.get("error") === "not_admin" ? "This account is not a platform admin." : null,
  );
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (signInError) {
      setError(signInError.message);
      return;
    }
    router.replace("/dashboard");
    router.refresh();
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-8">
      <form onSubmit={onSubmit} className="card w-full max-w-md p-8 flex flex-col gap-4">
        <div>
          <h1 className="font-display text-3xl text-midnight">Fam Admin</h1>
          <p className="text-text-muted text-sm">Platform administration console</p>
        </div>

        {error && (
          <p className="rounded-lg bg-danger-bg text-danger px-3 py-2 text-sm" role="alert">
            {error}
          </p>
        )}

        <label className="flex flex-col gap-1 text-sm">
          <span className="text-text-muted font-semibold">Email</span>
          <input
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="h-11 rounded-lg border border-border px-3 outline-none focus:border-royal"
          />
        </label>

        <label className="flex flex-col gap-1 text-sm">
          <span className="text-text-muted font-semibold">Password</span>
          <input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="h-11 rounded-lg border border-border px-3 outline-none focus:border-royal"
          />
        </label>

        <button type="submit" disabled={busy} className="btn-primary disabled:opacity-60">
          {busy ? "Signing in…" : "Sign in"}
        </button>

        <p className="text-xs text-text-muted">
          Platform-admin actions require MFA (AAL2). Enroll a TOTP factor after your first sign-in.
        </p>
      </form>
    </main>
  );
}
