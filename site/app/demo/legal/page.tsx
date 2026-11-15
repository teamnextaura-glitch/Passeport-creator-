import { LegalPage } from "@/components/legal-page";

export const metadata = { title: "Notice des démos — Passeport Créateur" };

export default function DemoLegal() {
  return (
    <LegalPage title="Notice des démonstrations">
      <p>
        Les démos du Passeport Créateur sont des simulations interactives. Ce que vous y saisissez (pseudo
        d&apos;affichage, réponses) n&apos;est ni collecté, ni transmis : ces informations sont enregistrées uniquement
        dans votre navigateur, pour vous permettre de retrouver votre simulation, et vous pouvez les supprimer à tout
        moment avec le bouton « Effacer mes données de démo ».
      </p>
      <p>
        Aucun cookie n&apos;est déposé et aucun outil de mesure d&apos;audience n&apos;est chargé sur ces pages. Les
        Passeports affichés portent la mention « DÉMO » : ils sont fictifs et n&apos;ont aucune valeur.
      </p>
      <p>
        Comme pour tout site web, notre hébergeur traite votre adresse IP le temps de vous servir la page ; voir notre{" "}
        <a href="/privacy" className="underline">politique de confidentialité</a>.
      </p>
    </LegalPage>
  );
}
