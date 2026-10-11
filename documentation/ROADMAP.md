# Eduquali — Feuille de route

Purpose : ce qui reste à faire, et seulement cela.
Audience : responsable produit et développeurs.
Last updated : 11/10/2026 — Owner : équipe Eduquali.

> Ce fichier ne liste que le **non fait** ou le **partiellement fait**. Une case
> cochée se retire à la version suivante. L'historique des décisions, avec leurs
> raisons, vit dans [DECISIONS.md](DECISIONS.md). La spécification de
> l'assistant IA vit dans [AI_ASSISTANT.md](AI_ASSISTANT.md).

## Prochaines étapes — ordonnées le 11/10

Quatre des cinq points du 06/10 sont clos. Ce qui suit est classé par ce qui
**empêche quelqu'un de se servir du produit**.

### 1. Essayer l'APK 1.17.0 sur un vrai téléphone

C'est le seul maillon qu'aucun contrôle automatique ne couvre, et il le reste.
Tout ce que l'application rencontrera est vérifié — référentiel lisible,
Worker à 200, colonnes de synchronisation présentes, authentification
joignable, clés Cloudflare éprouvées — mais **personne n'a encore créé un
compte depuis l'application elle-même**.

À regarder dans cet ordre :

1. **créer un compte, se déconnecter, se reconnecter.** La reconnexion est la
   preuve que le compte existe chez Supabase et pas seulement sur le téléphone.
   Repère utile : la base compte aujourd'hui 32 profils, dont deux créés depuis
   le **site** le 06/10 (un parent, un professeur), chacun avec sa fiche de
   rôle. Un troisième doit apparaître de la même façon ;
2. **le même compte sur le site** — c'est ce que les deux `--dart-define`
   Supabase servent à rendre vrai ;
3. **publier un cours** depuis l'écran du professeur, et vérifier que les
   séances apparaissent tout de suite ;
4. **la liste des professeurs** : elle doit montrer ceux du palier de
   l'apprenant, et eux seuls.

### 2. ⚠ Aucun professeur n'enseigne le primaire

Les six années du primaire existent depuis le 11/10 (1ère à 6ème, la
numérotation guinéenne continue qui donne ensuite la 7ème au collège), et
l'étape « quelle classe » s'affiche enfin pour elles. Mais sur les 97 niveaux
déclarés en base — 9 collège, 25 lycée, 63 supérieur — **aucun n'est du
primaire**.

Un parent de 1ère année verra donc une liste vide. Le filtre fonctionne ; c'est
l'offre qui manque. À traiter au recrutement, pas dans le code.

### 3. Aucune modération sur les groupes

Ni signalement, ni suppression par un tiers, ni durée de conservation. Les
messages de groupes d'élèves mineurs restent indéfiniment. À traiter avec
l'analyse juridique du §52, et **avant** d'ouvrir les groupes plus largement.

### 4. Passer Supabase au plan payant au premier utilisateur payant

Pas avant, et pas pour la raison qu'on croit. **La mise en pause n'est pas le
problème** : le cron du Worker interroge la base chaque nuit à 2 h, donc elle
ne peut pas atteindre les 7 jours d'inactivité qui la suspendraient. C'est un
effet de bord, mais il tient.

Le vrai motif est **l'absence de sauvegardes** sur le plan gratuit. Tant qu'on
teste avec des comptes de démonstration, une base perdue coûte une après-midi
de re-semis. Dès qu'un parent a payé 45 000 GNF, elle coûte sa confiance.

⚠ Risque silencieux en attendant : si le Worker est dépublié ou si son cron
échoue sept jours de suite, la base se met en pause et l'application tombe sans
message — tous les écrans vides, aucune erreur claire.

### 5. Ce qui peut attendre

* **Les entités à valeur d'ensemble** sont corrigées pour les compétences
  (`POST /teacher/competences`, migration 0029), mais le principe reste à
  reprendre si d'autres ensembles arrivent ;
* `[env.production]` du Worker — décision commerciale (argent réel), pas
  technique ;
* `CF_STREAM_CUSTOMER_CODE` : vide jusqu'à la première vidéo ingérée. À
  remplir, puis `npm run secrets`, sinon la lecture ne saura pas sur quel
  sous-domaine pointer ;
* les clés Djomy de production, pour l'encaissement réel ;
* Vite 5 → 6, pour que l'outillage Cloudflare moderne configure le site ;
* le domaine Hostinger : changer les serveurs de noms, ajouter le domaine
  personnalisé dans Pages, **et ajouter l'origine à `ALLOWED_ORIGINS`** — sans
  quoi le site se charge et chaque appel échoue en silence ;
* les trous 4 et 6 ci-dessous : promotions de démonstration citant de vraies
  écoles, et numéros de support encore en gabarit `+224 000 00 00 00`.

### Clos depuis le 06/10

| Point | État |
|---|---|
| Parcours de création de cours en direct | ✅ `POST /live/courses` + écran mobile, séances générées immédiatement |
| Synchronisation du compte | ✅ `POST /account` — un compte créé sur téléphone n'avait aucune ligne `profiles` |
| Ensembles (matières, niveaux) | ✅ `remplacer_competences`, migration 0029 |
| Promotions invisibles | ✅ affichées aux comptes FREE, une vue par personne et par jour (0030) |
| Classes du primaire absentes | ✅ six années au référentiel et en base (22 niveaux) |
| Professeurs sans niveau montrés à tous | ✅ règle inversée : la tolérance n'avait de sens que quand l'inscription jetait les niveaux |
| Clés Cloudflare | ✅ Stream et R2 éprouvées contre les vrais services, 14 secrets sur le Worker |

## ⚠ Trous connus — à lire avant d'ajouter une fonction

Cette section existe parce qu'il manquait un endroit où regarder. Les blocs
`✅ Fait` de [strategy_implementation.md](../strategy_implementation.md) disent ce
qui marche et où le code a dévié du plan ; **ils ne disent pas ce qui est cassé.**
Un trou dont aucun document ne parle ne se trouve que par accident.

Chaque entrée dit **comment le défaut se manifeste**, parce que c'est ce qui
permet de le reconnaître — et chacun de ceux-ci est invisible dans la suite de
tests.

### 1. ~~`/sync/push` n'existe pas~~ — écrit le 03/10, partiellement couvert

**Le trou d'origine :** `frontend/mobile/lib/data/remote/sync_api.dart` envoyait
ses modifications en `POST /sync/push` et **le Worker n'avait pas cette route**.
Tout ce qu'une personne saisissait restait sur son téléphone, définitivement.

**Ce qui existe maintenant :** la route, et `backend/api/_lib/sync.ts` qui décide
ce qu'un client a le droit d'écrire. **Deux barrières, aucune ne remplace
l'autre :**

- **RLS**, parce que l'écriture passe par `asUser(jeton)` — Postgres refuse une
  ligne qui n'appartient pas à l'appelant ;
- **une liste de colonnes par entité**, parce que RLS ne regarde que la ligne. Un
  professeur **possède** sa ligne `teachers` : RLS le laisserait écrire
  `identity_status = 'VERIFIED'` sur lui-même, ou prolonger son propre
  `boosted_until`, qui se paie.

**Couverture : 11 entités écrivables, 23 refusées explicitement, 34 en tout** —
soit toutes celles que le client pousse. Un test du dépôt le vérifie en lisant le
code Flutter (`api/_lib/sync.test.ts`), donc une nouvelle entité côté mobile fait
échouer la suite tant qu'elle n'est pas traitée **ou refusée avec sa raison**.

**Ce qui reste :** les 11 écrivables sont celles dont l'appartenance est claire et
qui ne touchent pas à l'argent — enfant, fiche parent, fiche professeur, matières
et classes enseignées, disponibilités, expériences, offres de cours à domicile,
demandes de cours, candidatures, favoris. Les 23 autres sont refusées **à
dessein** (argent, décisions d'un tiers, documents vérifiés, ou route dédiée qui a
ses propres règles), chacune avec son explication.

Les deux qui mériteront peut-être une route un jour, et qui sont aujourd'hui
refusées : `message` et `conversation`. Écrire un message hors ligne puis le voir
partir à la reconnexion serait utile ; cela demande une route qui notifie, pas une
écriture générique.

> **Pas encore éprouvé contre un vrai serveur.** Le plan d'écriture est pur et
> testé (20 contrôles) ; le comportement de RLS sur un refus — `42501` traité en
> `conflict` plutôt qu'en `failed`, pour que le téléphone arrête de réessayer —
> n'a pas pu être vérifié, faute de projet Supabase. À faire en même temps que le
> point 2.

### 2. ✅ RLS — éprouvé, clé publique et cloisonnement entre comptes

**Fermé le 03/10.** `npm run check:rls` crée deux comptes réels sur le projet en
service, les connecte, donne un enfant au premier et demande au second de le
lire. Résultat : Alice lit son enfant, Bruno ne le voit pas, et son insertion
sous le `parent_id` d'Alice est refusée par `42501` — la politique, nommément.
Les tables de la migration 0020 sont couvertes : journal de points invisible aux
autres, `point_balances` confirmée en `security_invoker`, et pas d'inscription à
un concours au nom d'autrui. Le script supprime ses deux comptes en sortant.

Il écrit dans la base, donc il exige `--ecrire` à la main : un script qui écrit ne
doit pas pouvoir partir par distraction ni entrer dans une chaîne automatique.

Une table reste volontairement hors de sa portée : `point_ledger`. Son
déclencheur d'ajout seul empêche de supprimer ce qu'on y écrit, et un contrôle ne
doit pas laisser de déchet définitif dans un journal de points. Son comportement
est éprouvé par `check:db`, sur un Postgres jetable.

<details><summary>L'état précédent, pour mémoire</summary>

### 2-bis. RLS : la clé publique est éprouvée, le cloisonnement entre comptes non

**Mis à jour le 03/10.** `npm run check:supabase` interroge la base en service avec
les deux clés et compare : `test_questions` rend 282 lignes au serveur et **0** à
la clé publique. Deux chiffres différents pour une requête identique — c'est RLS
qui agit, et cette forme de preuve résiste à une table vide, contrairement à un
« 0 ligne » sur une table qui n'en contient aucune. Les écritures anonymes sur
`subjects`, `children` et `teachers` sont refusées, et `correct_key` est absent de
`test_questions_public`.

Reste ouvert, et c'est le plus délicat : **deux comptes ne sont pas cloisonnés par
la même règle qu'une clé anonyme.** Ce qui n'est pas éprouvé : un parent qui lit la
présence de l'enfant d'une autre famille, un élève qui lit le décompte d'un point
de contrôle qui n'est pas le sien, un professeur qui lit les coordonnées d'un élève
qui ne l'a pas contacté. Cela demande deux utilisateurs réels et leurs jetons,
donc un script qui écrit dans la base — séparé de `check:supabase`, qui ne lit que.

La raison de fond n'a pas changé : la clé publique voyage dans le paquet du site et
dans l'APK, donc **RLS est la seule barrière.** Une politique trop large est une
table ouverte à Internet.

</details>

