# Passeport Créateur

Standard ouvert de réputation pour créateurs, sur Polygon.
**Code non audité. Testnet uniquement avant relecture communautaire. Aucun rendement financier n'est promis.**

## Architecture
- `PasseportSBT` : ERC-721 non transférable, niveau 1 à 5, statut actif / contesté / révoqué
- `PasseportToken` (PCT) : ERC-20, supply fixe 1 000 000 000, transferts restreints en Phase 1
- `FounderVesting` : 250 000 000 PCT, cliff 12 mois + linéaire 36 mois, irrévocable
- `Certification` : jury VRF, commit-reveal, mint au niveau médian, dotation d'accueil
- `Contestation` : stake, jury VRF, commit-reveal, slashing, burn 10 %
- `PassportRegistry` : état public et historique, event `Recorded`
- Gouvernance : Snapshot, Safe + Zodiac, TimelockController 48 h

## Réseaux
| Réseau | chainId | Usage | Coût |
| --- | --- | --- | --- |
| Polygon Amoy | 80002 | Prototype | 0 € (faucet) |
| Polygon PoS | 137 | Production | Financé par les dons |

## Adresses Amoy
| Contrat | Adresse |
| --- | --- |
| PasseportSBT | `0x...` |
| PasseportToken | `0x...` |
| FounderVesting | `0x...` |
| PassportRegistry | `0x...` |
| Contestation | `0x...` |
| Certification | `0x...` |
| TimelockController | `0x...` |
| Safe DAO | `0x...` |

Adresse fondateur : `0x723DFb2A1dd6a8f4b5Dd2a499A0B870f13A60477`.
Elle reçoit le vesting. Elle ne détient aucun rôle sur aucun contrat.

## Ordre de déploiement
1. Créer le Safe DAO, le Safe du conseil et l'abonnement VRF
2. `forge script script/Deploy.s.sol:Deploy --broadcast --verify`
3. `forge script script/DeployCertification.s.sol:DeployCertification --broadcast --verify`
4. Ajouter `Contestation` et `Certification` comme consommateurs VRF ; le Safe DAO appelle `Certification.fund()`
5. Cohorte genèse : mint des Passeports de la Phase 0, liste publiée
6. `forge script script/Deploy.s.sol:Handover --broadcast`
7. Vote : le Timelock exécute `acceptOwnership()` sur les consommateurs VRF
8. Vérifier que le déployeur n'a plus aucun rôle

## Contrats : installation et tests
```
cd contracts
npm run setup
forge test -vvv
```

## Test manuel sur Amoy
1. Mint d'un Passeport de test, puis tentative de transfert : doit échouer
2. Huit comptes rejoignent le pool de juges avec 200 PCT
3. Un neuvième ouvre une contestation avec 500 PCT
4. Attendre le rappel VRF, vérifier les cinq jurés tirés
5. Commit, attendre 48 h, reveal, attendre 24 h, `resolve()`
6. Vérifier statut du Passeport, soldes libres, supply totale

## Site
À venir (lot 3). Les pages `/demo/*` seront statiques et n'effectueront aucun appel réseau.

## Checklist RGPD des démos (avant chaque déploiement)
- [ ] Onglet Network vide après chargement d'une page `/demo`
- [ ] Aucun cookie
- [ ] Aucun champ email, nom ou wallet
- [ ] Filigrane DÉMO sur chaque carte
- [ ] Bandeau et bouton d'effacement présents
- [ ] `/demo/legal` à jour
- [ ] Aucune ressource tierce, aucune mesure d'audience

## Limites connues
- Aucun audit
- Tickets de juges jamais retirés ; tirage échoué si le pool est inactif
- Le commit-reveal n'empêche pas l'achat de votes
- Dépendance à l'abonnement Chainlink VRF
- Un Passeport lié à une clé perdue est perdu
- Certification : récusation, plafond hebdomadaire par juré et nouveau tirage automatique non implémentés

## Liens
X @PasseportCreateur, Discord, Telegram, Farcaster, LinkedIn, YouTube, Instagram, TikTok : liens centralisés sur le site.
