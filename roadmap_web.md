# Feuille de route — application web

Amener le client React au niveau de l'application Flutter, pour qu'une même
personne puisse **commencer sur son téléphone et continuer sur un ordinateur**
sans rien réapprendre et sans rien reperdre.

Écrit le 25/09/2026, sur l'état des deux clients à cette date.

---

## Le fait à connaître avant tout le reste

> **Les deux clients ne partagent encore aucune donnée.**
> Le mobile écrit dans un SQLite local (45 tables, schéma v20). Le web, lui,
> **parle désormais directement à Supabase** — décision du 25/09, code écrit ;
> il reste à héberger la base. Le mobile suivra ensuite.

C'est ce qui décide de l'ordre de cette feuille de route. Porter vingt écrans
sur le web pendant que chaque client garde ses données dans son coin
produirait deux applications qui se ressemblent et ne se parlent pas — un
résultat pire qu'aujourd'hui, parce qu'il *aurait l'air* de devoir se
synchroniser. La base partagée vient donc avant les fonctions.

**Ce que « direct » veut dire, et ce qu'il coûte.** Le navigateur interroge
PostgREST avec la clé anonyme, qui part en clair dans le bundle. Ce n'est
donc pas elle qui protège quoi que ce soit : la seule barrière est RLS, table
par table. Une table sans RLS est lisible par le monde entier ; une table
avec RLS mais sans politique est fermée à tous. Il n'y a pas de troisième
cas, et aucun filtre écrit dans le client n'y change rien — le premier `curl`
le contourne.

---

## Ce qui tourne aujourd'hui

| | Flutter (mobile) | React (web) |
|---|---|---|
| Routes | ~68 | 21, dont 8 publiques |
| Rôles | professeur, école, parent, **étudiant** | les quatre (02/10) |
| Écrans métier | l'ensemble du produit | recrutement, annuaire public, vitrine des cours |
| Composants partagés | 43 (`kit.dart`, `hero.dart`, `typeform_kit.dart`) | 15 (`components/ui.tsx`, `AppGate.tsx`) |
| Tests | 538, dans 46 fichiers | 68, dans 6 fichiers |
| Largeurs | téléphone (le produit y est né) | téléphone, puis 600 et 1024 px |
| Données | SQLite local, hors ligne d'abord | **Supabase en direct**, ou simulé sans configuration |
| Jetons de design | `app_colors.dart` | `tokens.css` — **mêmes valeurs** |

**La règle du produit, posée le 02/10 : le web montre, l'application agit.** On
parcourt sans compte tout ce qui se regarde — professeurs, écoles, offres,
programme des cours vidéo. Le compte, puis l'application, sont réclamés au
premier geste qui engage quelqu'un d'autre : contacter, postuler, réserver,
regarder, signer, payer.

Ce qui reste mobile uniquement, et volontairement : le lecteur vidéo et ses
commentaires, l'assistant IA (clé serveur, facturé à l'appel), la vérification
d'identité (appareil photo), la messagerie et la levée du masque sur les
coordonnées, les contrats et la signature, les paiements, les notifications, la
synchronisation hors ligne, et tout le travail d'édition d'un profil.

**Ce qui est déjà en parité, et qu'il ne faut pas casser :** les jetons de
couleur, de typographie et d'espacement ; le moteur d'inscription piloté par
les mêmes JSON (`shared/onboarding/`) ; le format monétaire (`100 000 GNF`) ;
le découpage administratif et le programme national.

---

## Phase 0 — Les quatre pannes silencieuses · **faite le 02/10**

Petites, indépendantes du serveur, et ce sont des régressions actives. Aucune ne
levait d'erreur — elles faisaient disparaître des écrans, ce qui ne se voit
qu'en parcourant l'inscription jusqu'au bout.

Les quatre sont corrigées, avec 11 tests qui les tiennent fermées
(`src/onboarding/spec.test.ts`, `src/lib/textSearch.test.ts`). Les tests lisent
les parcours dans `public/data/` : une étape ajoutée au JSON sans rendu
correspondant les fait échouer, ce qui est exactement ce qui manquait.

### 0.1 — « Étudiant » mène à une impasse · **fait le 02/10**

`spec.ts:166` déclare `Audience = 'teacher' | 'institution' | 'parent'`. Le
quatrième rôle existe pourtant dans `intro.json`, et
`student_onboarding.json` est bien copié dans `public/data/` par le script de
synchronisation. Choisir « Étudiant » calcule donc
`AUDIENCE_BY_ROLE['STUDENT'] === undefined`, la requête part sur
`/data/undefined_onboarding.json`, et l'écran affiche « Parcours
indisponible ».

`'student'` est dans `Audience`, `'STUDENT'` dans `Role` et dans
`AUDIENCE_BY_ROLE`, `RegisterInput.role` et `Session.role`. Les onglets de
l'étudiant sont ceux de la famille — même besoin, et c'est déjà le choix du
mobile ; un second jeu d'écrans se tiendrait sans rien ajouter. L'arrivée après
inscription est `/etablissements`, comme pour un parent.

