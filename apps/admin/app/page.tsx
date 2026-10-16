import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center gap-6 p-8">
      <h1 className="font-display text-5xl text-midnight">Fam</h1>
      <p className="text-text-muted">Platform administration console</p>
      <Link href="/login" className="btn-primary">
        Sign in
      </Link>
    </main>
  );
}
