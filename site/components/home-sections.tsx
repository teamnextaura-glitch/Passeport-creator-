import Link from "next/link";
import { ShieldCheck, Repeat, Scale } from "lucide-react";
import { ALLOCATIONS, FOUNDER, SOCIALS } from "@/lib/site";

const EXPLORER = process.env.NEXT_PUBLIC_EXPLORER_URL || "https://amoy.polygonscan.com";
const CONTACT = process.env.NEXT_PUBLIC_CONTACT_EMAIL;

// ---------- Démo live ----------

export function DemoLive() {
  return (
    <section id="demo-live" aria-labelledby="demo-live-titre" className="mx-auto max-w-7xl px-6 py-24">
      <div className="grid items-center gap-12 rounded-section border border-white/10 bg-halo p-8 md:grid-cols-2 md:p-16">
        <div>
          <p className="text-sm uppercase tracking-widest text-secondary">Démo live</p>
          <h2 id="demo-live-titre" className="mt-3 font-display text-4xl">Essayez en 60 secondes</h2>
          <p className="mt-4 max-w-xl text-lg text-muted">
            Sans wallet, sans inscription, sans aucune donnée envoyée. Cinq simulations : votre niveau, son évolution sur
            un an, une contestation, la fiche vue par un annonceur, le mur des Passeports.
          </p>
          <Link href="/demo" className="mt-8 inline-block rounded-pill bg-primary px-7 py-3 font-medium text-white shadow-premium">
            Ouvrir les démos
          </Link>
        </div>
        {/* Aperçu statique : pas de composant animé ici, pour un rendu léger */}
        <div aria-hidden className="mx-auto w-full max-w-xs">
          <div className="relative aspect-[5/7] overflow-hidden rounded-section border border-demo-base/40 bg-white/[0.04] p-6 shadow-premium saturate-50">
            <span className="pointer-events-none absolute inset-0 flex -rotate-[28deg] items-center justify-center font-display text-6xl font-bold tracking-widest text-white/10">
              DÉMO
            </span>
            <div className="relative flex h-full flex-col justify-between">
              <span className="text-sm text-muted">PASSEPORT CRÉATEUR</span>
              <div>
                <p className="font-display text-3xl">Votre pseudo</p>
                <p className="text-muted">Twitch</p>
              </div>
              <div className="flex items-end justify-between">
                <p className="font-display text-4xl text-demo-soft">2</p>
                <p className="rounded-pill border border-demo-base px-3 py-1 text-sm text-demo-soft">Confirmé</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ---------- Créateurs ----------

const BENEFITS = [
  { icon: ShieldCheck, title: "Une réputation qui vous suit", text: "Changez de plateforme, perdez un compte : votre Passeport reste à votre adresse." },
  { icon: Scale, title: "Le sérieux, pas la taille", text: "Le jury juge la qualité et la régularité. 500 abonnés suffisent pour candidater." },
  { icon: Repeat, title: "Gratuit et contestable", text: "Candidater ne coûte rien. Chaque Passeport peut être contesté, ce qui le rend crédible." },
];

const TESTIMONIALS = [
  { quote: "Je change de plateforme tous les deux ans. Pour la première fois, mon historique me suit.", who: "Créatrice vidéo, 12 000 abonnés" },
  { quote: "Un jury de pairs plutôt qu'un algorithme : je sais au moins qui me juge, et sur quoi.", who: "Podcasteur, 3 000 écoutes par épisode" },
  { quote: "Les marques me demandaient des captures. Maintenant je leur envoie un lien.", who: "Streamer, 800 viewers en moyenne" },
];

export function ForCreators() {
  return (
    <section id="createurs" aria-labelledby="createurs-titre" className="mx-auto max-w-7xl px-6 py-24">
      <h2 id="createurs-titre" className="font-display text-4xl">Pour les créateurs</h2>
      <ul className="mt-12 grid gap-6 md:grid-cols-3">
        {BENEFITS.map((b) => (
          <li key={b.title} className="rounded-card border border-white/10 bg-white/[0.03] p-6">
            <b.icon className="h-7 w-7 text-primary" aria-hidden />
            <h3 className="mt-5 font-display text-xl">{b.title}</h3>
            <p className="mt-3 text-muted">{b.text}</p>
          </li>
        ))}
      </ul>
      <ul className="mt-10 grid gap-6 md:grid-cols-3" aria-label="Témoignages fictifs">
        {TESTIMONIALS.map((t) => (
          <li key={t.who} className="relative rounded-card border border-white/10 p-6">
            <span className="absolute right-4 top-4 rounded-pill bg-red-600 px-2 py-0.5 text-xs font-bold tracking-wider text-white">
              EXEMPLE FICTIF
            </span>
            <blockquote className="mt-6 text-lg">« {t.quote} »</blockquote>
            <p className="mt-4 text-sm text-muted">{t.who}</p>
          </li>
        ))}
      </ul>
      <p className="mt-4 text-sm text-muted">
        Ces témoignages illustrent l&apos;usage visé. Ils ne viennent pas de créateurs réels.
      </p>
    </section>
  );
}

// ---------- Annonceurs ----------

const SAMPLE_ROWS: [string, string][] = [
  ["Niveau", "3 sur 5, Établi"],
  ["Statut", "Actif"],
  ["Ancienneté", "14 mois"],
  ["Contestations", "1, rejetée"],
  ["Jury", "5 créateurs tirés au sort"],
];

export function ForAdvertisers() {
  return (
    <section id="annonceurs" aria-labelledby="annonceurs-titre" className="mx-auto grid max-w-7xl gap-12 px-6 py-24 md:grid-cols-2">
      <div>
        <h2 id="annonceurs-titre" className="font-display text-4xl">Pour les annonceurs</h2>
        <p className="mt-6 text-lg text-muted">
          Avant de signer un créateur, consultez sa fiche : un signal de sérieux attribué par ses pairs, public, gratuit
          et contestable. Ce n&apos;est pas une mesure d&apos;audience.
        </p>
        <div className="mt-8 flex flex-wrap gap-4">
          <Link href="/demo/verifier" className="rounded-pill bg-primary px-7 py-3 font-medium text-white shadow-premium">
            Tester le vérificateur
          </Link>
          {CONTACT ? (
            <a href={`mailto:${CONTACT}`} className="rounded-pill border border-white/15 px-7 py-3 text-text hover:border-white/40">
              Nous écrire
            </a>
          ) : (
            <span className="rounded-pill border border-white/10 px-7 py-3 text-muted">Contact annoncé au lancement</span>
          )}
        </div>
      </div>
      <div className="overflow-hidden rounded-card border border-white/10">
        <p className="bg-red-600 px-4 py-2 text-sm font-bold text-white">FICHE D&apos;EXEMPLE — fictive</p>
        <dl className="divide-y divide-white/10">
          {SAMPLE_ROWS.map(([k, v]) => (
            <div key={k} className="flex justify-between gap-4 px-4 py-3">
              <dt className="text-muted">{k}</dt>
              <dd className="text-right">{v}</dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}

// ---------- DAO et transparence ----------

export function DaoTransparency() {
  return (
    <section id="dao" aria-labelledby="dao-titre" className="mx-auto max-w-7xl px-6 py-24">
      <h2 id="dao-titre" className="font-display text-4xl">DAO et transparence</h2>
      <p className="mt-6 max-w-3xl text-lg text-muted">
        Supply fixe de 1 000 000 000 PCT, un jeton utilitaire servant de caution. Il n&apos;est pas en vente, n&apos;est
        listé nulle part et <strong className="text-text">aucun rendement n&apos;est promis</strong>.
      </p>

      <div className="mt-10 flex h-4 overflow-hidden rounded-pill" role="img" aria-label="Répartition des jetons : communauté 35 %, fondateur 25 %, investisseurs 20 %, trésorerie 15 %, réserve 5 %">
        {ALLOCATIONS.map((a) => (
          <span key={a.label} style={{ width: `${a.percent}%`, background: a.color }} />
        ))}
      </div>

      <div className="mt-8 overflow-x-auto rounded-card border border-white/10">
        <table className="w-full min-w-[640px] text-left text-sm">
          <caption className="sr-only">Répartition des 1 000 000 000 PCT</caption>
          <thead className="text-muted">
            <tr className="border-b border-white/10">
              <th scope="col" className="px-4 py-3 font-medium">Allocation</th>
              <th scope="col" className="px-4 py-3 font-medium">%</th>
              <th scope="col" className="px-4 py-3 font-medium">Jetons</th>
              <th scope="col" className="px-4 py-3 font-medium">Détenteur</th>
              <th scope="col" className="px-4 py-3 font-medium">Verrouillage</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/10">
            {ALLOCATIONS.map((a) => (
              <tr key={a.label}>
                <th scope="row" className="px-4 py-3 font-medium">
                  <span className="mr-2 inline-block h-2.5 w-2.5 rounded-full align-middle" style={{ background: a.color }} aria-hidden />
                  {a.label}
                </th>
                <td className="px-4 py-3">{a.percent} %</td>
                <td className="px-4 py-3 font-mono">{a.tokens}</td>
                <td className="px-4 py-3 text-muted">{a.holder}</td>
                <td className="px-4 py-3 text-muted">{a.lockup}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <ul className="mt-8 grid gap-4 text-sm text-muted md:grid-cols-3">
        <li className="rounded-card border border-white/10 p-4">
          <strong className="text-text">Fondateur sans pouvoir.</strong> Adresse{" "}
          <a className="break-all font-mono hover:text-text" href={`${EXPLORER}/address/${FOUNDER}`}>{FOUNDER}</a> :
          bénéficiaire du vesting, aucun rôle d&apos;administration.
        </li>
        <li className="rounded-card border border-white/10 p-4">
          <strong className="text-text">Gouvernance.</strong> Vote Snapshot réservé aux Passeports actifs, exécution par
          un Safe et un Timelock de 48 h.
        </li>
        <li className="rounded-card border border-white/10 p-4">
          <strong className="text-text">Code non audité.</strong> Prototype sur testnet Polygon Amoy. N&apos;y engagez rien
          que vous ne puissiez perdre.
        </li>
      </ul>
    </section>
  );
}

// ---------- Réseaux ----------

export function Socials() {
  const socials = SOCIALS.filter((s): s is [string, string] => Boolean(s[1]));
  return (
    <section id="reseaux" aria-labelledby="reseaux-titre" className="border-y border-white/10 py-16">
      <div className="mx-auto max-w-7xl px-6">
        <h2 id="reseaux-titre" className="font-display text-2xl">Suivre le projet</h2>
        {socials.length > 0 ? (
          <ul className="mt-6 flex flex-wrap gap-3">
            {socials.map(([name, url]) => (
              <li key={name}>
                <a
                  href={url}
                  rel="noopener noreferrer"
                  target="_blank"
                  className="inline-block rounded-pill border border-white/15 px-5 py-2 text-text hover:border-primary"
                >
                  {name}
                </a>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-4 text-muted">
            X, Discord, GitHub, Telegram, Farcaster, LinkedIn, YouTube, Instagram et TikTok : comptes officiels annoncés au
            lancement.
          </p>
        )}
      </div>
    </section>
  );
}