**Ce qui n'est toujours pas couvert**, et mérite d'entrer dans `check:rls` quand
les données existeront : un parent qui lit la présence de l'enfant d'une autre
famille, un élève qui lit le décompte d'un point de contrôle qui n'est pas le
sien, un professeur qui lit les coordonnées d'un élève qui ne l'a pas contacté.
Les trois demandent une séance en direct et une inscription payée, donc un jeu de
données que le script devrait fabriquer puis défaire.

### 3. ✅ Le poids de l'APK après WebRTC — mesuré : 77,8 Mo

**Mesuré le 03/10**, première construction depuis l'entrée de `livekit_client` et
`flutter_webrtc`. L'estimation de 75–80 Mo était juste.

| | Taille |
|---|---|
| 1.10.0 livré, avant WebRTC | 53,5 Mo |
| **1.12.0, après WebRTC** | **77,8 Mo** |
| APK brut avant allègement | 358 Mo |

Les 280 Mo d'écart entre le brut et le livré sont des symboles de débogage que
`tools/repack_apk.py` retire : le NDK n'est pas installé, donc Gradle ne peut pas
le faire lui-même. `libjingle_peerconnection_so.so` pèse à lui seul 11,7 Mo en
arm64 et 6,5 Mo en arm, une fois allégé.

**Ce n'est pas une inconnue technique mais commerciale** : +24 Mo sur un fichier
qui se transmet par Bluetooth et par Xender, c'est la moitié de temps de
transfert en plus, à chaque téléphone.

Le levier disponible, non pris : **publier par architecture.** Les tailles
estimées depuis les chiffres mesurés ci-dessus — arm64 seul ≈ 47 Mo, armeabi-v7a
seul ≈ 40 Mo — soit un retour sous la taille d'avant WebRTC. Le coût est qu'il
faut alors savoir quel téléphone on sert, et deux fichiers circulent au lieu
d'un. À décider, pas à faire par réflexe.

L'autre levier, `isMinifyEnabled = false` dans `app/build.gradle.kts` : activer
R8 gagnerait quelques Mo, mais sur une application Flutter avec des greffons qui
utilisent la réflexion, cela casse à l'exécution et non à la compilation. À
tenter seulement avec un essai sur appareil derrière.

### 4. Des promotions de démonstration citent de vraies écoles

`shared/seed/catalog.json` attribue des offres inventées à des établissements
réels et nommés — « Dix bourses au mérite en Terminale » pour le Lycée
Excellence, des annonces pour l'Université Gamal Abdel Nasser.

Ces listes sont **publiques depuis le 02/10** : on y arrive par un lien, sans
compte. Annoncer une bourse au nom d'une université qui ne l'a jamais décidée est
un risque de réputation, et il se réalise le jour où quelqu'un de chez eux le
voit. Soit renommer vers des établissements clairement fictifs, soit ne les
servir que derrière le bandeau de démonstration.

### 5. ✅ L'APK de production est signé avec une vraie clé — fait le 04/10

**Le trou d'origine :** `release { signingConfig =
signingConfigs.getByName("debug") }`. Deux APK construits sur deux machines
différentes ne pouvaient pas se remplacer l'un l'autre à l'installation, et
rien ne prouvait qu'un APK reçu par Bluetooth venait bien de nous.

**Ce qui existe maintenant.** `android/app/build.gradle.kts` lit
`android/key.properties`, qui pointe sur un magasin de clés conservé **hors du
dépôt**. La clé de debug reste en repli, avec un avertissement à la
compilation : une machine sans le magasin construit quand même, et dit qu'elle
l'a fait autrement.

`tools/repack_apk.py` signe avec le même magasin et **annonce laquelle des deux
clés il a utilisée** — « cle de publication » ou « CLE DE DEBOGAGE » en
capitales. C'est la seule façon de s'en apercevoir : un APK mal signé
s'installe parfaitement sur un téléphone neuf, et ne se révèle qu'à la mise à
jour suivante, chez l'utilisateur.

Vérifié sur `eduquali-1.13.0.apk` (04/10) : « Signature (cle de publication) ».

⚠ **Le magasin de clés est maintenant irremplaçable.** Le perdre signifie
qu'aucune mise à jour ne pourra plus remplacer les APK déjà distribués — il
faudrait désinstaller chez chaque utilisateur. Il doit être sauvegardé ailleurs
que sur la machine de compilation.

### 6. Les numéros de support sont des gabarits

`core/constants/app_constants.dart` : `supportPhone` et `supportWhatsApp` valent
tous deux `+224 000 00 00 00`. Affichés tels quels à quelqu'un qui cherche de
l'aide.

### 7. ✅ La chaîne complète est en service — 06/10

Les trois morceaux se parlent, et chaque maillon est vérifié depuis
l'extérieur, pas supposé :

| Maillon | État | Comment c'est vérifié |
|---|---|---|
| Supabase | 28 migrations appliquées | `npm run check:supabase` → « Base en service conforme » |
| Worker | déployé, `sandbox` | `GET /api/v1/health` → 200 ; `/shop/items` sans jeton → 401 |
| Site | `https://eduquali.pages.dev` | liens profonds 200, en-têtes de sécurité servis |
| APK | 1.15.0, branché | les deux adresses présentes dans le binaire |

**`ALLOWED_ORIGINS` n'est plus vide** : `https://eduquali.pages.dev` est
autorisée dans l'environnement par défaut — celui qui est réellement déployé.
Vérifié : cette origine reçoit son en-tête, `evil.example.com` n'en reçoit
aucun.

⚠ **Le bloc `[env.production]` n'a jamais été déployé, et c'est volontaire.**
Il porte `DJOMY_ENVIRONMENT = "production"`, c'est-à-dire de l'argent réel.
Déployer avec `--env production` est une décision commerciale, pas une étape
technique. Tant qu'elle n'est pas prise, utiliser `npx wrangler deploy` sans
`--env`.

⚠ **Restent absentes de `backend/.env`** : `R2_*`, `CF_*` et les clés Djomy de
production. Sans elles les rediffusions et l'encaissement réel se taisent
proprement — ils ne fonctionnent pas, mais ne cassent rien.

Les capacités, les paliers payants et le moment d'y passer sont dans
[../eduquali_services_externes.txt](../eduquali_services_externes.txt).

### 8. ✅ Le parcours d'inscription jetait la moitié de ce qu'il demande — corrigé le 04/10

**Relevé le 04/10**, en comparant chaque `fieldId` des quatre parcours
(`assets/onboarding/*.json`) aux clés réellement lues par
`SignupCompletion` — le seul endroit où une réponse devient un compte.

| Parcours | Réponses exploitées | Jetées |
|---|---|---|
| professeur | 7 / 15 | `service_types`, `cycles`, `level_ids`, `subject_ids`, `mobility`, `availability`, `home_availability`, `subscription` |
| établissement | 8 / 17 | `manager_role`, `priorities`, `teacher_location`, `work_days`, `work_start`, `work_end`, `work_days_custom`, `max_distance`, `subscription` |
| parent | 13 / 15 | `momo_phone`, `subscription` |
| universitaire | 12 / 14 | `momo_phone`, `subscription` |

**Comment le défaut se manifeste.** Un professeur remplit sept écrans — ce
qu'il enseigne, à quels niveaux, quels jours, s'il se déplace — puis arrive sur
un compte qui n'en sait rien. Sa fiche s'affiche sans aucune matière dans la
liste des familles (`capabilities` vide → `join(' · ')` rend une chaîne vide),
et le filtre par palier laisse passer qui n'a déclaré aucun cycle
(`cycle_match.dart` : `cycles.isEmpty ||`), donc il est proposé à un CE2 comme à
un étudiant. Pour exister vraiment, il doit **ressaisir les mêmes faits** dans
`/teacher/subjects`, `/teacher/levels`, puis une troisième fois dans le
formulaire d'offre (`TutoringServices` porte ses propres `subjectId`,
`levelIds`, `city`, `districts`, `availabilityNote`).

**Pourquoi la suite de tests ne le voit pas.** `signup_end_to_end_test.dart`
vérifie « l'apprenant déclaré porte son niveau et ses matières » — le chemin
parent/universitaire, qui lui fonctionne. Rien n'examine le chemin professeur
ni le chemin établissement.

**Les destinations existent déjà** pour le professeur : les tables
`TeacherSubjects` et `TeacherLevels`, et les colonnes
`teachers.preferredContractTypes`. C'est donc un défaut de branchement, pas de
schéma. Deux colonnes sont même **mortes** : `teachers.tutoringDays` et
`tutoringSlots` ne sont écrites par aucun code (seule la migration les crée) et
lues par aucun — l'écran `/teacher/availability` écrit `availability` et
`preferredInstitutionTypes`, pas elles.

Pour l'établissement en revanche, **aucune colonne n'accueille** ses critères
de recrutement : ni `manager_role`, ni les matières cherchées, ni les jours,
ni la distance. `Institutions` n'en a pas. Conséquence : à chaque offre
publiée, `publish_job_screen.dart` redemande la matière, les niveaux **et la
ville** — `_city` part à `null` alors que `institutions.city` est obligatoire
et déjà remplie.

### 9. ✅ La formule choisie à l'inscription n'était jamais retenue — corrigé le 04/10

La dernière étape des quatre parcours est un `plan_select` qui range sa réponse
sous `subscription`. **La chaîne `'subscription'` n'apparaît nulle part dans
`lib/`.** `auth_repository.subscribe()` n'est appelée que depuis
`billing/subscription_sheet.dart`.

Quelqu'un choisit donc PRO au dernier écran de son inscription, obtient un
compte `FREE`, et doit rechoisir la même formule depuis la facturation. C'est à
la fois la question posée deux fois et une recette qui ne rentre pas.

### 10. ✅ Le numéro Orange Money était demandé, puis jeté — l'étape est retirée le 04/10

L'étape `payment` des parcours parent et universitaire demande `momo_phone`
avec, écrit dans son propre libellé : « Le même que votre numéro de compte, en
général. » Le parcours **sait** que c'est le numéro déjà saisi deux écrans plus
tôt, le redemande sans le préremplir — le modèle d'étape n'a aucune notion de
prérempli — et `momo_phone` n'apparaît ensuite nulle part dans le code. Une
table `PaymentMethods` existe et ne reçoit rien.

### 11. ✅ Le tableau de bord ignorait le quartier qu'on venait de lui donner — corrigé le 04/10

L'étape qui collecte région / commune / quartier annonce : « Le quartier décide
des professeurs qui peuvent venir. »

Or `parent_dashboard.dart` appelle `bookableTeachersProvider(null)` et
`institution_dashboard.dart` `availableTeachersProvider(null)`. Le carrousel
« Professeurs disponibles » de l'accueil liste donc toute la Guinée. L'écran de
recherche, à un geste de là, fait pourtant les choses correctement
(`parent_shell.dart` : `bookableTeachersProvider(parent.city)`). Deux listes,
deux règles, et c'est celle de l'accueil qui contredit la promesse du parcours.

### 12. ✅ Rien ne se personnalisait avec le niveau et les matières déclarés — corrigé le 04/10

