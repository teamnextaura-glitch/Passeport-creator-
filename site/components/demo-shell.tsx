"use client";
import Link from "next/link";
import { useState } from "react";
import { clearDemo } from "@/lib/demo-store";

export function DemoShell({ title, children }: { title: string; children: React.ReactNode }) {
  const [cleared, setCleared] = useState(false);
  return (
    <div className="min-h-screen bg-bg text-text">
      <p role="note" className="sticky top-0 z-50 border-b border-white/10 bg-bg/90 px-4 py-2 text-center text-sm backdrop-blur">
        <strong>DÉMO — Simulation.</strong> Aucune donnée saisie n&apos;est collectée. Aucun Passeport réel créé. Tout
        reste dans votre navigateur.
      </p>
      <main className="mx-auto max-w-3xl px-6 py-16">
        <Link href="/demo" className="text-sm text-muted hover:text-text">
          ← Toutes les démos
        </Link>
        <h1 className="mt-4 font-display text-4xl">{title}</h1>
        <div className="mt-10">{children}</div>
      </main>
      <footer className="mx-auto flex max-w-3xl flex-wrap items-center justify-between gap-4 px-6 pb-16 text-sm text-muted">
        <button
          type="button"
          onClick={() => {
            clearDemo();
            setCleared(true);
          }}
          className="rounded-pill border border-white/20 px-4 py-2 hover:border-white/50"
        >
          Effacer mes données de démo
        </button>
        <span role="status" aria-live="polite">
          {cleared ? "Données de démo effacées." : ""}
        </span>
        <Link href="/demo/legal" className="underline">
          Notice des démos
        </Link>
      </footer>
    </div>
  );
}
