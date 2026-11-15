"use client";
import { useState } from "react";
import { motion } from "framer-motion";
import { DemoShell } from "@/components/demo-shell";

/** Hachage local et déterministe : le même pseudo donne toujours la même fiche fictive. */
function seed(s: string) {
  let h = 2166136261;
  for (const c of s.toLowerCase()) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return h >>> 0;
}

function fakeProfile(pseudo: string) {
  const h = seed(pseudo);
  const level = 1 + (h % 5);
  return {
    level,
    months: 3 + ((h >>> 3) % 30),
    evaluations: (h >>> 5) % 40,
    contests: (h >>> 9) % 3,
    badges: ["Régulier", "Juré", "Intègre", "Reconnu", "Référence"].slice(0, level),
  };
}

export default function Verifier() {
  const [input, setInput] = useState("");
  const [query, setQuery] = useState("");
  const p = query ? fakeProfile(query) : null;
  const rows: [string, string][] = p
    ? [
        ["Niveau", `${p.level} sur 5`],
        ["Statut", "Actif"],
        ["Ancienneté", `${p.months} mois`],
        ["Évaluations rendues", String(p.evaluations)],
        ["Contestations rejetées", String(p.contests)],
        ["Badges", p.badges.join(", ")],
      ]
    : [];
  return (
    <DemoShell title="Vérificateur pour annonceurs">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          setQuery(input.trim());
        }}
        className="flex gap-3"
      >
        <label className="flex-1">
          <span className="sr-only">Pseudo fictif</span>
          <input
            value={input}
            onChange={(e) => setInput(e.target.value.slice(0, 24))}
            placeholder="Un pseudo fictif"
            autoComplete="off"
            className="w-full rounded-card border border-white/15 bg-transparent px-4 py-3"
          />
        </label>
        <button className="rounded-pill bg-primary px-6 py-3 text-white">Vérifier</button>
      </form>
      <p className="mt-3 text-sm">
        <strong>Entrez n&apos;importe quel pseudo (même fictif). Ces données ne quittent pas votre navigateur.</strong>
      </p>

      {p && (
        <div key={query} className="mt-8 overflow-hidden rounded-card border border-demo-base saturate-50" aria-live="polite">
          <p className="bg-red-600 px-4 py-2 text-sm font-bold text-white">
            FICHE FICTIVE — SIMULATION. Elle ne décrit aucun créateur réel.
          </p>
          <dl className="divide-y divide-white/10">
            {rows.map(([k, v], i) => (
              <motion.div
                key={k}
                initial={{ opacity: 0, x: -16 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.12 }}
                className="flex justify-between gap-4 px-4 py-3"
              >
                <dt className="text-muted">{k}</dt>
                <dd className="text-right">{v}</dd>
              </motion.div>
            ))}
          </dl>
        </div>
      )}
    </DemoShell>
  );
}