| Ce qui est déclaré | Ce qui pourrait s'en servir | Ce qui s'en sert |
|---|---|---|
| niveau et matières de l'apprenant | le catalogue vidéo (`VideoCourses` a `subjectId` et `levelIds`) | rien : `published()` ne filtre que `status = 'PUBLISHED'` |
| niveau de l'apprenant | la grille des cours en direct | rien |
| matières et niveaux du professeur | les offres d'emploi | **tout, et c'est pire que rien** — voir ci-dessous |
| matières cherchées par l'établissement | sa liste de professeurs | rien |

Les deux côtés de chaque jointure existent en base. Seul le filtre par palier
des professeurs (`cycle_match.dart`) est réellement branché.

**Correction du 04/10, après une première lecture fautive.** Les offres
d'emploi *sont* rapprochées du professeur : `job_repository.opportunities()`
appelle `offersInSubjects` puis trie par `MatchingEngine.score`. La première
version de cette entrée disait le contraire — la lecture s'était arrêtée au
`ORDER BY j.published_at DESC` de la requête SQL, sans voir le traitement Dart
juste en dessous.

La conséquence réelle est plus grave que ce qui était écrit. `offersInSubjects`
rend **`const []`** quand le professeur n'a déclaré aucune matière :

> « Sans matière déclarée, aucune offre n'est pertinente : l'écran invite
> alors à ajouter ses matières plutôt que de tout montrer. »

Comme l'inscription jetait `subject_ids` (trou 8), tout professeur
fraîchement inscrit avait zéro compétence — donc un onglet « Offres »
**entièrement vide**, avec un message lui demandant d'aller saisir les
matières qu'il venait de saisir. Le moteur de rapprochement était construit et
correct ; il était simplement privé de ses entrées.

C'est le cas qui résume le mieux ce trou : un défaut de branchement à
l'inscription désactivait en silence un sous-système entier.

Conséquence à l'accueil : un universitaire qui vient de déclarer sa classe et
cinq matières voit trois sections vides — « Mes cours », « Mes professeurs »,
« Mes favoris » — et un catalogue identique à celui d'un élève de CE2.

### 13. ✅ Incohérences relevées au passage — corrigées le 04/10

- **Le site nomme l'établissement d'après son directeur.** `App.tsx` envoie
  `firstName: text('manager_name')` pour un compte établissement, et
  `supabase.ts` fait `institutions.insert({ name: input.firstName })`. Le
  mobile, lui, lit `institution_name`.
- **Le site persiste encore moins que le mobile** : `register()` ne prend que
  téléphone, mot de passe, rôle, prénom, nom et ville. Ni région, ni quartier,
  et **aucun enfant** n'est créé pour un compte parent — le commentaire
  l'assume (« Les reponses alimenteront le profil des que l'API existera »).
  Même questionnaire, deux niveaux d'enregistrement selon la porte d'entrée.
- **`institution_type` est lu sans être demandé.** `SignupCompletion`
  interroge `answers['institution_type']` ; aucune étape ne pose la question.
  Tout établissement est donc créé `SCHOOL`, université comprise.
- **La complétude du profil professeur annonce une disponibilité qu'elle ne
  vérifie pas** : `teacher_repository.dart` passe `hasAvailability: true` en
  dur à `ProfileCompletionCalculator`.
- **Le commentaire de `Signup.tsx` ne liste que trois parcours** sur quatre ;
  `AUDIENCE_BY_ROLE` en couvre bien quatre. Documentation seulement.

## Phase D — points et classement : ce qui est fait, ce qui ne l'est pas

**03/10.** Les deux morceaux que la fidélité exige d'abord sont construits ;
les quatre qui s'appuient dessus ne le sont pas. Écrit ici parce qu'un « système
de points » à moitié livré se croit fini.

**Fait**

* **D1 — le grand livre.** `point_ledger`, en ajout seul et pour de vrai : un
  déclencheur refuse `update` et `delete`, y compris à la clé de service, qui
  contourne les politiques. Une erreur se corrige par une écriture inverse. Le
  solde est la vue `point_balances`, jamais une colonne — un solde stocké se
  désynchronise et plus personne ne sait d'où vient le chiffre.
* **D4 — concours et classement.** `contests`, `contest_entries` (une
  participation par compte), et le rang calculé à la lecture. Le podium reste
  **fermé sous dix copies rendues** : un classement national à quatre
  participants n'est pas une approximation, c'est une affirmation fausse sur le
  pays. Le rang personnel, lui, s'affiche toujours.
* L'écran `/concours` dans le mobile, deux onglets, atteignable depuis l'accueil.

**Écart avec le plan** — D4 disait de réutiliser `test_sessions`. Impossible :
`test_sessions.teacher_id` référence `teachers`, c'est le test de compétence d'un
enseignant. Un concours d'élèves a donc sa propre table.

* **D2 — la boutique.** `shop_items`, `redemptions` et `redeem_shop_item()`,
  atomique : solde, stock et journal dans une seule instruction, comme
  `claim_session_seat`. Quatre lots au référentiel, prix en points **et**
  équivalent en francs, avec la distance au lot suivant. Écran `/boutique`.

**Pas fait** — D5 les cosmétiques, D6 les codes QR.

**D3 le partage de points — la règle existe, l'écran non.** `offrir_points`
(migration 0025) transfère des points d'un compte à un autre, **plafonné à 2
par jour**, les deux écritures dans la même instruction. Le plan prévoyait 10 :
une séance suivie rapporte 18, donc à 10 par jour quatre comptes complices
vident leur solde vers un seul en quelques jours, et la boutique récompense qui
a le plus d'amis. Aucun bouton ne l'appelle encore : la fonction est donc
inerte en production.

⚠ **Ambiguïté non tranchée.** « Réduire les points qu'on peut offrir à
quelqu'un » a été lu comme ce transfert entre élèves. Cela peut aussi désigner
un professeur qui récompense un élève — ce qui serait une fonction différente,
avec un plafond différent, puisqu'un professeur n'a pas de solde à dépenser. À
confirmer avant de poser le bouton.

### Gagner des points — fait le 04/10

La seule source était le concours hebdomadaire ; un élève qui n'en faisait pas
n'aurait jamais tenu un point. Migration 0023, en **déclencheurs Postgres** et
non en code serveur : la présence est écrite par les webhooks LiveKit, le vote
d'un point de contrôle est écrit par le téléphone lui-même sous RLS. Une règle
dans le Worker n'aurait couvert que la moitié des cas.

| Source | Gain |
|---|---|
| Création du compte | 100 |
| Séance suivie | 1 point par tranche de 5 minutes — 18 pour 90 minutes |
| Réponse à un point de contrôle | 2, quelle que soit la réponse |
| Concours | 100 au premier, 5 pour une copie rendue |

**Rien n'est déclaré par le client.** Les minutes viennent du serveur de
visioconférence, le vote exige une place payée et un module encore ouvert. On ne
peut donc pas récolter des points en cliquant — ce qui est le reproche fait aux
plateformes où l'XP récompense le fait d'avoir appuyé sur « continuer ».

Chaque gain porte une `reference` qui décrit l'événement exact, et
`crediter_points` refuse d'écrire deux fois sur la même : un webhook rejoué par
LiveKit ne double pas les points. Éprouvé par `check:db`.

Les cent points de bienvenue **ne suffisent à rien acheter** — le plus petit lot
en coûte 250 — et un invariant le vérifie. Sinon créer des comptes deviendrait
une façon de récolter des forfaits internet.

### ⚠ Les quatre téléphones restent hors d'atteinte

Deux lots accessibles ont été ajoutés : un forfait internet 1 Go (250 points) et
un mois d'abonnement offert (400). Pour quelqu'un qui suit une séance par
semaine — 26 points — le premier arrive vers la sixième semaine, le second vers
le troisième mois. La monnaie a enfin un sens.

Les quatre objets de valeur, eux, ne l'ont toujours pas :

| Lot | Prix | Séances à suivre |
|---|---|---|
| Samsung Galaxy A5 | 4 500 | ~170 |
| iPhone 15 | 30 000 | ~1 150 |
| iPhone 17 | 48 000 | ~1 850 |

**Et les baisser ne réglerait rien** : à un taux soutenable, un téléphone à
8 000 000 GNF ne s'achète pas avec la fidélité d'un seul élève. L'arithmétique ne
dépend pas du barème, elle dépend du fait qu'un élève ne rapporte pas huit
millions.

La sortie est le **tirage au sort**, décidé et écrit le 04/10 (migration
0024) : les points achètent des chances, pas l'objet. Cent élèves à 26 points
par semaine produisent assez d'entrées pour qu'un Galaxy A5 par mois soit
finançable, là où le vendre à un seul ne l'est jamais.

`shop_items.kind` vaut `DIRECT` ou `RAFFLE`. Un `RAFFLE` **ne décrémente pas le
stock** et accepte plusieurs participations du même compte — c'est précisément
ce qu'achète la mise. `draw_raffle(item)` solde *toutes* les entrées en une
instruction : une gagnante, les autres marquées perdantes, pour qu'aucune ne
reste en attente indéfiniment.

⚠ **Reste ouvert : la qualification juridique.** Les points s'obtiennent en
suivant des cours et ne s'achètent pas — il n'y a donc pas de mise en argent.
Reste à vérifier que le droit guinéen l'analyse ainsi avant d'annoncer un
tirage publiquement. Le §52 du cahier des charges demande déjà une analyse
juridique ; ce point s'y ajoute.

### 14. Ce qui a été corrigé le 04/10, et ce qu'il reste

**Corrigé.**

| Trou | Ce qui a été fait |
|---|---|
| 8 — réponses jetées | `SignupCompletion.attachTeacherProfile` et `attachInstitutionNeeds`, migration locale v24 et serveur `0026`. Le professeur garde ses matières, ses niveaux, ce qu'il cherche, sa mobilité et ses créneaux ; l'établissement garde ses critères |
| 9 — la formule | `profiles.pending_plan` / `users.pendingPlan` : le choix est retenu sans être accordé, parce que rien n'est encaissé à l'inscription |
| 10 — le numéro de paiement | l'étape `payment` est retirée des deux parcours. Le serveur prend déjà le numéro du compte comme payeur par défaut et accepte un autre numéro au moment de payer |
| 11 — le quartier | les deux accueils passent la ville réelle, comme l'écran de recherche le faisait déjà |
| 12 — la personnalisation | `course_relevance.dart` + section « Pour votre niveau » / « Pour sa classe », et le catalogue arrive classé. Les offres d'emploi étaient déjà rapprochées : elles sont désormais **alimentées** |
| 13 — incohérences | le site nomme l'établissement d'après `institution_name`, persiste région et quartier, **crée l'apprenant** ; `institution_type` est demandé ; la complétude ne coche plus la disponibilité en dur |

**Ce que les tests garantissent maintenant.** `signup_end_to_end_test.dart`
couvre enfin le chemin professeur et le chemin établissement — c'est leur
absence qui avait laissé passer le trou 8. `course_relevance_test.dart` tient
les règles de classement. `api/_lib/sync-columns.test.ts` compare chaque
colonne de `WRITABLE` au schéma réel.

