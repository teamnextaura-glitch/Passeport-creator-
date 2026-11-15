import { LegalPage } from "@/components/legal-page";

export const metadata = { title: "Mentions légales — Passeport Créateur" };

export default function Legal() {
  return (
    <LegalPage title="Mentions légales">
      <p>
        <strong>Éditeur.</strong> Passeport Créateur, projet porté par une association loi 1901 en cours de création.
        Coordonnées et numéro RNA publiés dès la déclaration en préfecture.
      </p>
      <p>
        <strong>Hébergement.</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, États-Unis.
      </p>
      <p>
        <strong>Statut du projet.</strong> Prototype sur le réseau de test Polygon Amoy. Le code des contrats n&apos;est
        pas audité. Le jeton utilitaire n&apos;est pas en vente, n&apos;est listé sur aucune plateforme et ne promet
        aucun rendement.
      </p>
      <p>
        <strong>Démonstrations.</strong> Les démonstrations interactives du site Passeport Créateur (accessibles sous
        /demo) sont des simulations pédagogiques. Les informations saisies par l&apos;utilisateur (pseudo
        d&apos;affichage) restent stockées localement dans son navigateur et peuvent être supprimées à tout moment via le
        bouton dédié. Aucun cookie ni aucun outil de mesure d&apos;audience n&apos;est utilisé sur ces pages.{" "}
        <a href="/demo/legal" className="underline">Notice des démos</a>.
      </p>
    </LegalPage>
  );
}
