import Link from "next/link";

// Les URL viennent des variables d'environnement : un lien vide n'est pas affiché.
const SOCIALS: [string, string | undefined][] = [
  ["X", process.env.NEXT_PUBLIC_X_URL],
  ["Discord", process.env.NEXT_PUBLIC_DISCORD_URL],
  ["GitHub", process.env.NEXT_PUBLIC_GITHUB_URL],
  ["Telegram", process.env.NEXT_PUBLIC_TELEGRAM_URL],
  ["Farcaster", process.env.NEXT_PUBLIC_FARCASTER_URL],
  ["LinkedIn", process.env.NEXT_PUBLIC_LINKEDIN_URL],
  ["YouTube", process.env.NEXT_PUBLIC_YOUTUBE_URL],
  ["Instagram", process.env.NEXT_PUBLIC_INSTAGRAM_URL],
  ["TikTok", process.env.NEXT_PUBLIC_TIKTOK_URL],
];

const CONTRACTS: [string, string | undefined][] = [
  ["Passeport (SBT)", process.env.NEXT_PUBLIC_SBT_ADDRESS],
  ["Token PCT", process.env.NEXT_PUBLIC_TOKEN_ADDRESS],
  ["Vesting fondateur", process.env.NEXT_PUBLIC_VESTING_ADDRESS],
  ["Registre", process.env.NEXT_PUBLIC_REGISTRY_ADDRESS],
  ["Contestation", process.env.NEXT_PUBLIC_CONTEST_ADDRESS],
];

const EXPLORER = process.env.NEXT_PUBLIC_EXPLORER_URL || "https://amoy.polygonscan.com";
const FOUNDER = "0x723DFb2A1dd6a8f4b5Dd2a499A0B870f13A60477";

function short(a: string) {
  return `${a.slice(0, 6)}…${a.slice(-4)}`;
}

export function Footer() {
  const socials = SOCIALS.filter((s): s is [string, string] => Boolean(s[1]));
  const contracts = CONTRACTS.filter((c): c is [string, string] => Boolean(c[1]));
  return (
    <footer className="border-t border-white/10 px-6 py-16 text-sm text-muted">
      <div className="mx-auto grid max-w-7xl gap-12 md:grid-cols-3">
        <nav aria-label="Réseaux sociaux">
          <h2 className="font-display text-base text-text">Suivre le projet</h2>
          {socials.length > 0 ? (
            <ul className="mt-4 grid grid-cols-2 gap-2">
              {socials.map(([name, url]) => (
                <li key={name}>
                  <a href={url} rel="noopener noreferrer" target="_blank" className="hover:text-text">
                    {name}
                  </a>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-4">Comptes officiels annoncés au lancement.</p>
          )}
        </nav>

        <div>
          <h2 className="font-display text-base text-text">Contrats</h2>
          <ul className="mt-4 space-y-2">
            {contracts.length === 0 && <li>Pas encore déployés sur Amoy.</li>}
            {contracts.map(([name, a]) => (
              <li key={name}>
                {name} :{" "}
                <a className="font-mono hover:text-text" href={`${EXPLORER}/address/${a}`}>
                  {short(a)}
                </a>
              </li>
            ))}
            <li>
              Fondateur (vesting uniquement, aucun rôle) :{" "}
              <a className="font-mono hover:text-text" href={`${EXPLORER}/address/${FOUNDER}`}>
                {short(FOUNDER)}
              </a>
            </li>
          </ul>
        </div>

        <nav aria-label="Informations légales">
          <h2 className="font-display text-base text-text">Informations</h2>
          <ul className="mt-4 space-y-2">
            <li><Link href="/legal" className="hover:text-text">Mentions légales</Link></li>
            <li><Link href="/privacy" className="hover:text-text">Confidentialité</Link></li>
            <li><Link href="/demo/legal" className="hover:text-text">Notice des démos</Link></li>
          </ul>
          <p className="mt-6">Code non audité. Testnet uniquement. Aucun rendement financier n&apos;est promis.</p>
        </nav>
      </div>
    </footer>
  );
}
