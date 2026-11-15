"use client";
import { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { DemoShell } from "@/components/demo-shell";
import { PassportCard, type PassportData } from "@/components/passport-card";

const EVENTS: { month: number; level: PassportData["level"]; badge: string; text: string }[] = [
  { month: 0, level: 1, badge: "Certifié", text: "Votre dossier est accepté par un jury de cinq créateurs." },
  { month: 2, level: 1, badge: "Régulier", text: "Huit semaines de publication sans interruption." },
  { month: 4, level: 2, badge: "Juré", text: "Vous évaluez votre premier dossier. Niveau 2." },
  { month: 6, level: 2, badge: "Intègre", text: "Une contestation contre vous est rejetée par le jury." },
  { month: 8, level: 3, badge: "Reconnu", text: "Un premier annonceur vérifie votre Passeport. Niveau 3." },
  { month: 10, level: 3, badge: "Juge", text: "Vous tranchez votre première contestation." },
  { month: 12, level: 4, badge: "Référence", text: "Un an d'historique vérifiable. Niveau 4." },
];

export default function Timeline() {
  const [month, setMonth] = useState(0);
  const reached = EVENTS.filter((e) => e.month <= month);
  const current = reached[reached.length - 1];
  const data: PassportData = {
    pseudo: "Votre pseudo",
    platform: `Mois ${month}`,
    level: current.level,
    isDemo: true,
    issuer: "demo",
  };

  return (
    <DemoShell title="Voyez votre Passeport évoluer">
      <motion.div
        key={current.level}
        initial={{ scale: 0.96 }}
        animate={{ scale: 1 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
      >
        <PassportCard data={data} />
      </motion.div>

      <ul className="mt-8 flex min-h-10 flex-wrap justify-center gap-2" aria-label="Badges obtenus">
        <AnimatePresence>
          {reached.map((e) => (
            <motion.li
              key={e.badge}
              initial={{ opacity: 0, scale: 0.6 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.6 }}
              transition={{ duration: 0.4 }}
              className="rounded-pill border border-demo-base px-3 py-1 text-sm text-demo-soft"
            >
              {e.badge}
            </motion.li>
          ))}
        </AnimatePresence>
      </ul>

      <label className="mt-10 block">
        <span className="text-sm text-muted">Mois {month} sur 12</span>
        <input
          type="range"
          min={0}
          max={12}
          step={1}
          value={month}
          onChange={(e) => setMonth(Number(e.target.value))}
          className="mt-3 w-full accent-[#8E88A8]"
        />
      </label>
      <p className="mt-4 text-lg" aria-live="polite">
        Mois {current.month} : {current.text}
      </p>
      <p className="mt-2 text-sm text-muted">Scénario illustratif. Aucun niveau n&apos;est garanti : il dépend du vote des jurys.</p>
    </DemoShell>
  );
}
