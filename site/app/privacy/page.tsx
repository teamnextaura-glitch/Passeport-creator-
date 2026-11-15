import { LegalPage } from "@/components/legal-page";

export const metadata = { title: "Confidentialité — Passeport Créateur" };

export default function Privacy() {
  return (
    <LegalPage title="Politique de confidentialité">
      <p>
        <strong>Ce que nous ne collectons pas.</strong> Le site ne dépose aucun cookie, n&apos;utilise aucun outil de
        mesure d&apos;audience et ne charge aucune ressource tierce. Les démos stockent vos saisies uniquement dans votre
        navigateur.
      </p>
      <p>
        <strong>Journaux techniques.</strong> Notre hébergeur, Vercel, traite l&apos;adresse IP et les en-têtes de chaque
        requête pour servir les pages et protéger le service. Nous n&apos;utilisons pas ces journaux à d&apos;autres fins.
      </p>
      <p>
        <strong>Comptes réels (à venir).</strong> Lorsque les candidatures ouvriront, une politique complète précisera les
        données traitées (wallet, pseudo, dossier de preuves), leur base légale, leur durée de conservation et vos droits,
        dont l&apos;effacement des données hors-chaîne. Les informations inscrites sur la blockchain ne peuvent pas être
        effacées : vous en serez averti avant toute candidature.
      </p>
      <p>
        <strong>Contact.</strong> Adresse de contact publiée avec la déclaration de l&apos;association.
      </p>
    </LegalPage>
  );
}
