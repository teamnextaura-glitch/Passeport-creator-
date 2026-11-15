# Site Passeport Créateur

Next.js 14 (App Router), TypeScript, Tailwind CSS, Framer Motion.

```
cd site
npm install
npm run dev      # http://localhost:3000
npm run build    # lance d'abord scripts/check-demo.mjs
```

Sur Vercel, le projet est configuré avec **Root Directory = `site`**.

## Pages

| Route | Contenu |
| --- | --- |
| `/` | Hero, le problème, la carte Passeport, comment ça marche, appel vers les démos, pied de page |
| `/demo` | Index des 5 démos |
| `/demo/simulator`, `/demo/result` | Simulateur et page cible du QR code (résultat dans le fragment `#`) |
| `/demo/timeline` | Évolution sur 12 mois |
| `/demo/contest` | Mini-jeu de contestation |
| `/demo/verifier` | Fiche de réputation fictive |
| `/demo/wall` | Mur de 48 Passeports fictifs (`data/wall.json`) |
| `/demo/legal`, `/legal`, `/privacy`, `/inscription` | Notices |

## Écarts par rapport au document de conception

- **Pas de Spline ni de GSAP.** Le Hero utilise un fond 100 % CSS (halo pulsé + grille de points qui dérive). Le mur est une grille, pas une galerie 3D. Les scènes Spline restent à créer, puis à servir depuis `/public`.
- **Polices provisoires.** Space Grotesk (titres) et Inter (texte), via `next/font/google` : téléchargées au build, servies par le site, aucune requête tierce côté visiteur. Pour passer à Clash Display et Satoshi, déposer les fichiers dans `public/fonts` et remplacer par `next/font/local` en gardant les variables `--font-clash` et `--font-satoshi`.
- **Compteurs du Hero** affichés en « — » tant que les contrats ne sont pas déployés.
- **Mur** : uniquement des Passeports fictifs ; la lecture d'Amoy au build viendra après le déploiement.

## RGPD des démos

`scripts/check-demo.mjs` fait échouer le build si un fichier sous `app/demo` importe Supabase, appelle `fetch`, écrit un cookie ou charge un outil de mesure d'audience. Le reste de la checklist (onglet Network vide, test en navigation privée) se vérifie à la main sur chaque prévisualisation.

## Variables d'environnement (facultatives)

`NEXT_PUBLIC_X_URL`, `NEXT_PUBLIC_DISCORD_URL`, `NEXT_PUBLIC_GITHUB_URL`, `NEXT_PUBLIC_TELEGRAM_URL`, `NEXT_PUBLIC_FARCASTER_URL`, `NEXT_PUBLIC_LINKEDIN_URL`, `NEXT_PUBLIC_YOUTUBE_URL`, `NEXT_PUBLIC_INSTAGRAM_URL`, `NEXT_PUBLIC_TIKTOK_URL`, `NEXT_PUBLIC_*_ADDRESS`, `NEXT_PUBLIC_EXPLORER_URL`. Un lien vide n'est pas affiché.
