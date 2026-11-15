import Link from "next/link";

export function LegalPage({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-bg text-text">
      <main className="mx-auto max-w-3xl px-6 py-16">
        <Link href="/" className="text-sm text-muted hover:text-text">
          ← Accueil
        </Link>
        <h1 className="mt-4 font-display text-4xl">{title}</h1>
        <div className="mt-10 space-y-6 text-lg leading-relaxed text-muted [&_strong]:text-text">{children}</div>
      </main>
    </div>
  );
}