### 15. ⚠ La synchronisation sortante était cassée sur presque toutes les entités

**Trouvé en écrivant le contrôle du trou 8**, et c'est le défaut le plus large
de cet audit.

`planWrite` ne retient d'une charge utile que les clés qui portent le **nom
exact** d'une colonne autorisée, et refuse celle dont il ne reste rien. Or les
dépôts Dart envoyaient des clés en `camelCase` : `teacherId`, `coverNote`,
`preferredStart`, `preferredInstitutionTypes`… Aucune ne correspondait. Pire,
`WRITABLE` nommait des colonnes **inexistantes** :

| Entité | Ce qui était déclaré | La réalité |
|---|---|---|
| `favourite` | `user_id`, `entity_type`, `entity_id` | la table porte `owner_id` et `teacher_id` |
| `tutoring_request` | `teacher_id`, `subject_id`, `level_id`, `mode`, `preferred_days` | une demande vise une **offre** (`service_id`), qui porte déjà le professeur et la matière |
| `application` | `note` | la colonne est `cover_note` |
| `teacher_tutoring_availability` | toute l'entité | **aucune migration n'a jamais créé cette table** |

S'y ajoutent les envois de `teacher_repository` :
`setPreferredInstitutionTypes` poussait `preferredInstitutionTypes`, et
`setAvailability` `availableFrom` et `yearsExperience`. Le premier était refusé
entièrement ; le second passait **amputé**, parce que la seule clé reconnue,
`availability`, suffisait à sauver la charge.

Conséquence : mettre un professeur en favori, envoyer une demande de cours,
candidater, enregistrer ses disponibilités, ses types d'établissement, son
ancienneté — rien ou presque ne quittait le téléphone. En local tout
fonctionnait, donc rien ne se voyait.

**Corrigé** pour ces quatre entités, des deux côtés, et `sync-columns.test.ts`
interdit désormais de nommer une colonne qui n'existe pas.

**⚠ Reste ouvert : les entités à valeur d'ensemble.** `teacher_subjects` et
`teacher_levels` sont poussées avec `{subjectIds: [...]}` et
`{subjectId, levelIds: [...]}`, alors que le serveur attend **une ligne par
couple**. Le contrôle des colonnes ne le voit pas — il vérifie des noms, pas
des formes — et ces deux envois échouent encore. Les compétences d'un
professeur restent donc locales à son téléphone, même maintenant qu'elles sont
enregistrées à l'inscription. C'est le prochain morceau à écrire, et il demande
de décider comment une collection se pousse : une ligne par envoi, ou un
remplacement en bloc assumé par le serveur.

**⚠ `check:schema` ne compare que les noms de tables.** C'est pour cela que
`teachers.region`, `teachers.district`, `children.last_name` et
`children.subject_ids` manquaient côté serveur sans que rien ne le signale. La
migration 0026 les ajoute ; le contrôle, lui, reste à étendre aux colonnes.

### 16. ✅ L'APK n'était branché à aucun serveur — corrigé le 06/10

**Le trou :** `AppConstants.apiBaseUrl` vaut
`String.fromEnvironment('ACALIA_API')`, **vide par défaut**, comme
`SUPABASE_URL` et `SUPABASE_ANON_KEY`. Les APK 1.13.0 et 1.14.0 ont été
construits avec un simple `flutter build apk --release`, donc **sans aucune de
ces trois valeurs**. Ils ont été livrés et annoncés comme la version courante.

**Pourquoi personne ne l'a vu.** Il n'y a aucun symptôme. L'application
s'ouvre, les écrans se remplissent avec le référentiel semé localement, et
seuls les comptes partagés, les groupes et les cours en direct manquent — ce
qu'on met naturellement sur le compte d'une base vide. Mesuré en cherchant les
adresses dans le binaire :

| | adresse du Worker | adresse Supabase |
|---|---|---|
| 1.14.0 | absente | absente |
| 1.15.0 | présente | présente |

**La correction est un script, pas une consigne.** `tools/build_release.py`
lit `backend/.env`, **refuse de construire** si les valeurs manquent, écarte
toute valeur qui ressemble à une clé `service_role`, Gemini ou Djomy, et
enchaîne l'allègement. Une consigne dans un fichier se réoublie ; un script qui
refuse, non.

**À faire désormais :** `python tools/build_release.py`, jamais
`flutter build apk` directement.

### 17. ⚠ Ce que la série du 06/10 dit de la méthode

Trois défauts le même jour, et aucun n'était un bogue de logique :

1. une politique RLS qui se fermait sur elle-même — **zéro ligne, aucune
   erreur** ;
2. une inscription qui écrivait des colonnes pas encore migrées — **arrêt
   silencieux après la dernière question** ;
3. un APK sans ses valeurs de compilation — **aucun symptôme**.

Les trois partagent la même forme : **l'échec ne se signale pas, il ressemble
à un état normal.** Une base vide, un formulaire qui ne réagit pas, une
application locale.

C'est la classe de défaut que ce dépôt attrape le moins bien, et les deux
contrôles ajoutés le 06/10 visent exactement ça : la section E de
`check:supabase` (une permission fonctionne-t-elle ?) et le refus de
`build_release.py` (les valeurs sont-elles là ?). À continuer : pour chaque
nouveau réglage qui peut être absent, se demander ce qui le dirait — et si la
réponse est « rien », écrire le contrôle avant la fonction.

## Les discussions de groupe — écrites le 04/10

**Fait.** Un onglet de discussions dans les quatre profils, en forme de
messagerie moderne : liste des groupes et des fils privés au même endroit, puis
des lignes avec avatar, nom, heure et texte — pas des bulles. Les messages
consécutifs d'un même auteur se regroupent ; le professeur est en ambre avec
une puce « PROF », comme dans le fil d'une séance en direct.

Un groupe par cours en direct, ouvert automatiquement à la première place
payée. **L'appartenance est dérivée** (`est_membre_groupe`, migration 0027) et
jamais stockée : une place annulée referme la porte d'elle-même. Rien à créer,
rien à rejoindre — la décision est dans
[DECISIONS.md](DECISIONS.md), avec les raisons de refuser les groupes ouverts.

**⚠ L'établissement n'avait aucune messagerie accessible.** Sa tuile « Mes
messages » poussait `Routes.institutionMessages` depuis le 02/10, la constante
existait avec sa justification écrite, et **aucune route ne la déclarait** : il
pouvait écrire à un professeur et tombait sur l'écran d'erreur de go_router en
cherchant la réponse. `MessagesPage` et `conversationsProvider` le servaient
pourtant déjà tous les deux. Corrigé, et `chat_groups_test.dart` vérifie
maintenant que les quatre profils ont bien leur porte.

**⚠ Les groupes de contrat ne peuvent pas exister.** Le schéma et la règle
d'appartenance les gèrent (`kind = 'CONTRACT'`), mais rien ne les crée, parce
que **`work_contracts` n'est jamais écrite côté serveur** : le mobile crée les
contrats en local et l'entité `contract` est dans `REFUSED` (« un contrat
engage deux parties : il se signe, il ne se pousse pas »). La route de
signature n'existe pas encore. Tant qu'elle manque, seuls les groupes de cours
s'ouvrent.

**Pas fait — et c'est la décision à prendre avant d'ouvrir plus largement :**

* **aucune modération.** Ni signalement, ni suppression par un tiers, ni purge.
  Les messages ne s'éditent ni ne se suppriment, à dessein : laisser réécrire
  après coup rendrait un signalement futur inexploitable. Mais il n'y a
  personne pour lire un signalement qui n'existe pas.
* **aucune durée de conservation.** Les messages d'un groupe restent
  indéfiniment, y compris ceux d'élèves mineurs dont le cours est terminé. Le
  §52 du cahier des charges demande déjà une analyse juridique guinéenne sur
  les données personnelles ; ce point s'y ajoute, et c'est le plus pressant des
  deux.
* **pas de temps réel.** La discussion se relit toutes les dix secondes tant
  que l'écran est ouvert. Une connexion maintenue coûterait de la batterie et
  tomberait sur un réseau guinéen ; un envoi, lui, part tout de suite.
* **pas de notification.** Un message reçu ne prévient pas. La cloche existe
  (`notifications`) et pourrait servir.

## Le direct côté professeur — écrit le 04/10

**Fait.** Un grand bouton sur l'accueil du professeur, rouge et pulsant quand
la salle est ouverte, bleu sinon, et dont le sous-titre dit laquelle des trois
situations est vraie : séance ouvrable, séance plus tard, aucune séance. Il mène
à un seul écran (`/direct/animer`) qui porte le reste — c'est délibéré : trois
boutons obligeraient à choisir avant de savoir.

