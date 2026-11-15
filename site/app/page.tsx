import { Hero } from "@/components/hero";
import { PassportCard } from "@/components/passport-card";
import { HowItWorks } from "@/components/how-it-works";
import { Footer } from "@/components/footer";
import { SiteNav } from "@/components/site-nav";
import { DaoTransparency, DemoLive, ForAdvertisers, ForCreators, Socials } from "@/components/home-sections";

const PROBLEMS = [
  ["01", "Un compte supprimé, dix ans effacés."],
  ["02", "Des chiffres invisibles hors de la plateforme."],
  ["03", "Des faux comptes impossibles à distinguer."],
  ["04", "Des annonceurs qui signent à l'aveugle."],
];

export default function Home() {
  return (
    <>
      <SiteNav />
      <main id="contenu">
        <Hero />

        <section id="probleme" aria-labelledby="probleme-titre" className="mx-auto max-w-7xl px-6 py-24">
          <h2 id="probleme-titre" className="font-display text-4xl">Le problème</h2>
          <ul className="mt-12 grid gap-6 md:grid-cols-4">
            {PROBLEMS.map(([n, t]) => (
              <li key={n} className="rounded-card border border-white/10 bg-white/[0.03] p-6">
                <span className="font-display text-2xl text-primary">{n}</span>
                <p className="mt-4 text-lg">{t}</p>
              </li>
            ))}
          </ul>
        </section>

        <section
          id="passeport"
          aria-labelledby="passeport-titre"
          className="mx-auto grid max-w-7xl items-center gap-16 px-6 py-24 md:grid-cols-2"
        >
          <PassportCard data={{ pseudo: "Exemple", platform: "YouTube", level: 3, isDemo: true, issuer: "demo" }} />
          <div>
            <h2 id="passeport-titre" className="font-display text-4xl">Le Passeport</h2>
            <ul className="mt-8 space-y-4 text-lg text-muted">
              <li><strong className="text-text">Niveau 1 à 5</strong>, fixé par la médiane d&apos;un jury de pairs.</li>
              <li><strong className="text-text">Non transférable</strong> : il ne s&apos;achète pas et ne se revend pas.</li>
              <li><strong className="text-text">Contestable</strong> par n&apos;importe qui, sur pièces et avec une mise.</li>
              <li><strong className="text-text">Lisible par tous</strong>, sans compte et sans plateforme intermédiaire.</li>
            </ul>
          </div>
        </section>

        <HowItWorks />
        <DemoLive />
        <ForCreators />
        <ForAdvertisers />
        <DaoTransparency />
        <Socials />
      </main>
      <Footer />
    </>
  );
}
