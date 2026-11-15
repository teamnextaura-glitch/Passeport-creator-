import type { Metadata } from "next";
import { Inter, Space_Grotesk } from "next/font/google";
import "./globals.css";

// Polices téléchargées au build et servies par le site : aucune requête tierce côté visiteur.
// Variables nommées d'après les polices cibles (Clash Display, Satoshi) pour les remplacer plus tard.
const display = Space_Grotesk({ subsets: ["latin"], variable: "--font-clash", display: "swap" });
const body = Inter({ subsets: ["latin"], variable: "--font-satoshi", display: "swap" });

export const metadata: Metadata = {
  title: "Passeport Créateur — votre réputation vous appartient",
  description:
    "Un passeport de créateur vérifiable par tous, attribué par un jury de pairs tiré au sort. Prototype sur testnet Polygon Amoy.",
  openGraph: {
    title: "Passeport Créateur",
    description: "Un passeport de créateur vérifiable par tous. Prototype testnet, code non audité.",
    type: "website",
    locale: "fr_FR",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={`dark ${display.variable} ${body.variable}`}>
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
