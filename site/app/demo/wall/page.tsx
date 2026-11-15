"use client";
import { useState } from "react";
import { motion } from "framer-motion";
import { DemoShell } from "@/components/demo-shell";
import { PassportCard, type PassportData } from "@/components/passport-card";
import wallData from "@/data/wall.json"; // statique : aucune requête à l'exécution

type WallItem = { id: string; pseudo: string; platform: string; level: number; isDemo: boolean };
const wall = wallData as WallItem[];

export default function Wall() {
  const [platform, setPlatform] = useState("Toutes");
  const [level, setLevel] = useState(0);
  const platforms = ["Toutes", ...Array.from(new Set(wall.map((w) => w.platform)))];
  const items = wall.filter(
    (w) => (platform === "Toutes" || w.platform === platform) && (level === 0 || w.level === level)
  );
  return (
    <DemoShell title="Mur des Passeports">
      <div className="flex flex-wrap gap-4">
        <label className="text-sm text-muted">
          Plateforme
          <select
            value={platform}
            onChange={(e) => setPlatform(e.target.value)}
            className="ml-2 rounded-card border border-white/15 bg-bg px-3 py-2 text-text"
          >
            {platforms.map((p) => (
              <option key={p}>{p}</option>
            ))}
          </select>
        </label>
        <label className="text-sm text-muted">
          Niveau
          <select
            value={level}
            onChange={(e) => setLevel(Number(e.target.value))}
            className="ml-2 rounded-card border border-white/15 bg-bg px-3 py-2 text-text"
          >
            <option value={0}>Tous</option>
            {[1, 2, 3, 4, 5].map((l) => (
              <option key={l} value={l}>
                {l}
              </option>
            ))}
          </select>
        </label>
      </div>
      <p className="mt-3 text-sm text-muted">
        {items.length} Passeports, tous fictifs. Les Passeports réels du testnet apparaîtront ici après le déploiement des contrats.
      </p>
      <ul className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
        {items.map((w, i) => (
          <motion.li
            key={w.id}
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: (i % 6) * 0.05 }}
          >
            <PassportCard
              data={{
                pseudo: w.pseudo,
                platform: w.platform,
                level: w.level as PassportData["level"],
                isDemo: true,
                issuer: "demo",
              }}
            />
          </motion.li>
        ))}
      </ul>
    </DemoShell>
  );
}
