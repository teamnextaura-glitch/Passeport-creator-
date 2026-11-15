"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { QRCodeSVG } from "qrcode.react"; // génération locale, aucune requête
import { DemoShell } from "@/components/demo-shell";
import { PassportCard } from "@/components/passport-card";
import { loadDemo, saveDemo, toDemoPassport, toShareUrl, type DemoState } from "@/lib/demo-store";

const PLATFORMS = ["YouTube", "TikTok", "Twitch", "Instagram", "Podcast", "Autre"];
const QUESTIONS = [
  { q: "Qualité : comment décririez-vous votre production ?", a: ["Je débute", "Correcte", "Soignée", "Référence dans ma niche"] },
  { q: "Régularité : à quel rythme publiez-vous ?", a: ["Quand je peux", "Chaque mois", "Chaque semaine", "Plusieurs fois par semaine"] },
  { q: "Engagement : que fait votre communauté ?", a: ["Elle regarde", "Elle commente", "Elle partage", "Elle se mobilise"] },
];
const EMPTY: DemoState = { pseudo: "", platform: PLATFORMS[0], answers: [] };

export default function Simulator() {
  const [state, setState] = useState<DemoState>(EMPTY);
  const [step, setStep] = useState(0); // 0 identité, 1 à 3 questions, 4 résultat
  const [shareUrl, setShareUrl] = useState("");

  useEffect(() => {
    const saved = loadDemo();
    if (saved) {
      setState(saved);
      setStep(saved.answers.length === 3 ? 4 : 0);
    }
  }, []);

  const passport = toDemoPassport(state);

  useEffect(() => {
    if (step === 4) setShareUrl(toShareUrl(toDemoPassport(state)));
  }, [step, state]);

  function update(next: DemoState, nextStep: number) {
    setState(next);
    saveDemo(next);
    setStep(nextStep);
  }

  return (
    <DemoShell title="Simulateur de Passeport">
      <p className="text-sm text-muted" aria-live="polite">
        Étape {Math.min(step + 1, 4)} sur 4
      </p>
      <AnimatePresence mode="wait">
        <motion.div
          key={step}
          initial={{ opacity: 0, x: 40 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -40 }}
          transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
          className="mt-6"
        >
          {step === 0 && (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                update({ ...state, answers: [] }, 1);
              }}
              className="space-y-6"
            >
              <label className="block">
                <span className="text-sm text-muted">Pseudo d&apos;affichage</span>
                <input
                  value={state.pseudo}
                  onChange={(e) => setState({ ...state, pseudo: e.target.value.slice(0, 24) })}
                  autoComplete="off"
                  className="mt-2 w-full rounded-card border border-white/15 bg-transparent px-4 py-3"
                />
              </label>
              <fieldset>
                <legend className="text-sm text-muted">Plateforme principale</legend>
                <div className="mt-2 flex flex-wrap gap-2">
                  {PLATFORMS.map((p) => (
                    <button
                      key={p}
                      type="button"
                      aria-pressed={state.platform === p}
                      onClick={() => setState({ ...state, platform: p })}
                      className={`rounded-pill border px-4 py-2 ${
                        state.platform === p ? "border-primary bg-primary/20" : "border-white/15"
                      }`}
                    >
                      {p}
                    </button>
                  ))}
                </div>
              </fieldset>
              <p className="text-sm">
                <strong>Entrez n&apos;importe quel pseudo (même fictif). Ces données ne quittent pas votre navigateur.</strong>
              </p>
              <button className="rounded-pill bg-primary px-7 py-3 font-medium text-white">Continuer</button>
            </form>
          )}

          {step >= 1 && step <= 3 && (
            <fieldset>
              <legend className="font-display text-2xl">{QUESTIONS[step - 1].q}</legend>
              <div className="mt-6 grid gap-3">
                {QUESTIONS[step - 1].a.map((label, score) => (
                  <button
                    key={label}
                    type="button"
                    onClick={() =>
                      update({ ...state, answers: [...state.answers.slice(0, step - 1), score] }, step + 1)
                    }
                    className="rounded-card border border-white/15 px-5 py-4 text-left hover:border-primary"
                  >
                    {step === 3 ? `${label} → Générer` : label}
                  </button>
                ))}
              </div>
            </fieldset>
          )}

          {step === 4 && (
            <div className="space-y-8">
              <motion.div
                initial={{ rotateY: 180, opacity: 0 }}
                animate={{ rotateY: 0, opacity: 1 }}
                transition={{ duration: 0.8 }}
              >
                <PassportCard data={passport} />
              </motion.div>
              <p>
                <strong>
                  Ceci est une démonstration. Le Passeport affiché est fictif. Pour obtenir un vrai Passeport, connectez
                  votre wallet et demandez une certification.
                </strong>
              </p>
              <div className="flex flex-wrap items-center gap-6">
                {shareUrl && (
                  <div className="rounded-card bg-white p-3">
                    <QRCodeSVG value={shareUrl} size={120} title="Lien vers cette simulation" />
                  </div>
                )}
                <div className="space-y-3">
                  <Link href="/inscription" className="inline-block rounded-pill bg-primary px-7 py-3 font-medium text-white">
                    Créez le vrai, gratuitement
                  </Link>
                  <button type="button" onClick={() => update(EMPTY, 0)} className="block text-sm text-muted underline">
                    Recommencer
                  </button>
                </div>
              </div>
            </div>
          )}
        </motion.div>
      </AnimatePresence>
    </DemoShell>
  );
}
