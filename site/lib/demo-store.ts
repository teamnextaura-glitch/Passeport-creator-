// Seule porte d'accès au stockage des démos. Rien ne quitte le navigateur.
import type { PassportData } from "@/components/passport-card";

const KEY = "pc-demo-v1";

export type DemoState = { pseudo: string; platform: string; answers: number[] };

export function loadDemo(): DemoState | null {
  try {
    const raw = window.localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as DemoState) : null;
  } catch {
    return null; // stockage indisponible : la démo marche quand même, en mémoire
  }
}

export function saveDemo(state: DemoState) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* navigation privée ou stockage refusé */
  }
}

export function clearDemo() {
  try {
    Object.keys(window.localStorage)
      .filter((k) => k.startsWith("pc-demo"))
      .forEach((k) => window.localStorage.removeItem(k));
  } catch {
    /* rien à effacer */
  }
}

/** 3 réponses notées 0 à 3. Total 0 à 9 ramené à un niveau 1 à 5. */
export function estimateLevel(answers: number[]): PassportData["level"] {
  const sum = answers.reduce((a, b) => a + b, 0);
  return Math.min(5, 1 + Math.floor(sum / 2)) as PassportData["level"];
}

export function toDemoPassport(s: DemoState): PassportData {
  return {
    pseudo: s.pseudo.trim() || "Anonyme",
    platform: s.platform,
    level: estimateLevel(s.answers),
    isDemo: true,
    issuer: "demo",
  };
}

/** Le résultat voyage dans le fragment (#) : il n'est jamais envoyé au serveur. */
export function toShareUrl(p: PassportData): string {
  return `${window.location.origin}/demo/result#p=${encodeURIComponent(JSON.stringify(p))}`;
}

export function fromFragment(hash: string): PassportData | null {
  try {
    const p = JSON.parse(decodeURIComponent(hash.replace(/^#p=/, ""))) as Partial<PassportData>;
    const level = Math.min(5, Math.max(1, Number(p.level) || 1)) as PassportData["level"];
    // un lien ne peut jamais produire un « vrai » Passeport
    return {
      pseudo: String(p.pseudo ?? "Anonyme").slice(0, 24),
      platform: String(p.platform ?? "").slice(0, 24),
      level,
      isDemo: true,
      issuer: "demo",
    };
  } catch {
    return null;
  }
}
