import Link from "next/link";
import { Hero } from "@/components/hero";
import { PassportCard } from "@/components/passport-card";
import { HowItWorks } from "@/components/how-it-works";
import { Footer } from "@/components/footer";

const PROBLEMS = [
  ["01", "Un compte supprimé, dix ans effacés."],
  ["02", "Des chiffres invisibles hors de la plateforme."],
  ["03", "Des faux comptes impossibles à distinguer."],
  ["04", "Des annonceurs qui signent à l'aveugle."],
];

export default function Home() {
  return (
    <>
      <Hero />

      <section aria-labelledby="probleme" className="mx-auto max-w-7xl px-6 py-24">
        <h2 id="probleme" className="font-display text-4xl">Le problème</h2>
        <ul className="mt-12 grid gap-6 md:grid-cols-4">
          {PROBLEMS.map(([n, t]) => (
            <li key={n} className="rounded-card border border-white/10 bg-white/[0.03] p-6">
              <span className="font-display text-2xl text-primary">{n}</span>
              <p className="mt-4 text-lg">{t}</p>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="passeport" className="mx-auto grid max-w-7xl items-center gap-16 px-6 py-24 md:grid-cols-2">
        <PassportCard data={{ pseudo: "Exemple", platform: "YouTube", level: 3, isDemo: true, issuer: "demo" }} />
        <div>
          <h2 id="passeport" className="font-display text-4xl">Le Passeport</h2>
          <ul className="mt-8 space-y-4 text-lg text-muted">
            <li><strong className="text-text">Niveau 1 à 5</strong>, fixé par la médiane d&apos;un jury de pairs.</li>
            <li><strong className="text-text">Non transférable</strong> : il ne s&apos;achète pas et ne se revend pas.</li>
            <li><strong className="text-text">Contestable</strong> par n&apos;importe qui, sur pièces et avec une mise.</li>
            <li><strong className="text-text">Lisible par tous</strong>, sans compte et sans plateforme intermédiaire.</li>
          </ul>
        </div>
      </section>

      <HowItWorks />

      <section aria-labelledby="demo" className="mx-auto max-w-7xl px-6 py-24">
        <div className="rounded-section border border-white/10 bg-halo p-10 md:p-16">
          <h2 id="demo" className="font-display text-4xl">Essayez en 60 secondes</h2>
          <p className="mt-4 max-w-xl text-lg text-muted">Sans wallet, sans inscription, sans aucune donnée envoyée.</p>
          <Link href="/demo" className="mt-8 inline-block rounded-pill bg-primary px-7 py-3 font-medium text-white shadow-premium">
            Ouvrir les démos
          </Link>
        </div>
      </section>

      <Footer />
    </>
  );
}
