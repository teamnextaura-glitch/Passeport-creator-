import Link from "next/link";
import { LegalPage } from "@/components/legal-page";

export const metadata = { title: "Inscription — Passeport Créateur" };

export default function Inscription() {
  const discord = process.env.NEXT_PUBLIC_DISCORD_URL;
  return (
    <LegalPage title="Les candidatures ouvrent bientôt">
      <p>
        Le protocole tourne aujourd&apos;hui en prototype, sur réseau de test. Les premières certifications seront
        réservées à une cohorte de créateurs évalués à la main.
      </p>
      {discord ? (
        <p>
          Pour en faire partie, rejoignez le{" "}
          <a href={discord} className="underline" rel="noopener noreferrer" target="_blank">
            Discord du projet
          </a>
          .
        </p>
      ) : (
        <p>Les canaux pour candidater seront annoncés ici.</p>
      )}
      <p>
        <Link href="/demo/simulator" className="underline">Revenir au simulateur</Link>
      </p>
    </LegalPage>
  );
}
