"use client";
import { motion } from "framer-motion";
import { FileCheck, Dices, EyeOff, BadgeCheck } from "lucide-react";

const STEPS = [
  { icon: FileCheck, title: "Déposez vos preuves", text: "Liens, captures, statistiques. Vous prouvez que le compte est le vôtre." },
  { icon: Dices, title: "Un jury est tiré au sort", text: "Cinq créateurs certifiés, choisis par un aléa vérifiable. Personne ne les désigne." },
  { icon: EyeOff, title: "Ils votent en secret", text: "Chaque note est scellée puis révélée. Impossible de copier son voisin." },
  { icon: BadgeCheck, title: "Votre Passeport est émis", text: "Niveau 1 à 5, non transférable, vérifiable par n'importe qui." },
];

export function HowItWorks() {
  return (
    <section aria-labelledby="how" className="mx-auto max-w-7xl px-6 py-32">
      <h2 id="how" className="font-display text-4xl text-text">
        Quatre étapes, aucun intermédiaire
      </h2>
      <ol className="mt-16 grid gap-6 md:grid-cols-4">
        {STEPS.map((s, i) => (
          <motion.li
            key={s.title}
            initial={{ opacity: 0, y: 32 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.6, delay: i * 0.1, ease: [0.16, 1, 0.3, 1] }}
            className="rounded-card border border-white/10 bg-white/[0.03] p-6"
          >
            <s.icon className="h-7 w-7 text-primary" aria-hidden />
            <p className="mt-6 text-sm text-muted">Étape {i + 1}</p>
            <h3 className="mt-1 font-display text-xl text-text">{s.title}</h3>
            <p className="mt-3 text-muted">{s.text}</p>
          </motion.li>
        ))}
      </ol>
    </section>
  );
}
