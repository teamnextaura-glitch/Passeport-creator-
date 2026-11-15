"use client";
import Link from "next/link";
import { motion } from "framer-motion";

const EASE = [0.16, 1, 0.3, 1] as const;

/**
 * Hero cinématographique.
 * La scène Spline prévue (§8.3) est remplacée pour l'instant par un fond 100 % CSS :
 * halo radial pulsé + grille de points qui dérive. Aucune ressource tierce.
 */
export function Hero() {
  const lines = ["Votre réputation", "vous appartient."];
  return (
    <section className="relative flex min-h-screen items-center overflow-hidden bg-bg">
      <div className="pointer-events-none absolute inset-0 animate-pulse-halo bg-halo" aria-hidden />
      <div className="dot-grid pointer-events-none absolute inset-0 animate-drift" aria-hidden />
      <div
        className="pointer-events-none absolute -right-40 top-1/4 h-[36rem] w-[36rem] rounded-full bg-secondary/10 blur-3xl"
        aria-hidden
      />

      <div className="relative z-10 mx-auto w-full max-w-7xl px-6 py-32">
        <p className="mb-6 inline-block rounded-pill border border-white/15 px-4 py-1 text-sm text-muted">
          Prototype · testnet Polygon Amoy · code non audité
        </p>
        <h1 className="font-display text-hero font-semibold text-text">
          {lines.map((line, i) => (
            <span key={line} className="block overflow-hidden">
              <motion.span
                className="block"
                initial={{ y: "100%" }}
                animate={{ y: 0 }}
                transition={{ duration: 0.8, delay: i * 0.12, ease: EASE }}
              >
                {line}
              </motion.span>
            </span>
          ))}
        </h1>
        <p className="mt-6 max-w-xl text-lg text-muted">
          Un passeport de créateur vérifiable par tous, attribué par un jury tiré au sort. Aucune plateforme requise.
        </p>
        <div className="mt-10 flex flex-wrap gap-4">
          <Link
            href="/demo/simulator"
            className="rounded-pill bg-primary px-7 py-3 font-medium text-white shadow-premium transition duration-premium ease-premium hover:scale-[1.03]"
          >
            Simuler mon Passeport
          </Link>
          <Link href="/demo" className="rounded-pill border border-white/15 px-7 py-3 text-text hover:border-white/40">
            Voir les 5 démos
          </Link>
        </div>
        <dl className="mt-14 flex flex-wrap gap-x-10 gap-y-4 text-sm text-muted">
          {[
            ["Passeports", "—"],
            ["Évaluations", "—"],
            ["Contestations", "—"],
          ].map(([label, value]) => (
            <div key={label} className="flex flex-col-reverse">
              <dt>{label}</dt>
              <dd className="font-display text-3xl text-secondary">{value}</dd>
            </div>
          ))}
          <p className="w-full text-sm">Compteurs actifs dès le déploiement des contrats sur Amoy.</p>
        </dl>
      </div>
    </section>
  );
}
