"use client";
import { useRef } from "react";
import { motion, useMotionValue, useSpring, useTransform, useReducedMotion } from "framer-motion";

export type PassportData = {
  pseudo: string;
  platform: string;
  level: 1 | 2 | 3 | 4 | 5;
  isDemo: boolean;
  issuer: "demo" | "polygon";
};

const LEVELS = {
  1: { name: "Émergent", color: "#8A8A9A" },
  2: { name: "Confirmé", color: "#7C5CFF" },
  3: { name: "Établi", color: "#3DF5FF" },
  4: { name: "Référence", color: "#B49BFF" },
  5: { name: "Éminent", color: "#E8C77A" },
} as const;

/** Carte Passeport 3D. Avec isDemo : palette désaturée, filigrane « DÉMO », bandeau « SIMULATION ». */
export function PassportCard({ data }: { data: PassportData }) {
  const ref = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const x = useMotionValue(0.5);
  const y = useMotionValue(0.5);
  const rotateY = useSpring(useTransform(x, [0, 1], [-12, 12]), { stiffness: 150, damping: 18 });
  const rotateX = useSpring(useTransform(y, [0, 1], [12, -12]), { stiffness: 150, damping: 18 });
  const glare = useTransform(x, [0, 1], ["0%", "100%"]);
  const level = LEVELS[data.level];
  const accent = data.isDemo ? "#8E88A8" : level.color;

  function onMove(e: React.PointerEvent) {
    if (reduced || !ref.current) return;
    const r = ref.current.getBoundingClientRect();
    x.set((e.clientX - r.left) / r.width);
    y.set((e.clientY - r.top) / r.height);
  }
  function onLeave() {
    x.set(0.5);
    y.set(0.5);
  }

  return (
    <div style={{ perspective: 1200 }} className="mx-auto w-full max-w-sm">
      <motion.div
        ref={ref}
        onPointerMove={onMove}
        onPointerLeave={onLeave}
        style={{ rotateX, rotateY, transformStyle: "preserve-3d", borderColor: `${accent}55` }}
        className={`relative aspect-[5/7] overflow-hidden rounded-section border bg-white/[0.04] p-6 shadow-premium backdrop-blur ${
          data.isDemo ? "saturate-50" : ""
        }`}
        role="img"
        aria-label={`${data.isDemo ? "Simulation de " : ""}Passeport de ${data.pseudo}, niveau ${data.level}, ${level.name}`}
      >
        <motion.div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-40 mix-blend-screen"
          style={{
            backgroundImage: `linear-gradient(115deg, transparent 30%, ${accent} 50%, transparent 70%)`,
            backgroundSize: "250% 100%",
            backgroundPositionX: glare,
          }}
        />

        {data.isDemo && (
          <>
            <span
              aria-hidden
              className="pointer-events-none absolute inset-0 flex -rotate-[28deg] items-center justify-center font-display text-7xl font-bold tracking-widest text-white/10"
            >
              DÉMO
            </span>
            <span className="absolute right-[-46px] top-[22px] w-44 rotate-45 bg-red-600 py-1 text-center text-xs font-bold tracking-widest text-white">
              SIMULATION
            </span>
          </>
        )}

        <div className="relative flex h-full flex-col justify-between" style={{ transform: "translateZ(40px)" }}>
          <header className="flex items-center justify-between text-sm text-muted">
            <span>PASSEPORT CRÉATEUR</span>
            <span>{data.isDemo ? "émetteur : demo" : "Polygon"}</span>
          </header>
          <div>
            <p className="break-words font-display text-3xl text-text">{data.pseudo}</p>
            <p className="text-muted">{data.platform}</p>
          </div>
          <footer className="flex items-end justify-between">
            <div>
              <p className="text-sm text-muted">Niveau</p>
              <p className="font-display text-4xl" style={{ color: accent }}>
                {data.level}
              </p>
            </div>
            <p className="rounded-pill border px-3 py-1 text-sm" style={{ borderColor: accent, color: accent }}>
              {level.name}
            </p>
          </footer>
        </div>
      </motion.div>
    </div>
  );
}
