# VeriProf — Plateforme de recrutement et de vérification des enseignants

Application mobile Flutter mettant en œuvre le cahier des charges v1.0
(Guinée). Positionnement produit : **VÉRIFIER → ÉVALUER → MATCHER → RECRUTER →
SUIVRE** — un outil professionnel de recrutement, pas une plateforme de cours.

## Ce qui est implémenté

### Parcours enseignant (§55)

| Étape | Écrans | Référence |
|---|---|---|
| Authentification | Splash, onboarding, inscription, OTP, connexion | §5.1 |
| Vérification d'identité | Selfie + pièce d'identité, contrôles de qualité | §6 |
| Diplômes | Déclaration, justificatif, statuts de vérification | §7 |
| Matières et niveaux | Sélection multiple, un test par couple | §8, §9 |
| Test de compétence | Présentation, passage chronométré, correction | §10, §12 |
| Certification | Par matière **et** niveau, avec score | §13 |
| Emploi | Offres, détail, candidature, suivi | §17, §18 |
| Recrutement | Messagerie, entretien, proposition, contrat, signature | §23–§27 |

### Espace établissement (§56)

Tableau de bord, recherche multicritère d'enseignants, filtres avancés,
consultation de profil, publication d'offres publiques **et privées**,
candidatures classées, espace de recrutement, suivi après recrutement.

### Éléments différenciants

- **Test hors ligne (§11).** Les questions sont téléchargées avant le
  démarrage ; le chronomètre et les réponses survivent à une coupure réseau.
  La correction locale s'affiche immédiatement, le serveur reste la source
  officielle du résultat.
- **Moteur de matching explicable (§22, §61).** Chaque critère — matière,
  niveau, compétence, expérience, localisation, disponibilité — conserve sa
  contribution et son explication. Le score n'est jamais une boîte noire.
- **Trust Score (§62).** Agrégation de six dimensions vérifiables, détaillées
  à l'écran plutôt qu'une note arbitraire.
- **Protection contre le contournement (§30).** Les coordonnées sont masquées
  dans la messagerie jusqu'à la signature du contrat, avec avertissement à
  l'auteur. Le masquage est une couche d'affichage : le texte d'origine est
  conservé et redevient lisible une fois le recrutement conclu.
- **États réseau progressifs (§42).** `NO_NETWORK` → `NETWORK_AVAILABLE` →
  `INTERNET_REACHABLE` → `SERVER_AVAILABLE`. « Wi-Fi » ne vaut jamais
  « Internet ».
- **Contrat généré (§27).** Modèle articulé, export PDF, signature manuscrite
  capturée et annexée au document.

## Architecture (§38)

```
lib/
├── core/            # constantes, réseau, sécurité, stockage, utilitaires
├── domain/
│   ├── entities/    # agrégats manipulés par l'interface
│   └── usecases/    # matching, trust score, complétion, correction, contrat
├── data/
│   ├── local/       # base Drift (30 tables) + seed embarqué
│   ├── remote/      # client des endpoints de synchronisation
│   ├── repositories/
│   └── sync/        # file d'opérations et moteur push/pull
└── presentation/
    ├── providers/   # Riverpod
    ├── router/      # go_router
    ├── screens/
    ├── theme/
    └── widgets/
```

- **État :** Riverpod (§39)
- **Base locale :** SQLite via Drift (§40)
- **Offline-first :** « Local first → Sync later » (§41)
- **Synchronisation :** file `sync_queue`, curseur, conflits signalés et non
  écrasés silencieusement (§43–§45)

## Données embarquées

Le référentiel et les jeux de démonstration sont livrés en assets pour que
l'application soit utilisable dès la première ouverture, sans connexion :

- 11 matières, 14 niveaux (scolaire et universitaire)
- **8 banques de questions, 282 questions au total** — dont le test complet
  **Mathématiques — L2 (60 questions)** réparti sur Algèbre, Analyse,
  Probabilités et Géométrie, avec explication par question
- 5 établissements, 7 offres, 8 profils enseignants

## Lancer le projet

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # code Drift
flutter test
flutter run
```

### Construire l'APK

```bash
flutter build apk --release
```

La chaîne d'outils est configurée dans `android/` :
`org.gradle.java.home` pointe sur le JDK 21 local et `local.properties` sur le
SDK Android local.

### Comptes de démonstration

L'écran de connexion propose deux accès directs, alimentés par le seed :

- **Espace enseignant** — Mamadou Diallo, identité et diplôme vérifiés,
  certifié Mathématiques L1 (91 %) et L2 (86 %)
- **Espace établissement** — Université Gamal Abdel Nasser

## Points laissés au serveur

Ces éléments relèvent du backend décrit au §47 et sont branchés côté client
derrière des interfaces, sans implémentation embarquée :

- **Reconnaissance faciale et OCR** (§6, §7) — `IdentityCheckService` définit
  le contrat ; l'implémentation locale se limite aux contrôles de qualité
  avant envoi, la décision reste serveur.
- **Envoi des SMS OTP** — le code est généré et affiché en mode dégradé pour
  ne pas interrompre le parcours hors ligne.
- **Application des changements `pull`** — le curseur et le transport sont en
  place ; la projection des entités distantes attend l'API réelle.
- **Back-office administrateur** (§57) — hors périmètre d'une application
  mobile, prévu en Web.

## Réserves à lever avant production

Conformément au cahier des charges, deux points demandent une validation
juridique préalable :

- **Signature électronique** (§27) — sa valeur doit être appréciée au regard
  du cadre applicable en Guinée avant d'être présentée comme opposable.
- **Traitement des données personnelles** (§52) — selfie, pièce d'identité et
  diplômes appellent une analyse spécifique. Le code applique déjà la
  minimisation, le consentement explicite à l'inscription, le chiffrement du
  stockage local et l'exclusion des données d'identité des journaux (§51).

L'option **Visibilité+** (§35) est implémentée comme service de visibilité,
distinct de l'accès aux offres, du recrutement et de la certification — la
certification n'est jamais vendue.