Derrière : qui est attendu, qui est entré et depuis combien de minutes
(`/live/sessions/:id/roster`, rafraîchi toutes les 20 s), un bouton *Prévenir*
par ligne et un *Prévenir tout le monde* (`/live/sessions/:id/notify`), et le
répertoire dérivé (`/live/teacher/contacts`). Les deux décisions structurantes
— répertoire non stocké, aucun SMS — sont dans
[DECISIONS.md](DECISIONS.md#2026-10-04).

**⚠ Il n'existe aucun parcours de création de cours en direct.** Ni sur le
téléphone, ni sur le site. Et rien ne les semait non plus : aucun fichier de
semis ne créait de cours en direct, donc la grille était vide, l'écran du
professeur disait d'attendre, et les groupes de discussion n'avaient rien à
montrer — trois fonctions construites, aucune vérifiable.

`supabase/seed_demo_live.sql` comble ce dernier point (04/10) : un cours
publié, deux séances — dont une dans l'heure, pour que le bouton
« Démarrer » s'allume —, une place payée et le groupe avec deux messages.
Rejouable, et éprouvé sur un vrai Postgres. À appliquer après
`seed-demo-accounts.mjs`, qui crée les comptes auxquels il se rattache.

Cela ne remplace pas le parcours de création : un professeur ne peut toujours
pas publier son propre cours.
Un professeur sans séance voit donc un écran qui lui dit d'attendre qu'un cours
soit publié, sans pouvoir le publier lui-même. C'est le prochain trou à
combler sur cette fonction : tout le reste du direct est prêt à l'accueillir.

**Pas fait** — l'aperçu vidéo de 30 s dans les cartes « En direct ». Les cartes
ne diffusent rien : le flux *est* le produit vendu, et le jeton LiveKit exige
une place payée `CONFIRMED`. Un aperçu public demanderait un jeton restreint
distinct, à décider.

## ✅ Migrations appliquées — 06/10

Toute la chaîne 0001 → 0028 est sur le projet en service, vérifiée objet par
objet par `npm run check:supabase` : **« Base en service conforme »**, zéro
échec.

Les dernières appliquées, et ce qu'elles ont débloqué :

| Fichier | Ce qu'il a débloqué |
|---|---|
| `0023` → `0025` | gagner des points, le tirage au sort, offrir 2 points par jour |
| `0026_onboarding_answers.sql` | les 20 colonnes qui manquaient — sans elles l'inscription du site s'arrêtait après la dernière question |
| `0027_chat_groups.sql` | les groupes de discussion et `est_membre_groupe()` |
| `0028_public_teacher_read_fix.sql` | les 30 fiches de professeurs, enfin visibles |

Reste optionnel : `seed_demo_live.sql`, pour un cours en direct et un groupe
visibles (il n'existe toujours aucun parcours de création de cours en direct).

### Ce que 0028 a appris sur les contrôles

La politique de 0009 rendait **zéro** fiche de professeur à la clé publique,
alors que trente existaient et qu'aucun compte n'était suspendu. Elle vérifiait
le compte avec `exists (select 1 from profiles ...)` en ligne, et une
sous-requête dans une politique subit les politiques de la table qu'elle lit :
`profiles` étant clos à la clé publique, le test ne trouvait jamais rien.

`check:supabase` était vert pendant tout ce temps. Il éprouvait qu'une lecture
**interdite** rend zéro ligne et qu'une écriture interdite est refusée ; jamais
qu'une lecture **permise** aboutit. Une politique trop stricte ne lève rien —
elle rend zéro ligne, ce qui se lit exactement comme une base vide.

La section E du contrôle comble ce trou, et c'est la leçon la plus
réutilisable de cette série : **vérifier qu'une permission fonctionne, pas
seulement qu'une interdiction tient.**

## Livré en v1.11.0 — 02/10/2026

*Section retirée à la prochaine version.*

**Les crédits sont supprimés, les formules les remplacent.** Plus de solde, de
barème ni de grand livre : un compte est `basic`, `pro` ou `master`, et c'est
la formule qui ouvre une fonction. Un solde créait un compteur à tenir des
deux côtés — serveur et téléphone — pour une somme que personne ne lisait
jamais au bon moment, et la page « Faire ma promotion » annonçait encore un
coût en crédits pour un geste désormais inclus. `credit_rules.dart` et la table
`credit_ledger` ont disparu (schéma v20) ; `ai_rules.dart` garde le choix du
modèle par fonction, qui reste une question de coût réel.

**Un cours se construit en chapitres (schéma v23).** Trois tables —
`course_chapters`, `course_items`, `course_comments` — et un lecteur : sommaire
par chapitres, vidéo, description du chapitre sous l'image, commentaires sous
la vidéo avec les réponses du professeur distinguées. En dessous de 600 points
de large, une colonne ; au-delà, le sommaire à gauche et la vidéo à droite,
avec plein écran. Le formulaire de création collecte le découpage réel : un
déroulant par chapitre, ses vidéos et ses ressources dedans, chacune choisie
dans les fichiers de l'appareil. Il écrivait auparavant « video_1.mp4 » — un
nom inventé derrière lequel il n'y avait aucun fichier.

Les cours vendus avant les chapitres ne portent qu'une liste plate de chemins :
le dépôt leur reconstruit un sommaire à la première ouverture, sinon un élève
qui a payé trouverait un écran vide. La reconstruction ne repart pas au
serveur, qui connaît déjà ces chemins.

Côté serveur, la migration `0010` pose les trois tables **et sépare la vitrine
de la marchandise** : le programme d'un cours est public — on doit savoir ce
qu'on achète — mais `local_path` et `remote_url` restent fermés à qui n'a pas
payé. Sans cette séparation, le fichier vidéo se lisait avec la clé anonyme,
qui est dans le code du site.

**Premier message automatique (02/10).** Réserver ou contacter ouvre le fil et
y pose un message composé à partir de ce qu'on sait : qui écrit, ce qu'il
cherche, pour quelle classe, et la question qui appelle une réponse. Une donnée
absente retire sa phrase au lieu d'imprimer un gabarit à trous. Aucune
coordonnée n'y figure : `ContactMasker` les masquerait (§30).

**Dépôt réel du CV et du diplôme.** L'étape d'inscription choisit un fichier,
la limite de 8 Mo est enfin appliquée, et la création du compte rattache les
fichiers à la fiche. Le bouton « Passer » reste : un professeur qui n'a pas son
diplôme sous la main doit pouvoir finir son inscription.

**Démarrage à l'épreuve.** Chaque attente avant `runApp` passe par
`runStartupStep`, avec un délai et un défaut : un `flutter_secure_storage` dont
le Keystore est corrompu ne gèle plus l'application sur son logo. Ce qui ne
peut pas être réparé s'affiche en clair, avec un bouton pour copier le message.

538 tests, analyse propre, schémas concordants (48/48).

---

## Livré en v1.8.0 — 24/09/2026

*Section retirée à la prochaine version.*

**L'application a enfin la couleur de son logo.** Le violet est remplacé par
le bleu `#1E40AF`, tiré du marine du logo. C'était le troisième changement de
palette en deux jours, et le seul qui règle le problème au lieu de le
déplacer : l'application était violette et sa marque marine et verte. 8,72:1
sur blanc. Avec lui : le marine `#0F1E4D` pour les cartes sombres, le bleu
très pâle `#EFF4FF` pour les bandes de section, et le jaune d'accent conservé.

Le jaune tombait à **3,37:1** au bout clair du dégradé — le test l'a attrapé.
Le dégradé a été foncé jusqu'à 4,37:1. La règle est désormais écrite : accent
= un mot de titre, jamais un fond, jamais un statut ; un test le vérifie et
refuse `backgroundColor: accent`. Le rouge est rendu au destructif et à
l'urgent.

**Poppins pour les titres.** Deux graisses, 312 Ko, licence OFL conservée à
côté des fichiers. Le corps de texte reste sur la police du système. Titres
montés à 36/30/26 en 800, boutons principaux en majuscules espacées.

**Bandes, puce d'unité, témoignage.** L'accueil professeur s'ordonne en trois
bandes pleine largeur qui alternent. Les montants portent leur devise dans le
champ. Le composant de témoignage existe mais ne s'affiche nulle part : il n'y
a pas encore de témoignages réels, et on ne le remplit pas d'un exemple.

**Messagerie parent↔professeur (schéma v17).** Le fil s'ouvre quand le
professeur accepte — avant, les deux n'ont rien à se dire ; après, ils
n'avaient aucun endroit pour le faire et sortaient de l'application, ce qui
fait sortir la transaction avec eux. Nouvelle table `conversations` ; les
messages restent dans la table existante, parce que le masquage des
coordonnées (§30) ne doit exister qu'une fois. `messages.room_id` devient
facultatif : SQLite réécrit la table, et un test vérifie que les messages de
recrutement survivent à la réécriture — une réécriture ratée ne lève rien,
elle vide la table sur les téléphones déjà installés.

Onglet Messages chez le professeur et chez la famille. Le catalogue quitte la
barre du professeur : six onglets étaient la limite, et il l'ouvre une fois
par mois quand il ouvre ses messages tous les jours.

**Inscription professeur alignée sur les trois autres.** Elle passait par une
page unique écrite le 21/09. Elle tenait sous le pouce mais ne demandait ni
matières ni classes — un professeur inscrit par là n'avait donc **aucune offre
à voir**, la liste étant filtrée par ses matières. Et elle ne pouvait pas
poser les questions conditionnelles : les disponibilités pour cours à domicile
n'existent que si l'on a déclaré en donner. Les quatre profils suivent
désormais le même parcours ; la page unique est supprimée.

**Web aligné.** Mêmes jetons bleus, même dégradé, Poppins sur les titres.

430 tests, analyse propre, build web vert.

---

## Livré en v1.7.0 — 24/09/2026

*Section retirée à la prochaine version.*

**On regarde avant d'ouvrir un compte.** Le premier écran n'est plus la
connexion : c'est une recherche. Titre en deux tons, carte blanche qui
chevauche le dégradé, trois raccourcis de matière, un bouton. Les résultats
sont publics eux aussi — ce qu'ils montrent est ce qu'un professeur publie de
lui-même, les coordonnées restent masquées (§30). Le compte n'est demandé
qu'au moment de contacter quelqu'un, parce que c'est le premier geste qui
engage une autre personne.

La règle d'accès est sortie de la fermeture du routeur : elle vit dans une
constante nommée, et quatre tests la couvrent — dont un qui vérifie que
l'ouverture de deux chemins **n'a pas ouvert le reste**.

**Le web suit.** Même palette, même dégradé, même page d'action, même
`/recherche` publique. Un seul fichier de jetons à changer : `tokens.css`
reflétait déjà la palette mobile, il la reflète toujours.

**Jaune d'accent.** Un mot dans un titre, et rien d'autre. 5,87:1 sur le
violet — mesuré, pas estimé.

**Signalements du 23/09 corrigés.** Le champ de recherche écrivait en blanc
sur un fond blanc que le thème lui posait ; période d'essai ramenée de 90 à
15 jours ; libellés d'onglets passés en blanc par le thème, une fois pour
toutes ; jours de disponibilité devenus des cases à cocher (cocher un jour le
prend en entier, on retire ensuite) ; « Quand êtes-vous disponible ? » devenu
« Vos disponibilités pour une école », avec une seconde étape pour les cours à
domicile, trois jours minimum ; onglet Assistant IA branché chez le
professeur, le parent et l'étudiant ; compte étudiant débarrassé de « Mes
enfants » ; marge haute rendue aux profils parent et étudiant ; page d'âge
retirée du parcours étudiant — la règle des 18 ans vit désormais là où elle
décide de quelque chose, au choix du profil.

**Matières filtrées par classe.** Elles suivaient le cycle (« LYCEE »), ce qui
proposait la philosophie à un professeur de 11ᵉ. Elles suivent maintenant les
classes choisies, et côté parent la classe **puis** le profil de lycée — un
filtre peut désormais chaîner plusieurs questions, celles sans réponse étant
ignorées.

**Un test qui passait à vide.** `indexOf('age_check') < indexOf('level')` reste
vert pour toujours une fois l'étape supprimée : `-1` est plus petit que tout.
Remplacé par une assertion d'absence explicite, plus la vérification que la
condition d'âge est bien énoncée au choix du profil.

417 tests, analyse propre, build web vert.

---

## Livré en v1.5.0 — 23/09/2026

*Section retirée à la prochaine version.*

**Refonte visuelle (23/09).** Cinq maquettes de référence, un seul langage :
en-tête dégradé violet sur les onglets principaux, feuille blanche sur la
connexion, cartes à coins larges sans bordure, pastilles d'icônes teintées,
puces de filtre, bandeaux de chiffres. Palette : `#5B21B6` en principale
(8,98:1 sur blanc), `#0F1724` en texte, `#F6F5FB` en fond de page.

Le travail tient dans une couche de composants partagée — `widgets/hero.dart`,
`widgets/kit.dart`, `widgets/mini_chart.dart` — pour que soixante-huit écrans
héritent du même dessin au lieu d'être redessinés un par un et de diverger.
La barre du bas est désormais un seul composant pour les trois rôles ; il y en
avait trois, dont deux de types différents. Les pages de détail et de
formulaire gardent une barre compacte de la même couleur : deux cents pixels
de dégradé au-dessus de « Ajouter un diplôme » mangeraient l'écran sans rien
apprendre.

Là où les maquettes montraient des données que l'application ne mesure pas —
note moyenne, étoiles, durée d'un cours, vignettes — rien n'a été inventé : ces
tuiles portent un chiffre réel ou disparaissent. Le graphique des revenus sur
sept jours est calculé en SQL et dessiné à la main, sans bibliothèque.

**Deuxième passe (23/09, même jour).** Six composants ajoutés au kit —
`StickyActionBar`, `FormSection`, `FieldLabel`, `StepHeader`, `SheetHeader`,
`SegmentedToggle`, `PersonRow`. Trois primitives partagées ont été redessinées
*en place* plutôt que dupliquées : `AppCard` (34 écrans), `EmptyState`
(35 écrans) et `SectionHeader`. Ces soixante-neuf écrans héritent donc du
nouveau dessin sans avoir été touchés, et ne peuvent pas diverger.

Pages de détail reprises : offre d'emploi, contrat, profil public d'un
professeur — l'en-tête y reprend le contenu de la carte qui y mène, en grand,
et l'action principale est collée en bas. Listes reprises : paiements,
contrats. Le bouton d'envoi de quatre formulaires ne défile plus avec le
formulaire ; le prix d'une action (crédits d'une promotion, coût d'un cours
construit) est affiché au-dessus du bouton, et non découvert au moment de
valider.

**Mode sombre : pas fait, et pourquoi.** `AppColors` est une classe de
constantes `static const`, lues directement par une soixantaine d'écrans. Le
mode sombre demande d'en faire une extension de thème et de reprendre tous ces
points d'appel — sinon la moitié de l'application affiche du texte noir sur
fond noir. C'est un chantier à part entière, pas un ajout de palette.

**Trois tableaux de bord réparés.** `StatRow` posait ses tuiles dans une `Row`
en `stretch` à l'intérieur d'une `ListView` : hauteur disponible infinie, donc
tuiles dessinées hors de l'écran en gardant leur zone de clic. Les trois
tableaux de bord paraissaient vides, débordaient, et un doigt posé dans le vide
ouvrait « Paiements ». Trois tests de mise en page, écrits d'abord en échec.

**Déconnexion du professeur.** Elle avait disparu avec la refonte du profil du
21/09, alors que parent et établissement gardaient la leur. Elle vit maintenant
dans l'en-tête des trois profils, et un test vérifie pour chaque rôle qu'il
existe un moyen de quitter son compte.

**Identité visuelle.** La marque remplace l'icône générique : `Eduqualiflutter_app_logo.png`
devient l'icône du téléphone (icône adaptative Android 8+, plus l'ancien format
pour les appareils antérieurs) et la marque de l'écran d'ouverture ;
`logo_eduquali.png` porte le nom en entier sur la page de connexion, et nulle
part ailleurs. Les deux sources sont détourées par `tools/make_logos.py` — sans
cela le logo traînerait un rectangle blanc sur le fond fumé. L'écran de
démarrage natif, jusqu'ici vide, affiche la marque.