Deux tests : chacun des quatre rôles charge un parcours qui rend au moins une
étape, et **tout profil proposé par `intro.json` doit avoir une entrée** — un
cinquième rôle ajouté au JSON fera échouer le test au lieu de disparaître.

### 0.2 — `showIf` ignore les réponses multiples · **fait le 02/10**

`stepApplies` (`spec.ts:319`) réduit la réponse donnée à `String(given)`
(ligne 323) avant de la comparer. Sur une réponse multiple,
`['HOME','FULL_TIME']` devient `"HOME, FULL_TIME"`, qui n'égale jamais
`"HOME"`.

Conséquence aujourd'hui : depuis le retrait de « Vous donnez des cours à
domicile ? » le 26/09, les deux écrans de disponibilité du professeur
**ne s'affichent plus jamais** sur le web. Le parcours se termine, le profil
part incomplet, et rien ne le signale.

`stepApplies` compare maintenant deux listes : la réponse correspond dès qu'un
de ses éléments correspond — la règle de `ShowIf.matches` côté mobile. Les deux
clients lisent le même JSON, ils doivent en tirer les mêmes écrans.

Test : `service_types: ['HOME','FULL_TIME']` rend les deux écrans ; `['HOME']`
rend `home_availability` et retire `availability` — la condition filtre
encore.

### 0.3 — Deux types d'étape ne sont pas implémentés · **fait le 02/10**

`upload` et `day_hours` ne figurent pas dans `StepType`. Le rendu tombe sur
`default: return null` (`OnboardingFlow.tsx:373`) et `canContinue` renvoie
`true` : l'écran est vide, le bouton Continuer fonctionne, et on passe.

Un professeur inscrit sur le web **ne dépose donc jamais son CV et ne déclare
jamais ses horaires**.

- `upload` : un champ fichier par entrée de `uploads`, limite de 8 Mo dite au
  moment du choix — la même qu'au téléphone, c'est la même connexion. L'étape
  reste `optional`, donc « Passer » existe : un candidat n'a pas toujours son
  diplôme sous la main.
- `day_hours` : les sept jours et les trois moments. Cocher un jour le prend en
  entier, puis on retire les moments qui ne conviennent pas ; l'inverse laissait
  des jours cochés sans créneau, que le parcours refusait sans dire pourquoi.
  Forme stockée identique au mobile : `{ MON: ['MORNING', …] }`. `canContinue`
  compte les jours **qui portent au moins un créneau** — un jour vide ne dit pas
  quand on est libre.
- Un type inconnu lève maintenant en développement au lieu de rendre `null`, et
  `RENDERED_STEP_TYPES` est vérifié contre les cinq parcours du JSON. C'est ce
  silence qui avait laissé passer les deux.

