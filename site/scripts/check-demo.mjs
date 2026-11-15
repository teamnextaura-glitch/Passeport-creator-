// Garde-fou RGPD exécuté avant chaque build (npm run build -> prebuild).
// Échoue si une page sous app/demo importe un client Supabase, appelle fetch,
// écrit un cookie ou charge un outil de mesure d'audience.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("../app/demo", import.meta.url));
const RULES = [
  [/from\s+["']@supabase/, "import d'un client Supabase"],
  [/\bfetch\s*\(/, "appel à fetch()"],
  [/@vercel\/analytics|plausible|googletagmanager|gtag\(/i, "outil de mesure d'audience"],
  [/document\.cookie/, "écriture de cookie"],
];

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}

const errors = [];
for (const file of walk(ROOT).filter((f) => /\.(t|j)sx?$/.test(f))) {
  const src = readFileSync(file, "utf8");
  for (const [re, label] of RULES) if (re.test(src)) errors.push(`${file} : ${label}`);
}

if (errors.length) {
  console.error("check-demo : règles RGPD des démos non respectées\n" + errors.join("\n"));
  process.exit(1);
}
console.log("check-demo : aucune requête réseau, aucun cookie, aucun traceur dans app/demo.");