**Chiffres qui changent une décision.** `StatsRepository` calcule tout en SQL sur
la base locale — aucun écran n'attend un réseau pour afficher un nombre. Deux
tuiles par tableau de bord : professeur = encaissé ce mois + vues de profil ;
établissement = postes pourvus + coût mensuel (avec le délai moyen de
recrutement en précision) ; famille = coût mensuel + séances faites sur prévues.
La colonne `teachers.profile_views` (schéma v16) se remplit à l'ouverture d'une
fiche, et le professeur ne se compte pas lui-même.

**Annuler plutôt que confirmer.** Annuler une séance et retirer un enfant ne
posent plus de question : l'action part, et cinq secondes suffisent à la
défaire. La question arrivait avant qu'on voie ce qu'on perd, et se posait
aussi les quatre-vingt-dix-neuf fois où la réponse était oui. Ce qui ne se
rattrape pas — résilier un contrat, retirer un cours de la vente — garde sa
confirmation.

**Charge cognitive.** Tableau de bord établissement ramené de sept liens à
trois, « Résilier » rendu au contrat concerné. Libellés d'ajout explicites
(« ajouter un enfant » plutôt que « ajouter »). Score de confiance et bouton
« Voir » redondant retirés. Dépendance `fl_chart` supprimée : déclarée, jamais
importée, et payée en poids d'APK.

404 tests, analyse propre.

---

**Le fait qui conditionne tout le reste :** l'application mobile ne parle encore
à aucun serveur. Comptes, offres et candidatures vivent dans la base locale d'un
seul téléphone. Tant que la partie 8 n'est pas faite, deux personnes sur deux
téléphones ne peuvent pas interagir — tout ce qui fonctionne est une
démonstration sur un appareil.

---

## Ordre recommandé

```
1. Entrée dans l'application + interface    visible tout de suite, sans serveur
2. Inscription : détails par profil         corrige ce que les testeurs subissent
3. Cours à domicile & inscription scolaire  finir ce qui est commencé
4. Authentification serveur                 ← débloque l'IA ET le multi-appareil
5. Assistant IA réel (+ .docx) et RAG
6. Abonnements et paiement mobile money
```

**Pourquoi l'authentification avant la synchronisation :** l'assistant IA a
besoin de savoir **qui** appelle (crédits, clé Gemini côté serveur), pas de
synchroniser la base locale. L'IA peut donc sortir dès l'étape 4.

---

## 1. Entrée dans l'application

- [ ] **La connexion devient le premier écran.** Aujourd'hui le splash mène
      directement au parcours d'inscription.
- [ ] **Déplacer les écrans de présentation après la création du compte.** On ne
      fait plus lire quatre écrans avant de savoir qui est la personne : on
      ouvre le compte, puis on explique.
- [ ] Écran **preuve sociale** : **plus de 200 professeurs** et
      **3 établissements** déjà inscrits, plus un témoignage nommé par profil.
      Les deux chiffres se lisent depuis un compteur réel et se mettent à jour
      seuls : un chiffre figé devient faux, et un chiffre faux se retourne
      contre nous.
- [ ] Écran **« ce que ça m'apporte »**, adapté au profil (professeur,
      établissement, parent).
- [ ] Écran **« comment s'en servir »** : les 3 gestes utiles du profil.
- [ ] Chaque écran de présentation reste **passable**, et n'apparaît qu'une fois.

## 2. Interface

- [ ] **Contraste renforcé** sur les éléments d'interface : bordures, libellés
      secondaires, états désactivés. Plancher WCAG AA : 4,5:1 pour le texte,
      3:1 pour les bordures et icônes.
- [ ] **Ombre discrète** derrière les cartes, les champs et les boutons, pour
      les détacher du fond.
- [ ] **Augmenter la taille de base du texte de contenu** (16 px aujourd'hui sur
      le web, à relever ; vérifier aussi les libellés secondaires du mobile).
- [ ] Vérifier le résultat sur un écran de téléphone en plein soleil, pas
      seulement sur un moniteur.

## 3. Inscription — ce que chaque profil doit saisir

### 3.1 Professeur / répétiteur
- [x] **Matières filtrées par le niveau choisi.** Collège → matières du collège,
      Lycée → matières du lycée. La liste complète est trop longue et contient
      des matières hors sujet.
- [x] Ajouter **Biologie** et **Géologie** au référentiel.
- [x] **Localisation en cascade** : les **10 régions** administratives →
      préfecture (commune à Conakry) → quartier en saisie libre. Le découpage
      vit dans `shared/geography/guinea.json`, lu par les deux clients ; la
      liste des préfectures reste verrouillée tant que la région n'est pas
      choisie, et changer de région efface la préfecture déjà retenue.
      Aucune liste de quartiers n'existe : en inventer une proposerait à un
      professeur de Ratoma un quartier qui n'existe pas.
- [x] **Disponibilités à cocher** : les 7 jours, puis Matin / Après-midi /
      Soirée — voir 3.2. L'horaire précis (16 h – 18 h) reste à faire.
- [x] **Retirer « Vos centres d'intérêt »** : collecté, jamais utilisé. Une
      donnée sans usage reste une donnée à protéger pour rien.
- [x] **Retirer « Permis de conduire » et « Véhicule »** du parcours.
- [x] **Retirer « Booster mon compte » du parcours d'inscription** : la
      proposition arrive une fois le compte créé.

### 3.2 Disponibilité pour les cours à domicile (professeur)
- [x] Écran dédié après l'inscription : **au moins 3 jours par semaine**,
      avec Matin / Après-midi / Soirée.
- [ ] Horaire précis (16 h – 18 h) en plus du créneau : pas encore fait.
- [x] Refuser la publication d'une offre de cours tant que la disponibilité
      n'est pas renseignée : un parent ne doit pas réserver à l'aveugle.
- [ ] Afficher ces disponibilités sur l'offre et dans la demande de réservation.

### 3.3 École ou université
- [ ] **Fonction obligatoire** de la personne qui inscrit : Directeur/Directrice,
      Fondateur/Fondatrice, Responsable pédagogique, Responsable administratif,
      Responsable des ressources humaines, Autre.
- [ ] **Matières réellement enseignées** par l'établissement : les besoins de
      recrutement s'y limitent ensuite.
- [ ] **Disponibilités de recrutement** : jours et horaires où l'établissement
      reçoit les candidats. Utilisées à la mise en relation.

### 3.4 Parent
- [ ] Fiche enfant complète : **prénom, nom, classe/niveau, établissement
      fréquenté, matière(s) où il a besoin d'aide**.
- [ ] **Plusieurs enfants** : ajouter, modifier, retirer depuis le profil.
      *(L'inscription promet déjà « vous pourrez en ajouter d'autres ».)*

### 3.5 Base des établissements
- [ ] Base des établissements de **Conakry**, organisée Commune → Quartier →
      Établissement.
- [ ] **Recherche au fil de la frappe** : taper « Lycée… » filtre et trie la
      liste. C'est le seul moyen utilisable sur une longue liste.
- [ ] Saisie libre conservée quand l'établissement n'est pas encore répertorié.

### 3.6 Programme guinéen (19/09)
- [x] **Le lycée n'a que trois classes** : 11ème, 12ème, Terminale. « Lycée »,
      « Collège » et « Primaire » étaient proposés à côté d'elles ; ce sont des
      en-têtes de cycle, pas des classes. Ils restent des cibles valables pour
      une certification ou une offre d'emploi, mais ne s'affichent plus dans la
      liste des classes enseignées.
- [x] **Collège** : 7ème à 10ème année, jusqu'au BEPC.
- [x] **Trois profils de lycée** — sciences mathématiques, sciences
      expérimentales, sciences sociales — dans `shared/curriculum/guinea.json`,
      lu par les deux clients. Le profil ne se demande qu'à partir de la 12ème :
      la 11ème est commune.
- [x] Les matières de l'enfant suivent son profil : l'économie ne se fait qu'en
      sciences sociales, la géologie qu'en sciences expérimentales.
- [x] **Matières manquantes ajoutées** : philosophie, éducation civique et
      morale, EPS, et les disciplines universitaires des facultés décrites
      (médecine, pharmacie, gestion, marketing, génie civil, génie électrique,
      télécommunications, sciences politiques). 24 matières au total.