**Ce qui reste :** le fichier choisi est gardé tel quel dans les réponses
(l'objet `File`), mais rien ne l'envoie — Supabase Storage n'existe pas encore
(1.2). L'écran dit « joint », jamais « vérifié », et il ne faut pas changer ce
mot avant que l'envoi existe.

### 0.4 — `searchable` est ignoré · **fait le 02/10**

Le drapeau posé le 24/09 sur les quatre étapes « matières » ne produit rien
sur le web : la liste reste un mur de vingt-quatre étiquettes.

`TypeAheadTags` est porté dans `OnboardingFlow.tsx` : champ à taper,
suggestions dessous, étiquettes retenues en bas, et ce qui est déjà choisi ne se
repropose pas — le reproposer fait croire qu'on ne l'a pas pris. `foldText` et
`matchesSearch` sont repris à l'identique dans `src/lib/textSearch.ts` : un
clavier guinéen tape « francais » et « Nzerekore », et « aucun résultat » sur une
liste qui contient la réponse fait conclure que la matière n'existe pas.

Les matières écartées par `optionsFilter` restent accessibles sous « Hors des
classes choisies », comme au téléphone : un professeur peut enseigner une
matière hors des classes qu'il a déclarées, et la faire disparaître l'obligerait
à revenir en arrière.

---

## Phase 0bis — Le web montre, l’application agit · **faite le 02/10**

La frontière du produit, posée explicitement. Avant, **toutes** les pages de
contenu étaient derrière `<Guard>` : le site demandait de s’inscrire pour savoir
s’il y avait une raison de s’inscrire, alors que son propre accueil promet que
« le compte n’est réclamé qu’au moment de contacter quelqu’un ». Le téléphone,
lui, laisse tout parcourir sans compte (`publicPaths`).

**Publiques désormais :** `/professeurs`, `/professeurs/:id`, `/etablissements`,
`/etablissements/:id`, `/offres`, `/offres/:id`, `/cours`, `/cours/:id`. Une
barre d’onglets apparaît pour un visiteur — sans elle, il atterrit sur une liste
et ne peut pas aller voir l’autre.

**Restent derrière le compte :** `/candidatures`, `/tests`, `/profil`. Les ouvrir
n’afficherait rien d’utile et se lirait comme une panne.

**Le geste engageant est remplacé, jamais masqué** (`components/AppGate.tsx`).
Un bouton absent se lit comme « ce professeur ne prend personne », ce qui est
faux et coûte un contact. Le composant dit ce que le téléphone apporte — fil de
discussion hors réseau, vidéos téléchargées, dépôt du CV — et non « il faut un
compte », qui ne donne aucune raison d’en créer un.

Au passage, un défaut qui ne concernait pas que les visiteurs : « Envoyer ma
candidature » appelait `apply`, qui sortait sans rien faire quand le compte
n’avait pas de fiche enseignant. Le bouton s’enfonçait et il ne se passait rien
— pour un parent ou un établissement aussi.

### Ce que ça a révélé côté serveur

`api.teacher(id)` existait dans le contrat et **aucune route ne l’appelait** : la
liste affichait des noms sur lesquels on ne pouvait pas cliquer. La fiche
publique est maintenant là, avec le même contenu que l’écran du téléphone.

Plus grave : `teacherColumns` joint `profiles` directement, et « profil : lecture
de soi » (0002) ferme cette table à tout le monde sauf son propriétaire. Les
cartes publiques se seraient affichées **sans nom** — et le réflexe devant ce
symptôme est d’ouvrir `profiles`, ce qui aurait publié les téléphones. La
migration `0009` avait créé `public_teacher_identities` exactement pour ce cas,
et rien ne l’utilisait. C’est fait, par une requête séparée plutôt qu’une
jointure sur la vue : PostgREST ne devine pas toujours la relation d’une vue, et
un `select` imbriqué qui échoue ferait tomber toute la liste.

Quatre tests tiennent cette porte fermée (`src/api/public-reads.test.ts`) : la
requête publique ne demande ni `phone` ni `email` ni `teacher_documents`, la vue
n’expose que quatre colonnes, un nom manquant ne fait pas échouer la liste, et
les routes gardées le restent.

### Ce qui est passé du téléphone au web

| Fonction | État |
|---|---|
| Fiche publique d’un professeur | faite — identité, vérifications, matières, parcours, tests réussis |
| Fiche d’un établissement | faite — `institutions()` rendait déjà l’adresse et la description, la liste les jetait |
| Cours à domicile sur la fiche | faite — tarif, mode, quartiers desservis, disponibilités. Les offres actives étaient publiques depuis 0002 ; l’écran manquait |
| Vitrine des cours vidéo + programme complet | faite — voir 3.8 |
| Filtre par ville sur les professeurs | fait — la ville du compte sert de départ, pas de prison |
| Mises en avant d'établissements | faite — « À la une » en tête de la liste des écoles. C'est ce qu'un établissement achète avec Master, et ce qu'il achète est d'être vu par des gens **sans compte** : la même annonce derrière une authentification ne touche personne |
| Catalogue des tests de certification | fait — public. Un professeur doit pouvoir voir qu'une certification existe dans sa matière avant d'ouvrir un compte |

Et un défaut que l'ouverture a mis au jour : sur le backend Supabase,
`submitTest` lève un 501 par construction — corriger dans le navigateur
demanderait de lui livrer les bonnes réponses. On pouvait donc répondre à vingt
questions avant d'apprendre que rien ne serait enregistré. `canGradeTests`
(`src/api/index.ts`) ferme l'entrée du test au lieu de la sortie.

---

## Phase 0ter — Du téléphone à l’ordinateur · **faite le 02/10**

Le web n’était pas « non adapté » : il était **volontairement bridé** à la
largeur d’un téléphone. `.shell` et `.flow` portaient `max-width: 720px`, donc
sur un portable de 1 440 px l’application était une bande centrée sur du blanc.
Rien ne cassait ; rien n’utilisait l’écran non plus.

### Deux seuils, et une seule section pour les tenir

Il y en avait **trois** qui disaient la même chose : `600` côté Flutter
(`_largeurPourDeuxColonnes`), `640` dans `tokens.css`, `720` dans `app.css`.
C’est ce désaccord qui avait produit un défaut visible : `.hero` débordait de
`--s-5` en dur alors que la gouttière passait à 40 px, donc **deux bandes
blanches encadraient le dégradé bleu dès 640 px**. Corrigé en débordant de
`--gutter`.

Désormais : **600 px** (la valeur du client Flutter — un seul nombre pour « ça
ne tient plus sur une colonne ») et **1024 px** (l’ordinateur). La tablette
reçoit la transition et rien de plus : ce n’est pas un usage courant ici.
Toutes les règles vivent dans une seule section à la fin de `app.css` — les
règles dispersées sont exactement ce qui avait produit trois seuils.

### Ce qui change, et où

| Seuil | Ce qui change |
|---|---|
| **≥ 600** | La barre d’onglets devient un en-tête : `order: -1`, collée en haut, libellés à côté des icônes, la marque apparaît, le compte part à droite. **Même composant, même DOM** — seule la mise en page change. Les listes de cartes deviennent des grilles `auto-fill minmax(300px, 1fr)` |
| **≥ 1024** | `.shell` passe à 1 240 px (trois cartes de 300 px avec leurs gouttières). Les fiches passent en deux colonnes : contenu à gauche, identité et action collées à droite. L’accueil se dédouble : promesse à gauche dans un dégradé qui ne déborde plus qu’à gauche, boîte de recherche à droite. Le parcours d’inscription garde son plein écran et borne sa colonne à 760 px |

### Les quatre règles qui tiennent l’ensemble

1. **Toutes les requêtes sont `min-width`.** Le téléphone est le cas par
   défaut, inconditionnel : aucun travail sur grand écran ne peut le casser.
2. **Aucune cible tactile ne rapetisse selon la largeur.** Une tablette de
   900 px se touche avec un pouce ; ce qui dépend du doigt dépend du pointeur,
   donc de `(pointer: fine)`. Le plancher de 44 px reste.
3. **La largeur gagnée sert à montrer plus, jamais à étirer.** `--measure:
   68ch` borne les paragraphes : au-delà d’environ 70 caractères, l’œil perd la
   ligne en revenant à la marge. Une fiche de 1 200 px de large se lit moins
   bien, pas mieux.
4. **Pas de framework CSS.** Les jetons de `tokens.css` reproduisent ceux
   d’`app_colors.dart` ; Tailwind dupliquerait ce système et casserait la
   parité que ce document revendique.

### Deux conflits que l’ouverture a créés, et réglés

- `.appbar` et la nouvelle barre haute étaient **tous deux** `position: sticky;
  top: 0`. Le titre de page, qui porte un `z-index`, recouvrait la navigation au
  défilement. Au-delà de 600 px l’`appbar` redevient statique : sur un
  ordinateur, c’est la navigation qui suit le défilement, pas un titre de page.
- Le `<h1>` d’un cours se retrouvait dans la colonne de 340 px, où 2,5 rem se
  casse sur cinq lignes. Réduit à `--t-title` dans une colonne latérale ; le
  titre complet reste dans l’en-tête de page juste au-dessus.

Et un manque qui n’avait rien à voir avec la largeur : **les résultats de
recherche ne menaient pas à la fiche** du professeur, ajoutée le matin même. On
cherchait, on trouvait, on ne pouvait pas ouvrir.

### Ce qu’aucun test ne prouve

12 tests (`src/styles/responsive.test.ts`) tiennent les règles : deux seuils et
pas trois, aucune `max-width`, aucun `min-height` dans une requête de largeur,
une mesure de lecture sur les paragraphes, les cinq listes en grille, le
programme d’un cours **pas** en grille (ses chapitres sont ordonnés), une seule
`.tabbar` dans le DOM.

**Aucun ne dit que le site est beau à 1 440 px.** Cela se vérifie dans un
navigateur. Playwright a été écarté : une dépendance et un téléchargement de
navigateur de plus sur une machine où la chaîne Android vit déjà hors du dépôt.

---

## Phase 1 — La base partagée

C'est la phase qui décide si « utiliser les deux de la même façon » veut dire
quelque chose. Sans elle, le reste est cosmétique.

### 1.1 — Le client direct · **fait le 25/09**

- `src/api/supabase.ts` — `SupabaseApi`, qui implémente le contrat
  `VeriprofApi` existant. Aucun écran n'a été touché : c'est tout l'intérêt
  d'avoir eu une seule interface depuis le début.
- `src/api/supabase-rows.ts` — la traduction `snake_case` → domaine, isolée
  et **pure**, donc testable sans serveur ni clé.
- `src/api/index.ts` — Supabase si les deux variables sont là, sinon REST,
  sinon le backend simulé. Le mode simulé reste : c'est ce qui permet de
  développer sans serveur.
- `currentSession()` et `logout()` ajoutés au contrat. La session n'est plus
  relue dans `localStorage` mais **demandée à qui de droit** : quand le jeton
  vit chez Supabase, une copie locale diverge dès la première expiration et
  l'application se croit connectée devant un serveur qui la refuse.
- 23 tests sur les traducteurs.

### 1.2 — Ce qu'il reste à faire dans Supabase · **à vous**

1. Créer le projet, relever l'URL et la clé `anon` dans
   *Project Settings → API*.
2. Appliquer les migrations `0001` → `0009` dans l'ordre.
3. Verser le référentiel : `cd backend && npm run seed`, puis coller
   `backend/supabase/seed.sql` dans l'éditeur SQL. **Sans cette étape la base
   est vide et toutes les listes le sont aussi** — sans message, parce qu'une
   liste vide n'est pas une erreur.
4. Activer l'authentification par **courriel** (pas par téléphone), et y
   désactiver la confirmation d'adresse. La confirmation par SMS a été
   retirée le 25/09 : voir le blocage ci-dessous.
5. Renseigner `VITE_SUPABASE_URL` et `VITE_SUPABASE_ANON_KEY`
   (voir `frontend/web/.env.example`).

### 1.3 — La migration `0009`, et pourquoi elle existe · **fait le 25/09**

Trois règles de `0002` fermaient des portes que le produit ouvre. Elles ne
gênaient personne tant qu'un serveur intermédiaire décidait à leur place ;
en accès direct, elles rendent des listes vides.

- `teachers` n'était lisible que par un compte `INSTITUTION`. Or la recherche
  de professeurs est publique dès l'écran d'accueil, et une famille n'est pas
  un établissement.
- `profiles` n'était lisible que par soi-même, et la vue
  `teacher_public_profiles` la joint en `security_invoker` : elle ne rendait
  **rien**, y compris à l'établissement pour qui elle avait été écrite. D'où
  `public_teacher_identities`, qui expose le prénom, le nom et la photo — et
  rien d'autre.
- Les matières, niveaux et certifications suivaient `teachers` : sans eux une
  fiche s'affiche sans ce qui la rend utile.

Ce que `0009` **n'ouvre pas** : téléphone, courriel, diplômes, documents,
expériences. Les coordonnées ne circulent qu'après mise en relation (§30).

`0009` crée aussi la table `favourites`, seule divergence que signalait
`check-schema.mjs` depuis la v19 du mobile. **Les deux schémas concordent
maintenant : 45 tables de chaque côté.**

### 1.4 — Le mobile rejoint la même base · **L** · plus tard

Le mobile reste local-first : c'est une décision prise pour la Guinée, pas un
retard. Il garde donc son SQLite et **synchronise** avec Supabase, au lieu de
l'interroger en direct comme le web. La file d'envoi (`sync_queue`,
`SyncEngine`) existe déjà et attend une adresse.

### 1.5 — Blocage de lancement : il n'y a plus d'authentification

La confirmation par SMS a été retirée des deux clients le 25/09, à la
demande, pour ne pas dépendre d'un fournisseur payant tout de suite. **Ce qui
reste n'authentifie personne.**

- **Mobile** : la connexion se fait sur le numéro seul. Le code ne protégeait
  déjà rien — aucun SMS ne part sans serveur, et l'écran affichait
  « Saisissez le code 123456 pour continuer ». Il demandait de recopier un
  nombre qu'il venait d'écrire.
- **Web** : l'adresse est dérivée du numéro (`22462…@telephone.eduquali.gn`)
  et le mot de passe est une constante écrite dans le bundle.

Dans les deux cas : **quiconque connaît un numéro entre dans le compte qui le
porte.** Ce n'est pas une régression — c'était déjà vrai — mais c'est
désormais visible, ce qui vaut mieux que l'inverse.

Tenable tant que personne de réel n'a de compte. **À remplacer avant la
première inscription d'un vrai utilisateur**, au choix : un fournisseur SMS
(dépense récurrente, à chiffrer), ou un mot de passe choisi à l'inscription
— une question de plus dans un parcours qui en compte onze.

### 1.6 — Deux points à trancher avant l'ouverture

- **Corriger un test dans le navigateur est impossible.** `submitTest` refuse
  explicitement plutôt que de calculer un score côté client : corriger ici
  supposerait d'avoir envoyé les bonnes réponses au navigateur, ce qui vide le
  test de son sens. Il faut une fonction Postgres `security definer`, ou une
  fonction Edge, qui lise `correct_key` côté serveur. En attendant le refus
  est écrit noir sur blanc — un score calculé ici ferait croire à une
  certification qui n'en est pas une.
- **L'inscription fait deux écritures** : le compte d'authentification, puis
  le profil. Un déclencheur SQL les rendrait indissociables ; sans lui, un
  profil qui échoue laisse un compte sans identité. À écrire côté serveur.

### 1.7 — L'assistant IA passe par le serveur · **M**

Contrainte qui ne se négocie pas : **la clé Gemini ne doit jamais se trouver
dans un client**, ni dans l'APK qui circule par Bluetooth, ni dans un bundle
web. Elle reste dans `backend/.env`, jamais préfixée `VITE_`.

Une fois la passerelle serveur écrite, le web est **plus simple** que le
mobile, parce qu'il n'a pas de passerelle de démonstration à défaire. Le
routage de modèle est déjà écrit (`lib/domain/usecases/ai_rules.dart`) :
`gemini-2.5-flash` pour une question, `gemini-3.1-pro` pour un cours ou un
examen.

L'offre payante de Google est obligatoire : sur l'offre gratuite, les données
envoyées servent à améliorer leurs produits, ce qui est inacceptable pour des
photos de devoirs d'enfants.

---

## Phase 2 — Parité de dessin

> La mise en page adaptative est traitée en phase 0ter. Ce qui reste ici est le
> dessin lui-même — composants manquants, accueil, ombres — indépendamment de la
> largeur.

Indépendante du serveur, faisable en parallèle de la phase 1.

### 2.1 — Refaire la page d'accueil · **M**

`screens/Auth.tsx` porte encore le dessin d'avant le 24/09.

| | À retirer | À mettre |
|---|---|---|
| Fond | hero blanc | plein bleu, dégradé `--c-hero-start` → `--c-hero-end` |
| Contenu | aligné en haut | centré, occupant la hauteur disponible |
| Titre | « …qu'il vous faut » | « …qu'il vous faut **pour** », que la bascule complète |
| Choix | cartes « Je suis professeur / Je représente une école » | bascule *Cours à domicile / Embauche* dans la boîte d'action |
| Bas de page | « Se connecter » en lien | **Connexion** (plein blanc) + **Inscription** (contour blanc), décollés du bord |
| Haut de page | — | **Espace professeur**, qui mène à la connexion |
| Mentions | « Aucun compte nécessaire pour regarder », sous-titre « Écoles, universités… » | retirées |

### 2.2 — Compléter la bibliothèque de composants · **L**

13 composants côté web contre 43 côté mobile. À porter dans l'ordre des
besoins des phases suivantes : `GradientHero`, `HeroStatStrip`, `KitCard`,
`ListItemCard`, `ActionCard`, `MetricCard`, `KitGrid`, `KitCarousel`,
`TeacherMiniCard`, `SegmentedToggle`, `StickyActionBar`, `FilterChipsRow`,
`StatRow`, `Band`, `TypeAheadTags`.

Restyler les primitives existantes sur place plutôt que d'en livrer de
nouvelles à côté : renommer `Card` en `NewCard` laisserait les écrans déjà
écrits sur l'ancien dessin pour toujours.

### 2.3 — Ombres et cartes · **S**

Le mobile a reçu `AppShadows.card` sur toutes ses cartes le 26/09. Vérifier
que `--shadow-sm` est appliqué aux mêmes endroits, et nulle part à
l'intérieur d'une carte.

---

## Phase 3 — Porter les fonctions

**À ne commencer qu'après la phase 1.** Ordre choisi par ce qu'un client fait
réellement, pas par facilité d'écriture.

### 3.1 — Tableaux de bord par rôle · **L**
Trois accueils (professeur, famille, établissement) : en-tête dégradé, bande
de chiffres, carrousel des cinq professeurs ou offres en tête, actions
rapides, demandes en attente. Aujourd'hui le web envoie tout le monde sur
`/offres`, y compris une famille qui ne recrute personne.

### 3.2 — Cours à domicile · **lecture faite le 02/10, réservation à faire**

**Fait :** la section « Cours à domicile » sur la fiche publique d'un
professeur — tarif horaire, mode (se déplace / chez lui / en ligne), quartiers
desservis, disponibilités, description. Les offres actives étaient publiques
côté serveur depuis la migration `0002` ; l'écran pour les lire manquait, et on
voyait un professeur de mathématiques sans savoir s'il se déplace ni à quel
tarif. Les quartiers sont l'information la plus concrète pour une famille de
Conakry : ils décident si le professeur peut venir.

Le tarif s'affiche. Le cacher obligerait à écrire pour le demander, ce qui est
exactement le geste qu'on ne veut pas imposer avant d'avoir choisi.

**Reste :** la réservation elle-même, ci-dessous.
Offres d'un professeur, disponibilités, réservation, suivi de la demande.
C'est ce qu'une famille vient chercher, et le web n'en a rien. Reprendre les
règles côté famille : pas de bouton « Contacter » (une famille réserve, elle
ne recrute pas), seuls les professeurs qui se déplacent sont listés, et la
réservation se verrouille en « Ce professeur vous répondra bientôt » tant que
la demande est sans réponse.

### 3.3 — Abonnement et paywall · **M**
Basic / Pro / Master. Porter `subscription_rules.dart` tel quel : la règle
doit vivre à un seul endroit et être appliquée **par le serveur**, pas par le
bouton. La feuille s'ouvre au geste refusé, jamais à l'ouverture d'un écran.

### 3.4 — Messagerie · **M**
Fils parent ↔ professeur et salons de recrutement, avec le masquage des
coordonnées tant que le contact n'est pas ouvert.

### 3.5 — Assistant IA · **M** (après 1.4)
Discussion, construction de cours, correction d'exercices. Le badge de
formule en haut, la feuille d'abonnement au premier geste.

### 3.6 — Contrats, paiements, calendrier · **L**
Contrats et échéances des trois côtés, moyens de paiement, calendrier des
séances.

### 3.7 — Catalogue de cours vidéo · **vitrine faite le 02/10, atelier à faire**
La vitrine côté famille est faite (3.8). Reste l'atelier du professeur : ses
cours, brouillons compris, et la mise en vente. C'est de l'écriture, donc après
que l'authentification soit réglée (1.5).

### 3.8 — Lecteur de cours et chapitres · **vitrine faite le 02/10, lecteur à faire**
Le mobile a pris de l'avance : un cours s'y construit en chapitres, chacun avec
ses vidéos et ses ressources (schéma v23, tables `course_chapters`,
`course_items`, `course_comments` ; migration serveur `0010`). Le lecteur
affiche le sommaire, la vidéo, la description du chapitre dessous et les
commentaires, les réponses du professeur distinguées des autres.

**La vitrine est faite** (`screens/Courses.tsx`, routes `/cours` et
`/cours/:id`) : la liste avec matière, prix, volume et durée, puis le programme
entier — chapitres, titres des vidéos, durées, ressources. Rien n'est caché :
masquer la seconde moitié « pour donner envie » ferait douter qu'il y ait une
seconde moitié. C'est le meilleur argument de téléchargement du site — on lit la
table des matières complète, puis il faut l'application pour regarder.

Trois cours de démonstration vivent dans `shared/seed/catalog.json`, donc dans
les deux clients. Leurs vidéos n'ont **pas** de fichier : un fichier de
démonstration pèserait dans l'APK pour montrer une image noire. Le téléphone
écrit « Bientôt disponible » sur une vidéo sans source, au lieu d'une ligne
grisée sans raison.

Reste à porter :
- Le lecteur : `<video>` suffit, avec le sommaire à gauche au-delà de 600 px et
  dessous en dessous — c'est la règle du mobile, et elle vaut pour une fenêtre
  étroite comme pour un téléphone couché. **À décider d'abord** : si le web lit
  les vidéos, il perd son rôle d'argument de téléchargement.
- Les commentaires, avec le même marquage du professeur du cours : comparer les
  rôles ne suffit pas, un autre professeur qui commente reste un spectateur.
- Le formulaire : un déroulant par chapitre, titre, vidéos, ressources. Le
  dépôt des fichiers passe par Supabase Storage, pas par un chemin local — le
  navigateur n'a pas de dossier privé d'application.

**Le piège est la lecture, pas l'affichage.** `course_items` porte le chemin du
fichier, et la migration `0010` le ferme à qui n'a pas payé : la vitrine passe
par la vue `course_item_titles`, qui rend le titre et la durée sans le fichier.
Un client web qui interrogerait `course_items` directement pour afficher un
programme recevrait zéro ligne — et le réparer en ouvrant la table donnerait le
cours entier avec la clé anonyme, qui est dans le bundle. C'est ce que
`src/api/courses.test.ts` vérifie, sur le client et sur la migration.

### 3.9 — Mise en avant d'un établissement · **lecture faite le 02/10, écriture à faire**
**Fait :** la bande « À la une » sur `/etablissements`, publique, qui mène à la
fiche de l'école. Trois annonces de démonstration vivent dans
`shared/seed/catalog.json`, donc dans les deux clients.

`views` n'est volontairement pas lu : le compteur appartient à l'établissement
qui a payé, et l'exposer laisserait un concurrent mesurer son audience.

**Reste :** le formulaire de création, l'onglet Promotion et ses statistiques,
ouverts par la formule Master.

### 3.10 — Favoris, notifications, mes enfants · **M**

### 3.11 — Vérification d'identité (KYC) · **à décider**
Voir les décisions ouvertes.

---

## Phase 4 — Le filet

### 4.1 — Le lanceur de tests · **fait le 25/09**

Le web n'avait **aucun test** ; le mobile en a 478. Les quatre pannes de la
phase 0 sont précisément le genre de chose qu'un test attrape et qu'une
relecture laisse passer, parce qu'aucune ne lève d'erreur.

Vitest est installé, `npm test` fonctionne, et 23 tests couvrent les
traducteurs de lignes Postgres — la frontière où une colonne mal nommée ne
lève rien, rend `undefined`, et affiche un blanc là où devrait être un nom.

Reste à ajouter Testing Library pour les composants, et à brancher
`test` + `typecheck` + `build` en intégration continue.

### 4.2 — Les règles qui méritent un test · **M**

Une par fichier, nommée d'après la règle :

- les quatre rôles mènent chacun à un parcours qui se charge ;
- `showIf` accepte une réponse multiple ;
- chaque type d'étape déclaré dans le JSON a un rendu ;
- une famille ne voit pas « Contacter » ;
- une fonction payante refusée propose la formule, jamais un message sec ;
- le contraste des paires de couleurs est **calculé**, pas jugé à l'œil.

### 4.3 — Un test de parité du contrat partagé · **S**

C'est la leçon des quatre pannes : le JSON de `shared/onboarding/` est un
contrat entre deux clients, et il a été modifié trois jours de suite sans que
le web suive.

Écrire un test qui lit les fichiers partagés et échoue si un type d'étape, un
`optionsSource` ou un drapeau (`searchable`, `allowCustom`) n'est pas géré par
le client. Le faire tourner **dans les deux clients**.

---

## Décisions ouvertes

1. **Le hors-ligne.** Le mobile fonctionne sans réseau, par construction —
   c'est une décision prise pour la Guinée. Le web ne le fera pas de la même
   façon. Jusqu'où va-t-on : rien, un cache de lecture, ou un service worker
   complet ? Tant que ce n'est pas tranché, « la même chose des deux côtés »
   a une limite qu'il faut dire aux clients.
2. **La vérification d'identité sur le web.** La capture d'un selfie et d'une
   pièce d'identité au navigateur est nettement moins fiable qu'au téléphone.
   Trois options : mobile uniquement, dépôt de fichier sur le web, ou renvoi
   vers le téléphone. Ce choix décide si un professeur peut s'inscrire
   entièrement depuis un ordinateur.
3. **Les notifications.** Push mobile et push web sont deux mécanismes
   différents. Le web se contente-t-il de la cloche dans l'application ?
4. **Le paiement.** Aucun encaissement réel n'existe encore, ni d'un côté ni
   de l'autre. Mobile money d'abord, et nommer les opérateurs (Orange Money,
   MTN MoMo) plutôt qu'un « paiement mobile » générique.
5. **Les chiffres des écrans de valeur — devenu urgent le 02/10.** « 3 000+
   élèves », « 500+ professeurs » sont dans les deux clients via le JSON
   partagé. Cette décision devait être tranchée **avant** d'ouvrir le web à des
   visiteurs ; le web vient de l'être. Un directeur à Conakry peut vérifier ces
   chiffres en une conversation, et une annonce publique est plus facile à
   citer qu'un écran d'inscription. À confirmer ou à remplacer maintenant, pas
   à la prochaine version.

   Même remarque pour les trois annonces d'écoles de démonstration
   (`promotions` dans `shared/seed/catalog.json`) : elles nomment des
   établissements réels — Université Nongo Conakry, Lycée Excellence, Centre de
   Formation Sonfonia — avec des offres inventées. Acceptable dans une
   démonstration interne, **à retirer avant toute mise en ligne publique** :
   une bourse au mérite annoncée au nom d'une école qui ne l'a pas décidée est
   un problème pour elle, pas pour nous.

---

## Pièges connus

| Symptôme | Cause / correctif |
|---|---|
| Un écran d'inscription n'apparaît jamais | `showIf` sur une réponse multiple (0.2), ou un type d'étape non géré rendu `null` (0.3) |
| Le web ne voit pas un compte créé sur le téléphone | Normal tant que le mobile n'a pas rejoint la base (1.4) |
| Toutes les listes du web sont vides | La base Supabase n'a pas recu le referentiel : `npm run seed`, puis `seed.sql` (1.2) |
| Une liste revient vide alors que la table est pleine | Une politique RLS la ferme. En acces direct, un refus se lit comme un resultat vide |
| Le web affiche « Parcours indisponible » | Le role n'a pas d'entree dans `AUDIENCE_BY_ROLE` (0.1) |
| Une écriture part du mobile et n'arrive jamais | Table absente côté serveur — la synchronisation rejette en silence. Lancer `check-schema.mjs` |
| Le web affiche un bandeau « Données de démonstration » | Ni Supabase ni API configures : `MockApi` est actif |
| Un APK demandé en x86_64 sort sans x86_64 | L'exclusion `jniLibs` d'`app/build.gradle.kts` prime sur `--target-platform`, en silence |
| `GeneratedPluginRegistrant.java: cannot find symbol <X>Plugin` | Plugin à implémentation Kotlin dont le `build.gradle` n'applique le plugin Kotlin que sous AGP < 9. Ce projet est en AGP 9.0.1 : les sources Kotlin ne sont jamais compilées. Épingler une version Java du plugin (c'est ce qui est fait pour `file_picker`, en 8.3.7) |
| `repack_apk.py` échoue sur « Signature » | `JAVA_HOME` n'est pas exporté : `apksigner.bat` ne trouve pas `java`. Le script a déjà retiré les symboles — relancer après l'export suffit |
| Un prix s'affiche « GNF100000.00 » | Passer par le formateur partagé : `100 000 GNF`, devise à droite, sans décimale |
| Le programme d'un cours revient vide pour un visiteur | `course_items` est fermée à qui n'a pas acheté. Lire la vue `course_item_titles` (3.8) — jamais la table |
| Un cours vidéo s'ouvre sur un écran vide | Cours d'avant les chapitres : le mobile lui en reconstruit un à l'ouverture, le web devra faire de même ou lire `video_paths` |
| Une carte de professeur s'affiche sans nom | La jointure sur `profiles` est fermée aux visiteurs. Passer par `public_teacher_identities` (0bis) — **jamais** élargir la politique de `profiles`, qui porte le téléphone |
| Un bouton s'enfonce et rien ne se passe | Action qui exige une fiche du compte courant. La remplacer par `AppGate`, pas la désactiver |

---

## Ordre conseillé

```
1.1 client Supabase   ─ fait le 25/09
4.1 lanceur de tests  ─ fait le 25/09
1.3 migration 0009    ─ fait le 25/09

1.2 heberger la base  ─────► a vous : sans elle, rien de ce qui precede ne sert
Phase 0 (4 pannes)    ─ faite le 02/10
Phase 2 (dessin)      ─┐
Phase 2 (dessin)      ─┴───► en parallele, independantes du serveur

Phase 3 (fonctions)   ─────► dans l'ordre 3.1 → 3.10, apres 1.2
1.4 le mobile suit    ─────► quand le web tourne sur la vraie base
Phase 4.2 / 4.3       ─────► au fil de chaque fonction, pas apres
```

Le code du web est prêt à parler à Supabase. **Ce qui manque maintenant est
la base elle-même** (1.2) : tant qu'elle n'est pas hébergée et remplie, le
web retombe sur son backend simulé et rien n'a changé pour un client.

La phase 0 rend au web ce qu'il est censé déjà faire. Tout le reste en
découle.
