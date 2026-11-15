"use client";
import { useEffect, useState } from "react";
import { DemoShell } from "@/components/demo-shell";
import { PassportCard, type PassportData } from "@/components/passport-card";
import { fromFragment } from "@/lib/demo-store";

export default function Result() {
  const [p, setP] = useState<PassportData | null>(null);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    setP(fromFragment(window.location.hash));
    setReady(true);
  }, []);
  return (
    <DemoShell title="Résultat de simulation">
      <p role="alert" className="mb-8 rounded-card bg-red-600 px-4 py-3 font-medium text-white">
        Ceci est une simulation, aucun Passeport réel n&apos;a été créé.
      </p>
      {p ? <PassportCard data={p} /> : ready && <p className="text-muted">Lien de simulation invalide ou incomplet.</p>}
    </DemoShell>
  );
}