- [ ] Profil du professeur de lycée : à ne collecter que le jour où la mise en
      relation s'en sert. Une donnée sans usage reste une donnée à protéger
      pour rien.

---

## 4. Cours à domicile & inscription scolaire

- [ ] Transformer les réponses « répétiteur » de l'inscription parent (matières,
      lieu) en première demande, ou en pré-filtre de l'onglet Professeurs.

### Inscription scolaire
- [ ] Bouton « Demander une inscription » sur la fiche établissement. L'API
      (`/enrolments`) et la migration `0004` sont prêtes ; rien côté mobile.
- [ ] **Établissement :** liste des demandes reçues — accepter / refuser.
- [ ] **Parent :** suivi de ses demandes.

---

## 5. Assistant IA et formules

Spécification complète, écrans et calculs de marge : [AI_ASSISTANT.md](AI_ASSISTANT.md).

**Prérequis :** la clé API Gemini ne vit **que** sur le serveur. Une clé
embarquée dans l'APK se lit en quelques minutes et se facture sans limite.

### 5.1 Passerelle IA (serveur)
- [ ] Module unique `llm.ts` : seul point d'appel à Gemini (délai, reprises,
      comptage des jetons, choix du modèle).
- [ ] Routes `/v1/ai/chat`, `/v1/ai/course/outline`, `/v1/ai/course/build`,
      `/v1/ai/course/:id/edit`, toutes authentifiées.
- [x] Clé `GEMINI_API_KEY` en variable serveur, vérifiée le 19/09 par
      `npm run check:gemini` (41 modèles, génération JSON réussie).
      **Elle avait été collée dans `.env.example`**, qui est versionné :
      déplacée vers `.env`, que `.gitignore` couvre.
- [ ] **Confirmer que la facturation est active** sur `console.cloud.google.com`.
      L'API ne dit pas de quelle offre relève une clé. En offre gratuite,
      Google se sert des données envoyées — inacceptable pour des photos de
      devoirs d'enfants.
- [ ] Réponses du chat en flux (SSE) : le texte arrive au fil de l'eau sur 3G.
- [ ] Consignes système versionnées, moins de 1 500 jetons.

### 5.2 Sortie des cours
- [x] **Word (.docx) par défaut** : c'est le format que le professeur rouvre,
      modifie et réutilise. Le bouton principal télécharge le cours en Word.
      `CourseDocx` écrit le document ; relu par python-docx, Word y retrouve
      les titres, le sommaire, les définitions, les corrigés, le calendrier.
- [x] Excel en second bouton, pour les exercices et le calendrier — les
      tableaux s'y prêtent mieux que dans un document texte. Les deux fichiers
      sont écrits d'un coup à la construction (schéma v8, `ai_courses.docx_path`).
- [ ] Le modèle renvoie du **JSON structuré** ; le serveur fabrique le fichier.
      On ne demande jamais au modèle de produire le fichier lui-même.

### 5.3 Reste à faire sur l'assistant
- [ ] Plafond d'usage par formule, tenu côté serveur. Les crédits ont disparu
      le 02/10 : ce qui limite un compte est désormais sa formule, et la limite
      n'existe encore nulle part. Sans elle, `master` est un forfait illimité
      sur une fonction facturée au jeton.
- [ ] État hors ligne : bouton désactivé, message clair, **aucun débit**.
- [ ] Élève — aide aux devoirs : choisir l'enfant, mode tuteur (ne pas donner la
      réponse d'emblée), photo d'exercice, réglages de sécurité renforcés.
- [ ] Professeur — « Corrige ce devoir » : photo de copie → correction, erreurs,
      note proposée (**total calculé par le serveur**, jamais par le modèle).
- [ ] Discussion libre réelle.
- [ ] Écran « Mon abonnement » : formule en cours, ce qu'elle ouvre, échéance.
      Il remplace « Mes crédits », retiré avec le barème.

### 5.4 Coûts et garde-fous
- [ ] Journal de chaque appel : compte, fonction, modèle, jetons, coût, durée.
- [ ] **Plafond de dépense mensuel global** : au-delà, l'IA se met en pause
      proprement, sans débiter personne.
- [ ] Limites par compte et plafond de jetons par fonction.
- [ ] Tableau de bord interne : coût réel des appels IA par formule vendue.
      C'est le chiffre qui dira si `master` à 200 000 GNF tient.

---

## 6. Mémoire documentaire (RAG) — nouveau

But : que l'assistant réponde à partir de **contenus guinéens réels**
(programmes officiels, manuels, annales) au lieu de généralités.

- [ ] Choisir le stockage des vecteurs. **Proposition : `pgvector` dans le
      Postgres Supabase déjà en place** — pas de second service à exploiter tant
      que le volume ne l'impose pas.
- [ ] Tables `documents` (source, titre, niveau, matière, année, licence) et
      `chunks` (texte, vecteur, renvoi au document).
- [ ] Découpage en fragments : viser 500–800 jetons avec recouvrement, en
      respectant les titres — un fragment coupé au milieu d'un énoncé ne sert à
      rien.
- [ ] Vecteurs via l'API d'embedding Gemini, par lots, avec reprise.
- [ ] Recherche filtrée par **niveau et matière** avant la similarité : un
      fragment de terminale n'a rien à faire dans un cours de collège.
- [ ] Les fragments retenus sont **cités** dans la réponse (titre + page) : un
      professeur doit pouvoir vérifier la source.
- [ ] Script d'ingestion : PDF / Word / texte → fragments → vecteurs, relançable
      sans doublon.
- [ ] **Droits d'usage** : ne rien ingérer sans vérifier qu'on a le droit de
      s'en servir. À trancher document par document.
- [ ] Contenus à réunir : programmes officiels par niveau, annales du bac et du
      BEPC, manuels autorisés.

---

## 7. Abonnements et paiements

### 7.1 Abonnement récurrent — remplace les packs à l'unité
- [ ] **Engagement 3 / 6 / 12 mois**, au choix, **prélevé chaque mois**.
      Entrée de gamme : **100 000 GNF par mois** sur 12 mois.

      | Engagement | Par mois | Total | Écart sur un an |
      |---|---|---|---|
      | 3 mois | 150 000 GNF *(à confirmer)* | 450 000 GNF | — |
      | 6 mois | 120 000 GNF *(à confirmer)* | 720 000 GNF | 360 000 GNF économisés |
      | **12 mois** | **100 000 GNF** | 1 200 000 GNF | **600 000 GNF économisés** |

      Seul le prix de l'entrée de gamme est arrêté ; les deux autres sont une
      proposition, calculée pour que l'engagement long reste le plus avantageux.
- [ ] Sélecteur de durée : 12 mois **présélectionné**, l'économie affichée
      **en francs** et non en pourcentage.
- [ ] Ce que l'abonnement inclut chaque mois (usage de l'IA, visibilité) reste à
      arrêter — décision ouverte n° 5.
- [ ] Renouvellement automatique, **résiliation en autant d'étapes que la
      souscription**, sans appel téléphonique.
- [ ] Échec de prélèvement : relance, période de grâce, puis suspension —
      jamais de coupure sans prévenir.
- [ ] **Crédits reportés d'un mois sur l'autre** tant que l'abonnement court,
      **perdus à la résiliation**. À écrire noir sur blanc avant la
      souscription, pas dans les conditions générales.

### 7.2 Paiement
- [ ] Mobile money via un agrégateur : **Orange Money** puis **MTN MoMo**.
- [ ] Écran d'attente explicite (« validez sur votre téléphone »), jamais une
      roue qui tourne sans explication.
- [ ] Reçu et référence de transaction citables par téléphone.
- [ ] Prélèvement récurrent : vérifier ce que l'agrégateur permet réellement.
      Sans mandat récurrent, prévoir une relance manuelle à échéance.

