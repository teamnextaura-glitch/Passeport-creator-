"use client";
import { useState } from "react";
import { motion } from "framer-motion";
import { DemoShell } from "@/components/demo-shell";

type Vote = "rejeter" | "rétrograder" | "révoquer";
const CHOICES: Vote[] = ["rejeter", "rétrograder", "révoquer"];
const OTHERS: Vote[] = ["révoquer", "rétrograder", "rejeter", "révoquer"]; // les 4 autres juges, figés
const JUDGE_STAKE = 200;
const CHALLENGE_STAKE = 500;

/** Mêmes règles que Contestation.resolve(), en version lisible. */
function resolveContest(mine: Vote) {
  const votes = [mine, ...OTHERS];
  const reject = votes.filter((v) => v === "rejeter").length;
  const upheld = votes.length - reject > reject;
  const winners = votes.filter((v) => (v !== "rejeter") === upheld).length;
  const pot = (votes.length - winners) * JUDGE_STAKE + (upheld ? 0 : CHALLENGE_STAKE);
  const burned = pot * 0.1;
  const net = pot - burned;
  const revoke = votes.filter((v) => v === "révoquer").length;
  const down = votes.filter((v) => v === "rétrograder").length;
  const sanction = revoke > down ? "révoqué" : "rétrogradé d'un niveau";
  return {
    votes,
    upheld,
    burned,
    outcome: upheld ? `Passeport ${sanction}` : "Contestation rejetée, Passeport rétabli",
    youWin: (mine !== "rejeter") === upheld,
    judgeShare: Math.floor((upheld ? net / 2 : net) / winners),
    challengerShare: upheld ? net / 2 : 0,
  };
}

export default function ContestDemo() {
  const [mine, setMine] = useState<Vote | null>(null);
  const r = mine ? resolveContest(mine) : null;
  return (
    <DemoShell title="Contestation en direct : vous êtes juge">
      <section className="rounded-card border border-white/10 p-6">
        <h2 className="font-display text-xl">Affaire fictive n° 12</h2>
        <p className="mt-2 text-muted">Un Passeport de niveau 3 est accusé d&apos;avoir acheté des abonnés. Trois pièces au dossier :</p>
        <ul className="mt-3 list-disc pl-5 text-muted">
          <li>+40 000 abonnés en 48 h, sans vidéo publiée</li>
          <li>Taux de commentaires divisé par dix sur la même période</li>
          <li>Le créateur invoque une reprise de sa vidéo par un grand compte, sans lien à l&apos;appui</li>
        </ul>
        <p className="mt-4 text-sm">
          Votre caution : {JUDGE_STAKE} jetons fictifs. Vous la perdez si vous votez avec la minorité.
        </p>
      </section>

      {!r && (
        <div className="mt-8 flex flex-wrap gap-3">
          {CHOICES.map((v) => (
            <button
              key={v}
              type="button"
              onClick={() => setMine(v)}
              className="rounded-pill border border-white/20 px-6 py-3 capitalize hover:border-primary"
            >
              {v}
            </button>
          ))}
        </div>
      )}

      {r && (
        <div className="mt-8 space-y-6" aria-live="polite">
          <ol className="grid grid-cols-5 gap-2">
            {r.votes.map((v, i) => (
              <motion.li
                key={i}
                initial={{ opacity: 0, rotateX: 90 }}
                animate={{ opacity: 1, rotateX: 0 }}
                transition={{ delay: i * 0.5, duration: 0.5 }}
                className="rounded-card border border-white/10 p-3 text-center text-sm"
              >
                <span className="block text-muted">{i === 0 ? "Vous" : `Juge ${i + 1}`}</span>
                <span className="capitalize">{v}</span>
              </motion.li>
            ))}
          </ol>
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 2.8 }} className="space-y-2">
            <p className="font-display text-2xl">{r.outcome}</p>
            <p>
              {r.youWin
                ? `Vous êtes dans la majorité : caution rendue, +${r.judgeShare} jetons.`
                : `Vous êtes en minorité : vos ${JUDGE_STAKE} jetons de caution sont perdus.`}
            </p>
            <p className="text-muted">
              {r.burned} jetons brûlés.{" "}
              {r.upheld
                ? `Le contestataire récupère sa mise et reçoit ${r.challengerShare} jetons.`
                : `Le contestataire perd sa mise de ${CHALLENGE_STAKE} jetons.`}
            </p>
            <button type="button" onClick={() => setMine(null)} className="text-sm underline">
              Rejouer avec un autre vote
            </button>
          </motion.div>
        </div>
      )}
    </DemoShell>
  );
}
