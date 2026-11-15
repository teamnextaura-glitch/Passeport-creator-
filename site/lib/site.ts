// Constantes partagées par les pages publiques (hors démos).

export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL || "https://passeport-createur.vercel.app").replace(/\/$/, "");

export const FOUNDER = "0x723DFb2A1dd6a8f4b5Dd2a499A0B870f13A60477";

// Les URL viennent des variables d'environnement : un lien vide n'est pas affiché.
export const SOCIALS: [string, string | undefined][] = [
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

// Répartition des 1 000 000 000 PCT (document de conception, §11.1)
export const ALLOCATIONS: { label: string; percent: number; tokens: string; holder: string; lockup: string; color: string }[] = [
  { label: "Communauté", percent: 35, tokens: "350 000 000", holder: "Safe DAO, enveloppe d'émission", lockup: "Émission plafonnée à 87,5 M par an sur 4 ans", color: "#3DF5FF" },
  { label: "Fondateur", percent: 25, tokens: "250 000 000", holder: "Contrat FounderVesting", lockup: "Cliff 12 mois + linéaire 36 mois", color: "#7C5CFF" },
  { label: "Investisseurs", percent: 20, tokens: "200 000 000", holder: "Safe DAO, réservé", lockup: "Non distribué tant qu'aucune structure ne peut contracter", color: "#B49BFF" },
  { label: "Trésorerie DAO", percent: 15, tokens: "150 000 000", holder: "Safe DAO", lockup: "Dépense sur vote + Timelock 48 h", color: "#E8C77A" },
  { label: "Réserve", percent: 5, tokens: "50 000 000", holder: "Safe DAO", lockup: "Intouchable 2 ans", color: "#8A8A9A" },
];
