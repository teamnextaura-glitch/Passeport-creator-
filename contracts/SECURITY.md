# Sécurité des contrats

**Code non audité. Testnet uniquement avant relecture communautaire.** Ce fichier résume l'analyse automatique faite le 15/11/2026 sur la branche `main` (commit `5bb633e`). Elle ne remplace pas un audit.

## Outils

| Outil | Version | Résultat |
| --- | --- | --- |
| Foundry (`forge build`, `forge test`) | 1.9.0 | Compilation OK, 24 tests sur 24 |
| Slither | 0.11.6, solc 0.8.26 | 41 alertes sur `src/` (informationnelles et optimisations exclues) |
| `forge coverage --ir-minimum` | 1.9.0 | Tableau ci-dessous |
| Aderyn | — | Non exécuté : installation impossible dans le bac à sable (npm puis cyfrinup). À lancer en local. |

Commande Slither : `slither . --filter-paths 'node_modules|lib/|test/|script/' --exclude-informational --exclude-optimization`.

## Alertes Slither et décisions

Aucune alerte de gravité haute.

| Détecteur | Gravité | Nb | Contrat | Décision | Justification |
| --- | --- | --- | --- | --- | --- |
| divide-before-multiply | Moyenne | 1 | Contestation.resolve | Faux positif | `share = rest / winners` puis `rest -= share * winners` calcule volontairement le reste de la division, versé à la trésorerie. Aucune perte de précision. |
| incorrect-equality | Moyenne | 1 | PasseportSBT.isActive | Faux positif | Égalité stricte sur une énumération (`Status.Active`), pas sur un solde. |
| reentrancy-no-eth | Moyenne | 4 | Certification.finalize, Contestation.resolve | Risque accepté | Les appels externes vont uniquement vers des contrats du protocole (PCT `burn`, SBT `mint`, coordinateur VRF). Les deux fonctions sont `nonReentrant`, et la phase passe à Closed ou Resolved avant tout appel externe : un second appel revert. |
| uninitialized-local | Moyenne | 10 | Contestation, Certification, PasseportToken | Faux positif | Compteurs et accumulateurs locaux initialisés à zéro par Solidity, comme voulu. |
| missing-zero-check | Basse | 2 | Constructeurs de Contestation et Certification (`treasury_`) | Risque accepté | Valeur fixée au déploiement par le script, qui lit `DAO_SAFE`. À contrôler avant le mainnet ; une vérification `!= address(0)` pourra être ajoutée. |
| calls-loop | Basse | 2 | Tirage du jury (Contestation, Certification) | Risque accepté | Appels de lecture vers PasseportSBT dans la boucle de tirage, bornée à 60 tentatives. Le coût doit rester sous la limite de gas du rappel VRF : à mesurer sur Amoy. |
| reentrancy-benign | Basse | 4 | Certification, Contestation | Risque accepté | Même analyse que reentrancy-no-eth. |
| reentrancy-events | Basse | 2 | Certification, Contestation | Risque accepté | Événements émis après un appel à un contrat du protocole ; l'ordre n'a pas d'effet sur l'état. |
| timestamp | Basse | 15 | Fenêtres de commit, reveal, cooldown, bouclier | Attendu | Délais en heures ou en jours ; la marge de manipulation d'un validateur (quelques secondes) est sans effet. |

Aucune alerte ne justifiait une modification de `src/` : le code n'a pas changé lors de cette analyse.

## Couverture des tests

| Contrat | Lignes | Instructions | Branches | Fonctions |
| --- | --- | --- | --- | --- |
| Certification | 91,5 % (194/212) | 85,9 % | 50,0 % (25/50) | 78,3 % |
| Contestation | 82,7 % (124/150) | 78,3 % | 45,2 % (19/42) | 61,5 % |
| PasseportToken | 76,2 % (16/21) | 76,9 % | 33,3 % (1/3) | 50,0 % |
| PasseportSBT | 67,6 % (48/71) | 60,7 % | 41,7 % (5/12) | 68,8 % |
| FounderVesting | 66,7 % (2/3) | 66,7 % | — | 66,7 % |
| PassportRegistry | 58,8 % (20/34) | 53,1 % | 66,7 % (6/9) | 50,0 % |
| **Total** | **71,1 % (441/620)** | **66,7 %** | **46,3 % (56/121)** | **68,4 %** |

La checklist avant mainnet (§17 du document de conception) vise plus de 90 % de couverture sur Contestation et Certification. Certification l'atteint en lignes ; Contestation non (82,7 %). Les branches restent sous 50 % partout.

## Prochaines étapes

- Tests de propriétés (invariants de soldes, fuzz de `resolve()` et du vesting) : en cours.
- Lancer Aderyn en local : `cyfrinup` puis `aderyn . --src src`.
- Couvrir `cancelStuck`, `withdraw`, `leavePool`, `setLevel`, `revoke`, `pause` et `openTransfers`.
- Mesurer le gas du rappel VRF sur Amoy, plafond 2 500 000.
- Ajouter les vérifications d'adresse nulle sur `treasury_` avant le mainnet.
