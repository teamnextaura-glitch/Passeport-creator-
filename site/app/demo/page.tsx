import Link from "next/link";

const DEMOS = [
  ["/demo/simulator", "Simulateur de Passeport", "Trois questions, un niveau estimé, une carte holographique."],
  ["/demo/timeline", "Voyez votre Passeport évoluer", "Douze mois de réputation en un curseur."],
  ["/demo/contest", "Contestation en direct", "Vous êtes juge : votez et voyez la résolution."],
  ["/demo/verifier", "Vérificateur pour annonceurs", "Ce qu'un annonceur voit en tapant un pseudo."],
  ["/demo/wall", "Mur des Passeports", "Une galerie filtrable de Passeports fictifs."],
];

export default function DemoIndex() {
  return (
    <div className="min-h-screen bg-bg text-text">
      <p role="note" className="border-b border-white/10 px-4 py-2 text-center text-sm">
        <strong>DÉMO — Simulation.</strong> Aucune donnée saisie n&apos;est collectée. Tout reste dans votre navigateur.
      </p>
      <main className="mx-auto max-w-4xl px-6 py-16">
        <Link href="/" className="text-sm text-muted hover:text-text">← Accueil</Link>
        <h1 className="mt-4 font-display text-4xl">Cinq démos, zéro donnée envoyée</h1>
        <ul className="mt-10 grid gap-4 md:grid-cols-2">
          {DEMOS.map(([href, title, text]) => (
            <li key={href}>
              <Link href={href} className="block h-full rounded-card border border-white/10 bg-white/[0.03] p-6 transition hover:border-primary">
                <h2 className="font-display text-xl">{title}</h2>
                <p className="mt-2 text-muted">{text}</p>
              </Link>
            </li>
          ))}
        </ul>
        <p className="mt-10 text-sm text-muted">
          <Link href="/demo/legal" className="underline">Notice des démos</Link>
        </p>
      </main>
    </div>
  );
}