### 7.3 Frais de recrutement et Visibilité+
- [ ] **Réévaluer les frais de recrutement** (aujourd'hui : un mois de salaire)
      au regard de ce qu'un établissement guinéen peut réellement payer —
      décision ouverte n° 10.
- [ ] Brancher `activateBoost()` : la méthode existe, **aucun appel**.
- [ ] Proposer le boost **après** la création du compte.

---

## 7-bis. Signalements du 20/09 — corrigés

Trois défauts trouvés en testant l'APK 1.4.0. Aucun n'était visible depuis un
test unitaire : ils vivaient tous dans le trajet complet.

- [x] **« Je clique sur professeur et ça revient au menu. »** `intro.json` ne
      contient plus qu'une étape, le choix du profil : la première était donc
      aussi la dernière, et l'écran fermait sa propre route juste après avoir
      prévenu l'appelant. Le `Navigator.maybePop()` automatique est retiré —
      chaque appelant décidait déjà de la suite.
- [x] **Fiche professeur inaccessible depuis un compte école ou parent.**
      Le garde-fou de rôle comparait des préfixes de texte, et
      `'/teachers/t_123'.startsWith('/teacher')` vaut vrai : ouvrir une fiche
      renvoyait l'utilisateur à son accueil, sans un mot. La comparaison porte
      désormais sur des segments entiers (`belongsToOtherSpace`).
- [x] **Badges verts sur les cartes professeur.** Le pourcentage de
      certification et le score de compatibilité promettaient une précision
      que trois lignes ne justifient pas. Ils vivent sur la fiche, qui montre
      le détail par matière et par classe.
- [x] **Onglet « Écoles » du parent remplacé par un accueil** : dernière
      séance, prochaines séances, et deux actions — chercher un professeur,
      trouver une école. L'annuaire reste, en action rapide.
- [x] **Séances de cours à domicile** (schéma v11). Elles naissent quand le
      professeur accepte, aux jours et créneaux qu'il a lui-même déclarés.
      Avant l'acceptation, rien n'est annoncé au parent : ce serait promettre
      à la place de quelqu'un d'autre.
- [x] **Mise en place guidée des cours à domicile** (`/teacher/tutoring/setup`)
      en quatre étapes : jours (3 minimum), créneaux, matière et classes,
      conditions. Un formulaire unique portant six blocs décourageait.
- [ ] Horaire précis (16 h – 18 h) en plus du créneau.
- [ ] Le professeur marque une séance comme faite depuis son espace : la
      mécanique existe (`markDone`), l'écran non.

## 0. Note manuscrite du 21/09 — a faire en premier

Transcription de la feuille remise le 21/09, dans l'ordre du document.

**Avancement au 22/09** — **toute la note est faite**, sauf la lecture des
videos achetees (0.5). 368 tests passent, analyseur propre.

Schemas ajoutes en chemin : **v13** (cours video et achats), **v14**
(promotions), **v15** (moyens de paiement).

Deux points qui meritent votre avis, signales la ou ils se trouvent :
le **score de certification ne classe plus** (0.6), et l'inscription
professeur en **une page** coexiste avec le parcours en etapes des trois
autres profils.

### 0.1 Nom du produit
- [x] **Renommer l'application en « Eduquali »** : `AppConstants.appName`,
      `EduqualiApp`, `android:label`, documentation et paquets npm. L'ecran
      de connexion affiche le nom depuis `appName`, il suit donc tout seul.

### 0.2 Connexion
- [x] Numero **+ mot de passe**. Champ vide = code par SMS, car les comptes ouverts par l'inscription n'ont pas de mot de passe.
- [x] Actions : **s'inscrire** et **mot de passe oublie**, cote a cote sous le bouton.
- [x] **Mot de passe oublie** : recuperation par courriel **ou** par numero
      (`requestPasswordReset`). Le message ne dit jamais si le compte existe :
      ce serait donner a un inconnu le moyen de savoir qui est inscrit.

### 0.3 Inscription professeur
- [x] La page « Derniere experience » est **remplacee** par le depot du
      **CV + diplome** (nouveau type d'etape `upload`).
- [x] **Nouvelle page 2** : « Selectionnez vos services » — *A domicile*,
      *Job a temps plein*.
- [x] Pouvoir choisir **plusieurs matieres** — l'etape etait deja multiple.
- [x] **Retirer le bouton « Passer »**, sauf sur le depot du CV et du diplome.
- [x] **Retirer la page « Kilometres »** : personne ne convertit son trajet en kilometres, la zone se dit en quartiers.
- [x] **Numero de telephone** : saisie bornee a 9 chiffres, soit 13 avec
      l'indicatif `+224`. Le choix du pays et les indicatifs etrangers sont
      retires.
- [x] **Choix des dates** : liste deroulante empilee des **7 jours** ; au clic
      sur un jour, les **heures** apparaissent (type `day_hours`). Remplace les
      deux etapes « jours » puis « moments », qui posaient la meme question en
      deux fois sans relier un jour a son heure.

### 0.4 Nouveau profil
- [x] **Compte Etudiant** (majeur, plus de 18 ans), quatrieme profil du
      selecteur, avec son propre parcours `student_onboarding.json`. Il
      partage l'espace du parent : meme scolarite suivie, memes contrats,
      meme calendrier — lui en construire un second ne changerait que le mot
      « enfant ». La question de l'age arrive en deuxieme : en dessous de 18
      ans c'est un parent qui ouvre le compte, et la poser a la fin ferait
      remplir dix ecrans pour rien.

### 0.5 Catalogue de cours video

Socle pose : schema **v13** (`video_courses`, `course_purchases`),
`VideoCoursesRepository`, commission de 20 % dans `AppConstants`.

Le prix **et** la commission sont figes a l'achat : changer le tarif plus
tard ne doit pas reecrire ce qu'un eleve a deja regle.

- [x] **Domaine** : creation, publication, achat, gains nets du professeur.
- [x] **Professeur** : onglet **Catalogue** (a la place d'« Assistant »,
      qui reste atteignable depuis l'accueil) montrant ses cours, ses ventes
      et ses gains nets, avec « creer un cours » sous le tableau.
- [x] **Formulaire de creation** : titre, matiere, videos, prix. La
      commission s'affiche **avant** la publication, avec ce qui reste au
      professeur : decouvrir la retenue au moment du premier virement est la
      meilleure facon de perdre quelqu'un.
- [x] **Eleve / parent** : onglet **Catalogue** separant « mes cours » de
      « cours disponibles ». La recherche de repetiteurs quitte l'onglet pour
      devenir un ecran : on cherche un professeur ponctuellement, on regarde
      ses cours tous les jours.
- [ ] Lecture de la video une fois achetee. L'ecran le dit franchement au
      lieu d'afficher un bouton qui ne lit rien.

### 0.6 Mise en relation
- [x] **Bareme** : disponible **30 points**, diplome (**master 30**,
      **licence 10**), ville **30 points**, experience **10** pour completer
      le total. La matiere et le niveau ne rapportent plus de points : ce
      sont des **conditions**. Un professeur de francais ne se classe pas
      « un peu » sur un poste de mathematiques — son score est nul, et la
      raison reste lisible dans les facteurs.

      **Consequence a connaitre :** le score de certification, qui pesait
      25 %, ne classe plus. Les tests de competence restent affiches sur la
      fiche du professeur ; ils ne departagent plus deux candidats. A dire si
      ce n'etait pas voulu.

### 0.7 Etablissements
- [x] Bouton **« Faire la promotion de mon etablissement »** dans les actions
      rapides du tableau de bord.
- [x] **Page de configuration d'une promotion** : titre, message, videos et
      images. Cout **50 credits**, annonce sur le bouton avant d'etre debite.
      Le debit et la mise en ligne tiennent dans la meme transaction : une
      promotion payee mais invisible, ou visible sans avoir ete payee, sont
      deux facons de perdre la confiance d'un directeur.
- [x] Accroche : « Montrez votre etablissement a plus de 3 000 parents et
      etudiants. » Le chiffre vit dans `AppConstants.promotionReach`, pour
      qu'il ne derive pas d'un ecran a l'autre.
- [x] **Page separee** listant les professeurs de cours a domicile. Ils
      etaient melanges aux candidats a un poste, alors qu'un etablissement ne
      les cherche pas pour la meme raison : un repetiteur vient quelques
      heures par semaine, un enseignant occupe un poste a l'annee.

### 0.8 Paiements, sur les quatre profils
- [x] **Ajouter un moyen de paiement** depuis le profil / les reglages, sur
      les quatre profils — un seul ecran partage, quatre auraient fini par ne
      plus proposer les memes moyens. L'argent mobile d'abord (Orange Money,
      MTN MoMo), puis la carte, puis les especes : c'est ce que les gens ont.

      **Aucun secret n'est conserve** : ni code, ni numero complet. Seuls les
      quatre derniers chiffres sont ecrits, et ce sont eux seuls qui partent
      dans la file de synchronisation. Un code de paiement dans une base que
      l'APK transporte de telephone a telephone se lirait en quelques
      minutes.
- [x] **Telecharger les factures des paiements en PDF** (`InvoicePdf`). Le
      professeur voit ce qu'il encaisse, la famille ce qu'elle regle : la
      meme liasse, vue de chaque cote. Une periode sans paiement donne quand
      meme un document — un comptable qui demande les factures doit recevoir
      une page qui dit « rien », pas une erreur.

---

## 8. Serveur — faire exister le produit à plusieurs

- [ ] **Authentification serveur** par numéro + code (Supabase Phone). Les
      routes `/auth/*` n'existent pas.
- [ ] Envoi réel du SMS.
- [ ] `POST /sync/push` : le mobile l'appelle, le serveur ne l'a jamais eu.
- [x] Pointer l'application sur la vraie API : l'adresse est désormais un
      réglage de compilation, `--dart-define=ACALIA_API=…`, **vide par
      défaut**. L'ancienne valeur codée en dur, `api.veriprof.gn`, faisait
      attendre l'application toutes les 45 secondes devant un domaine
      inexistant. Sans adresse, aucune sonde n'est envoyée.

### 8-bis. Une dette trouvée le 19/09 : aucune clé étrangère

`tables.dart` déclare **51 `.references(...)`**. Le schéma SQL généré n'en
porte **aucune** — vérifié en lisant `sqlite_master` sur une base fraîche.
`PRAGMA foreign_keys = ON` est bien posé, mais il n'a rien à faire respecter.

Conséquence : la base accepte un enfant rattaché à un parent qui n'existe pas,
une candidature vers une offre supprimée, une certification sur un niveau
retiré. Rien ne casse tout de suite ; les incohérences s'accumulent en silence
et se découvrent le jour de la synchronisation, quand le serveur, lui, les
refusera.

- [ ] Décider si on ajoute les contraintes. Sur SQLite, ajouter une clé
      étrangère à une table existante impose de la **reconstruire** (créer,
      recopier, renommer) — une migration par table, sur une base qui contient
      déjà les données des testeurs. Ce n'est pas une correction d'une ligne.
- [ ] En attendant, `seed_curriculum_test.dart` **expose** l'état réel : le
      test échouera le jour où les contraintes apparaîtront, et devra alors
      être remplacé par son contraire.
- [ ] Désactiver le code unique hors ligne dans les versions publiées :
      `--dart-define=OFFLINE_OTP=false`.
- [ ] `/teachers` et `/teachers/:id` : authentification obligatoire, réservés aux
      établissements. Aujourd'hui lisibles par n'importe qui.
- [ ] Tests de compétence : session ouverte côté serveur, une tentative, délai de
      30 jours. Aujourd'hui on peut soumettre en boucle jusqu'à réussir.
- [ ] Web : jeton de session hors de `localStorage`.
- [ ] Une seule source pour les pondérations (compatibilité, confiance,
      complétion) : le mobile garde encore sa propre copie, divergente.
- [ ] `/teachers` paginé, profil chargé en une requête.
- [ ] Notifications push.

---

## 9. Avant tout lancement public

### Confiance
- [ ] Back-office : faire passer identité, diplôme, expérience et établissement à
      « vérifié ». **Aucun chemin de code ne le fait** aujourd'hui.
- [ ] Vérification d'identité réelle : les contrôles actuels ne regardent que la
      taille du fichier.

### Sécurité et données
- [ ] Clé de signature de publication : l'APK est signé avec la clé de débogage.
      La changer plus tard oblige chaque utilisateur à désinstaller.
- [ ] Base locale chiffrée (SQLCipher) ; pièces d'identité non conservées en clair.
- [ ] Code PIN : hachage lent et sel aléatoire.
- [ ] Analyse juridique guinéenne sur les données personnelles (§52).

### Outillage
- [ ] Dépôt git et intégration continue : aucun historique, aucun retour arrière.
- [ ] Vérification des parcours et tests à chaque envoi.

---

## Décisions ouvertes

Tranchées le 19/09 : format Word par défaut · chiffres de preuve sociale ·
retrait des centres d'intérêt · retrait du permis et du véhicule · report des
crédits · socle d'abonnement à 100 000 GNF par mois.

1. **Compte étudiant autonome pour les majeurs** (université) : utile, non
   tranché. Pour les mineurs, le compte appartient au parent (décidé le 14/09).
2. **Publicité et mineurs.** Vidéos récompensées réservées au compte parent,
   jamais pendant une session d'enfant.
3. **Écrans de découverte** : à mesurer une fois déplacés après l'inscription.
4. **Prix des engagements 3 et 6 mois.** Seul le socle à 100 000 GNF sur 12 mois
   est arrêté. Les deux autres sont une proposition.
5. **Ce que l'abonnement inclut.** Les crédits sont supprimés depuis le
   02/10 : reste à dire quel usage de l'IA et quelle visibilité chaque formule
   ouvre. Sans cela, un abonné ne sait pas ce qu'il achète, et `master` se lit
   comme illimité. Repère : l'ancien pack à 90 000 GNF donnait 100 crédits,
   soit une vingtaine de cours complets.
6. **Prélèvement récurrent en mobile money.** À vérifier auprès de
   l'agrégateur : sans mandat récurrent, il faudra une relance manuelle à
   chaque échéance, ce qui change le parcours de paiement.
7. **Montant des frais de recrutement.** Un mois de salaire est probablement
   hors de portée d'une petite école. À fixer avec des chiffres d'écoles
   réelles avant d'en faire une promesse commerciale.
