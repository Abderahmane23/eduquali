# Déploiement

Purpose : mettre Eduquali en ligne, et le remettre en ligne après une panne.
Audience : développeur, ou responsable technique non développeur.
Last updated : 19/09/2026 — Owner : équipe Eduquali.

Depuis la séparation du 19/09, **le site et l'API sont deux déploiements
distincts**. C'est la contrepartie d'avoir un dossier `backend/` séparé : plus
de mélange, mais deux projets à créer au lieu d'un.

```
eduquali.vercel.app            site web (frontend/web)
        │  appels HTTPS
        ▼
api.eduquali.vercel.app        API REST (backend/)
        │
        ▼
xxxxx.supabase.co            Postgres · Auth (OTP) · Stockage

Eduquali-vX.Y.apk              application mobile, partagée directement
```

---

## 1. Supabase — la base

### 1.1 Créer le projet

1. **supabase.com → Start your project.** Compte GitHub ou courriel ; aucune
   carte bancaire pour l'offre gratuite.
2. **New project** :
   - *Name* : `eduquali` (ou `eduquali-demo` si ce projet sert aux
     démonstrations — voir 1.4, il ne doit pas porter de vrais comptes).
   - *Database password* : généré, **à conserver**. C'est le mot de passe
     Postgres, pas une clé d'API ; il ne se relit jamais ensuite et sert aux
     connexions directes (`psql`, sauvegardes).
   - *Region* : **West EU (Ireland)** ou **Frankfurt** — les plus proches de la
     Guinée dans l'offre gratuite. La région ne se change pas après coup.
3. Attendre deux minutes que le projet se provisionne.

**Ce que l'offre gratuite donne, et ses deux limites qui comptent :** 500 Mo de
base, 1 Go de stockage, 50 000 comptes actifs par mois — largement au-delà des
besoins d'un lancement. Mais : **le projet se met en pause après 7 jours sans
requête**, et toutes les requêtes échouent alors jusqu'à sa réouverture depuis
le tableau de bord. Et il n'y a **pas de sauvegarde automatique** : une base de
production a besoin d'une sauvegarde planifiée, ou de l'offre payante.

### 1.2 Le schéma

**SQL Editor → New query**, coller le contenu de `eduquali_schema.sql`
(racine du dépôt), puis **Run**. Compter une dizaine de secondes.

Ce fichier est **généré** à partir des migrations, et c'est voulu : les
migrations sont la vérité et une copie saisie à la main serait une source de
plus, qui divergerait sans que rien ne le dise. Pour le régénérer après une
nouvelle migration :

```bash
cd backend && npm run schema:file
```

> **Sur un projet déjà en service, ne pas coller ce fichier.** Il rejoue les
> dix-sept migrations depuis le début. Appliquer seulement la migration
> manquante, depuis `backend/supabase/migrations/`.

#### Vérifier avant de coller

```bash
cd backend && npm run check:db
```

**Ce contrôle exécute réellement les dix-sept migrations**, dans l'ordre, sur un
vrai Postgres — PGlite, le moteur compilé en WebAssembly, donc sans Docker ni
service à lancer. Il affiche le temps de chaque migration, puis ce que la base
contient (tables, vues, politiques, fonctions, index), et il vérifie cinq
invariants qu'on ne peut constater qu'en exécutant : l'index partiel de présence,
le calcul des minutes de `attendance_detail`, le respect du nombre de places par
`claim_session_seat`, la contrainte d'achat polymorphe, et `auth.uid()`.

C'est le contrôle qui manquait. Les deux autres (`check:sql`,
`check:schema-file`) lisent le texte sans exécuter une ligne : **pendant les
dix-sept premières migrations, personne n'a jamais su si le schéma démarre**, et
on ne l'apprenait qu'en collant le fichier ici, une fois, à la main. Une seule
faute de frappe laisse alors la base à moitié créée.

Sur une erreur, il nomme le fichier, la ligne, la colonne et montre le contexte,
puis s'arrête — les migrations suivantes dépendent de celle qui a échoué et leurs
erreurs en cascade masqueraient la cause.

> **Ce qu'il ne vérifie pas :** qu'une politique RLS ferme bien ce qu'elle doit
> fermer. `auth.uid()` est ici une valeur de session posée par le banc d'essai,
> pas une revendication extraite d'un JWT. Éprouver les politiques demande de
> vrais comptes et de vrais jetons, donc un projet Supabase jetable. Voir
> l'en-tête de `backend/supabase/harness/00_supabase_shim.sql`, qui le dit aussi.

> **Deux nombres de tables, tous les deux justes.** `check:schema-file` annonce
> 54 tables déclarées, `check:db` en trouve 53 dans la base construite :
> `credit_ledger` est créée en 0001 et supprimée en 0008, quand le système de
> crédits a laissé la place aux formules. Le premier compte les `create`, le
> second décrit ce qui reste.

### 1.3 Le référentiel

**Deux fichiers, dans cet ordre.** Le second dépend du premier.

**1. `backend/supabase/seed.sql`** — le référentiel et la démonstration : les
25 matières, les 16 classes avec leur cycle, les 5 paliers, les 8 tests et leurs
282 questions, les 6 établissements et les 17 offres.

**2. `backend/supabase/seed_curriculum.sql`** — le programme scolaire guinéen :
348 chapitres et 1 228 sous-chapitres pour 14 matières et 7 classes, plus
13 manuels et 16 sources. Il cite les matières et les classes du premier par clé
étrangère, donc il échoue si on l'applique seul.

Les deux sont **rejouables** : leurs `on conflict` mettent à jour au lieu
d'échouer, donc on les repasse sur une base en service quand le catalogue ou le
programme change.

À régénérer après toute modification du catalogue partagé ou des fichiers de
`ressource_matières/` :

```bash
cd backend && npm run seed          # les deux fichiers
node ../shared/curriculum/build.mjs # si ressource_matières/ a changé
```

> **Le programme n'est pas une publication officielle du ministère.** Les sources
> consultées ne contiennent aucun document ministériel unique couvrant toutes les
> matières et toutes les classes. Chaque chapitre porte son `content_status` et sa
> source, les deux clients affichent l'avertissement, et `sync.mjs` échoue si
> quelqu'un le retire.

### 1.4 Les comptes de démonstration — optionnel

`seed.sql` s'arrête là où commence l'authentification. `teachers.user_id` est
`not null references profiles (id)`, et `profiles.id` référence
`auth.users (id)` : **une fiche de professeur ne peut pas exister sans compte**,
et un compte ne se crée pas en SQL. Sans l'étape ci-dessous, le site affiche un
référentiel complet et **aucun professeur** — ni fiche, ni cours à domicile, ni
cours vidéo. Il a l'air cassé alors qu'il est seulement vide.

```bash
cd backend
# SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY dans backend/.env (voir 1.7)
node scripts/seed-demo-accounts.mjs
```

Trente professeurs avec leur parcours et leurs certifications, leurs trente
offres de cours à domicile, trois cours vidéo avec leurs chapitres, trois mises
en avant d'établissements. Le script est idempotent : un deuxième appel met à
jour au lieu d'empiler.

> **À ne pas lancer sur la base qui portera de vrais comptes.** Les professeurs
> sont inventés et leurs parcours nomment des établissements réels ; les mises
> en avant annoncent des bourses que personne n'a décidées.

### 1.5 Authentification

**Authentication → Providers → Email** :

- **Désactiver « Confirm email ».** Ce n'est pas un détail de confort :
  l'inscription du site appelle `signUp()` puis insère la ligne `profiles`, et
  la politique de cette table exige `id = auth.uid()`. Confirmation activée,
  `signUp()` ne rend aucune session, `auth.uid()` est nul, l'insertion est
  refusée — **le compte d'authentification existe sans profil**, et la personne
  ne peut ni entrer ni recommencer : son numéro est déjà pris.
- Laisser « Enable email provider » actif. Le site n'utilise pas de courriel
  réel : il déduit un identifiant du numéro
  (`224620000101@telephone.eduquali.gn`). Il n'y a aucune boîte derrière.

**Phone / SMS : rien à brancher pour l'instant.** La confirmation par SMS a été
retirée des deux clients.

### Un mot de passe, choisi par la personne (02/10)

Le parcours demande un mot de passe juste après le numéro — étape
`credentials`, dans les quatre profils, donc dans le JSON partagé : les deux
clients la lisent, aucun ne peut l'oublier de son côté. Huit caractères au
minimum, vérifiés à la saisie **et** dans les dépôts, parce qu'un refus après
coup laisserait un numéro pris sans compte utilisable.

Ce qui a disparu : le mot de passe partagé écrit en clair dans le code, et la
connexion sur le numéro seul (`signInWithPhone`, retirée et non conservée « au
cas où » — une fonction qui ouvre une session sur un numéro se recâble en une
ligne).

Deux défauts que ce travail a mis au jour :

- Un compte **parent** n'avait aucune empreinte de mot de passe : il se créait
  et ne pouvait plus jamais s'ouvrir. Les comptes étudiants passent par la même
  fonction.
- La contrainte `profiles_role_check` ne connaissait pas `STUDENT`, alors que
  les quatre profils sont proposés depuis le 24/09. Migration `0011`.

> **L'OTP par SMS reste souhaitable**, et n'est pas remplacé par ceci : un mot
> de passe protège un compte, il ne prouve pas que le numéro appartient à la
> personne. Les deux sont complémentaires. Quand un fournisseur sera branché,
> c'est `verifyOtp` qu'il faudra écrire.

> **Les comptes créés avant le 02/10 n'ont pas de mot de passe.** Ils passent
> par « Mot de passe oublié » pour en poser un. Sur une base de démonstration,
> le plus simple est de relancer `npm run seed:accounts`, qui pose celui
> qu'il affiche.

### 1.6 Stockage

**Storage → New bucket** : `documents`, **privé**. Il recevra selfies, pièces
d'identité et diplômes. Ne jamais le rendre public — et ne pas cocher « Public
bucket » pour « voir si ça marche » : un bucket public laisse lire tout ce
qu'il contient à qui devine une URL.

### 1.7 Les clés

**Project Settings → API** :

| Clé | Où elle va | Risque |
|---|---|---|
| `Project URL` | partout | aucun, c'est une adresse |
| `anon` | `frontend/web/.env`, préfixée `VITE_` | **publique par construction** : elle part dans le bundle. Ce n'est pas elle qui protège les données, c'est RLS, table par table |
| `service_role` | `backend/.env`, **nulle part ailleurs** | passe outre RLS et donne accès à tout. Jamais dans un bundle, jamais dans un APK, jamais dans le dépôt. Si elle fuit : la régénérer immédiatement |

## 2. Backend — l'API

```bash
cd backend
npm install
npm test          # 65 tests, sans infrastructure
vercel            # premier déploiement : crée le projet
vercel --prod
```

Variables d'environnement (**Settings → Environment Variables**) :

| Variable | Valeur | Remarque |
|---|---|---|
| `SUPABASE_URL` | Project URL | |
| `SUPABASE_ANON_KEY` | clé `anon` | |
| `SUPABASE_SERVICE_ROLE_KEY` | clé `service_role` | **secret** |
| `ALLOWED_ORIGINS` | `https://eduquali.vercel.app` | sans elle, le navigateur bloque le site |
| `GEMINI_API_KEY` | clé Google Gemini, **offre payante** | jamais côté client |
| `AI_MONTHLY_BUDGET_USD` | `50` | au-delà, l'IA se met en pause |

## 2bis. Encaissement — Djomy

### Deux comptes, deux cibles de déploiement

Djomy délivre un `clientId` et un `clientSecret` par environnement. Les deux
jeux ne se mélangent pas, et le Worker a deux cibles pour les tenir séparés :

| Cible | Commande | Encaisse |
|---|---|---|
| Bac à sable | `wrangler deploy` | rien de réel |
| Production | `wrangler deploy --env production` | de l'argent |

**Les secrets sont par cible.** Il faut donc deux passes, et un secret posé une
seule fois ne vaut que là où il a été posé — c'est précisément ce qui empêche un
jeu de clés de fuir d'un environnement à l'autre :

```bash
cd backend

# Bac à sable
wrangler secret put DJOMY_BASE_URL
wrangler secret put DJOMY_CLIENT_ID
wrangler secret put DJOMY_CLIENT_SECRET
wrangler secret put DJOMY_WEBHOOK_SECRET

# Production
wrangler secret put DJOMY_BASE_URL       --env production
wrangler secret put DJOMY_CLIENT_ID      --env production
wrangler secret put DJOMY_CLIENT_SECRET  --env production
wrangler secret put DJOMY_WEBHOOK_SECRET --env production
```

`DJOMY_ENVIRONMENT` **n'est pas un secret** : il est dans `[vars]` de
`wrangler.toml`, une valeur par cible, lisible dans le fichier. Savoir laquelle
encaisse pour de vrai doit se lire sans interroger Cloudflare.

> **Il n'a pas de valeur par défaut, et c'est voulu.** « production » par défaut
> facturerait de vrais clients depuis un poste de développement ; « sandbox » par
> défaut laisserait une mise en ligne encaisser dans le vide pendant des
> semaines. Les deux erreurs sont silencieuses : on ne les découvre qu'en
> cherchant l'argent. Des clés sans environnement déclaré désactivent donc
> l'encaissement, avec un message dans les journaux.
>
> Il n'est pas non plus déduit de l'URL. Chercher « sandbox » dans le nom d'hôte
> serait la bonne façon de se tromper le jour où l'hôte de test ne porte pas ce
> mot.

### Vérifier laquelle est active

```bash
curl https://<worker>/api/v1/health
# → {"status":"ok","database":"configured",
#    "payments":{"configured":true,"environment":"sandbox"}}
```

C'est le seul endroit où cela se voit côté serveur. Côté acheteur, un paiement
de bac à sable porte un bandeau « Paiement de test : aucun argent n'est prélevé
ni reçu » — y compris quand il réussit, parce que c'est là que la confusion
coûte cher.

### Le webhook

Dans l'espace développeur Djomy, pointer l'URL sur :

```
https://<worker>/api/v1/payments/djomy/webhook
```

Une URL par environnement, chacune vers sa cible. La signature est vérifiée sur
le **corps brut** (`X-Webhook-Signature: v1:<hmac>`) et les doublons sont
écartés par `event_id` : Djomy réessaie ce qui n'a pas répondu 200, et un
réessai ne doit pas créditer deux fois.

### Ce qui reste à confirmer au premier appel

Le document d'API fourni s'arrête avant les schémas de réponse. Trois noms de
champs sont donc des hypothèses, regroupées dans la constante `CHAMPS` en tête
de `api/_lib/djomy.ts` — une correction tient en une ligne :

| | |
|---|---|
| le jeton rendu par `POST /v1/auth` | `accessToken`, `access_token`, `token`, `jwt` |
| l'identifiant de transaction | `transactionId`, `transaction_id`, `id`, `reference` |
| l'URL de redirection (portail, Kulu) | `paymentUrl`, `redirectUrl`, `paymentLink`, `url` |

Le module accepte plusieurs orthographes plutôt que d'en parier une. Manquent
aussi la durée de vie du jeton — d'où le renouvellement sur 401 plutôt que sur
une horloge — et l'URL de base, qui vient de la configuration.

### Payer les professeurs

Les points d'entrée `topups` acceptent une **preuve de virement bancaire**
(JPG/PNG/PDF, 5 Mo). Autrement dit les reversements tirent sur un solde Djomy
que l'on alimente par virement, et non sur l'argent qui vient d'être encaissé :
vous collectez 100 %, puis il faut avoir approvisionné le solde séparément pour
reverser les 80 %. Les payouts sont plafonnés à **5 bénéficiaires par ordre**,
donc payer trente professeurs fait six appels. À confirmer avec Djomy — cela
change la trésorerie, pas seulement le code.

---

## 2ter. Visioconférence et vidéo — LiveKit, R2 et Stream

Trois services : LiveKit pour la salle (retenu le 02/10), Cloudflare R2 et
Cloudflare Stream pour l’enregistrement et la rediffusion (03/10, en
remplacement de Bunny).

### 2ter.1 LiveKit Cloud — les cours en direct

**Pourquoi lui :** serveur de diffusion sélective. Il n'envoie à chaque élève
que ce que sa connexion supporte, et dégrade le flux plutôt que de le couper.
Sur une ligne guinéenne, c'est ce qui décide si un cours a lieu. Une
architecture en maillage demanderait à un élève de téléverser quatorze flux :
impossible ici.

1. Créer un projet sur **cloud.livekit.io**. Région : **Europe**.
2. **Settings → Keys** : relever l'URL `wss://<projet>.livekit.cloud`, la clé et
   le secret.
3. Poser les trois secrets, pour les deux cibles (voir 2bis pour le principe des
   deux passes).

> **LiveKit n'a aucune notion de compte.** Il fait confiance au jeton JWT que
> nous signons avec le secret du projet. **Tout le contrôle d'accès à une classe
> payante est donc chez nous**, et c'est une responsabilité, pas une commodité.
>
> Le point d'entrée `POST /live/sessions/:id/token` fait quatre vérifications,
> et aucune n'est superflue : le compte existe, l'élève est **inscrit et payé**,
> on est dans la fenêtre de la séance (quinze minutes avant, trente après), et
> le rôle décide des droits. Un élève n'a pas le droit de publier d'emblée — il
> demande la parole. Donner caméra et micro à quinze adolescents dès l'entrée
> rend le cours impossible à tenir.

### 2ter.2 Cloudflare Stream — les cours enregistrés

**Pourquoi lui, et pourquoi plus Bunny (03/10) :** il transcode, comme Bunny — une
vidéo devient plusieurs débits servis en HLS, et le lecteur prend celui que la
ligne supporte. Ce qui a fait changer, ce n'est pas le prix mais **le réseau** :
R2 et Stream sont chez le même fournisseur, donc faire passer un enregistrement
de l'un à l'autre ne traverse pas Internet et ne coûte pas d'egress. Et c'est un
fournisseur de moins : une facture, un jeton, une console et un incident possible
en moins.

1. Tableau de bord Cloudflare → relever l'**identifiant de compte** (colonne de
   droite).
2. **My Profile → API Tokens → Create Token** : permission **« Stream : Edit »**
   et rien d'autre. Un jeton global donnerait aussi accès au DNS et aux Workers.
3. **Stream** → ouvrir n'importe quelle vidéo → relever le **code client** du
   code d'intégration, `customer-xxxxxxxx`.
4. Poser les trois secrets, pour les deux cibles (voir 2bis).

> ### Les URL de lecture sont signées par construction
>
> RLS protège la **ligne** d'un cours en base. Elle ne protège pas un fichier
> servi par un réseau de diffusion : une adresse publique se copie dans un groupe
> WhatsApp et tout le catalogue circule en une soirée.
>
> Chaque vidéo est ingérée avec `requireSignedURLs: true`. Le serveur demande un
> jeton de lecture **après** vérification de l'achat, et il expire au bout de
> quatre heures.
>
> **Il n'y a pas de réglage à activer ni à oublier.** C'est le progrès par rapport
> à Bunny, où la protection était une option de zone : le serveur devait
> journaliser un avertissement à chaque démarrage tant qu'elle manquait, et un
> oubli rendait tout le catalogue gratuit.

### 2ter.3 Les enregistrements de séances

L'egress de LiveKit produit un `.mp4` monolithique et n'écrit que vers du
stockage compatible S3 — **jamais vers un service de diffusion**. Le chemin est
donc en deux temps :

```
LiveKit (egress)  ──►  Cloudflare R2  ──►  Cloudflare Stream  ──►  HLS 360-1080p
```

**Pourquoi ne pas servir le `.mp4` directement depuis R2 :** un fichier
monolithique se télécharge au débit du fichier, pas du réseau. Sur une ligne
guinéenne, le lecteur s'arrête à chaque creux. Stream démarre sur un fragment de
deux secondes très compressé et **dégrade la qualité au lieu de s'interrompre**.
C'est la différence entre « le cours se revoit » et « le cours se revoit chez
quelqu'un qui a la fibre ».

1. **R2 → Create bucket** : un dépôt pour les enregistrements.
2. **R2 → Manage API Tokens → Create token** : portée **« Object Read & Write »**
   sur ce seul dépôt.
3. Point d'entrée : `https://<identifiant de compte>.r2.cloudflarestorage.com`.
   Région : **`auto`**, toujours.
4. Variables `R2_*`.

> **Le dépôt reste privé.** Le serveur donne à Stream une URL pré-signée valable
> deux heures, le temps de l'ingestion. Un dépôt public économiserait cinquante
> lignes de signature et rendrait chaque séance de 90 minutes téléchargeable par
> qui devine un nom de fichier — et un nom dérivé d'un identifiant de séance se
> devine.
>
> Le `.mp4` brut est supprimé après ingestion : Stream sert désormais la vidéo, et
> le fichier d'origine ne se relit jamais. Sans ce nettoyage, les 10 Go gratuits
> de R2 sont atteints en deux semaines de cours.

### 2ter.4 Vérifier ce qu'un déploiement sait faire

```bash
curl https://<worker>/api/v1/health
# → {"status":"ok","database":"configured",
#    "payments":{"configured":true,"environment":"sandbox"},
#    "live":{"configured":true},
#    "video":{"configured":true,"provider":"cloudflare-stream","signedUrls":true},
#    "recording":{"configured":true,"storage":"configured"},
#    "aiSummary":"configured"}
```

`"recording":{"configured":false}` veut dire qu'une séance aura lieu mais ne
laissera **pas** de rediffusion : il faut les trois à la fois — la salle, le dépôt
R2, l'hôte vidéo. Découvrir cela une semaine plus tard, quand un élève réclame la
rediffusion d'un cours payé, coûte la confiance d'une famille.

Découvrir qu'une salle ne s'ouvre pas au moment du premier cours coûte une classe
entière : cette lecture est à faire après chaque déploiement.

### 2ter.5 Ce qui reste à confirmer au premier appel réel

Comme pour Djomy, quelques noms de champs sont des hypothèses, rassemblées dans
une constante `CHAMPS` en tête de chaque module pour qu'une correction tienne en
une ligne :

| | |
|---|---|
| `api/_lib/stream.ts` | l'identifiant d'une vidéo dans la réponse de `copy` — `uid` |
| `api/_lib/stream.ts` | le champ d'état du traitement — `status.state` |

Le passage de Bunny à Stream a **supprimé la plus risquée de ces hypothèses** :
la chaîne à signer pour un jeton de lecture. Chez Bunny il fallait la calculer à
la main (`SHA256(tokenKey + videoId + expiration)`), avec un mode « chemin » qui
changeait la formule — une note « ⚠ à vérifier au premier appel réel » traînait
dans le module. Stream émet le jeton par API : il n'y a plus de formule à se
tromper.

Une première ingestion suivie d'une lecture règle les deux champs restants d'un
coup.

---

## 3. Site web

```bash
cd frontend/web
npm install
npm run build
vercel --prod
```

Une seule variable : `VITE_API_BASE_URL` = l'URL de l'API suivie de `/api/v1`.

> **Tout ce qui commence par `VITE_` est écrit en clair dans le code du site.**
> N'y mettre jamais une clé d'API. Laisser la variable vide fait tourner le
> site sur son backend simulé, utile pour une démonstration.

## 4. Application mobile

```bash
cd frontend/mobile
# Les deux variables sont hors du depot : sans elles, Gradle ne demarre pas, et
# `repack_apk.py` echoue a la signature sans avoir perdu son travail.
export JAVA_HOME="<racine du JDK>"
export ANDROID_SDK_ROOT="<racine du SDK Android>"

flutter build apk --release \
  --target-platform android-arm,android-arm64 \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...

python tools/repack_apk.py build/app/outputs/flutter-apk/app-release.apk
```

**Les deux `--dart-define` relient le téléphone au même compte que le site**
(02/10) : l'identifiant d'un compte vient alors de Supabase, et la base locale
le recopie. Sans eux, l'APK fonctionne exactement comme avant, entièrement en
local — utile pour une démonstration, mais un compte créé sur le téléphone ne
se retrouve alors pas sur le site.

> **La clé anonyme dans l'APK ne pose pas de problème.** Elle est publique par
> construction : le site l'envoie à chaque visiteur dans son bundle, et ce n'est
> pas elle qui protège les données — c'est RLS. La règle « aucune clé dans
> l'APK » vise la clé Gemini et la clé `service_role`, qui donnent accès à tout.

Ce que le téléphone demande à Supabase se limite à l'identité : trois appels
HTTP via Dio (`supabase_auth_api.dart`), et non le paquet `supabase_flutter` —
celui-ci tire `app_links`, dont les sources Kotlin ne compilent pas sous AGP 9
(voir les problèmes fréquents). Les données métier continuent de vivre dans
SQLite.

Les deux architectures sont nécessaires : un APK 64 bits seul refuse de
s'installer sur les téléphones 32 bits, avec un simple « Application non
installée » et aucune explication.

**L'étape `repack_apk.py` n'est pas optionnelle.** Sans NDK installé, Gradle ne
peut pas retirer les symboles de débogage : l'APK pèse alors **358 Mo au lieu de
77,8 Mo** (mesuré sur 1.12.0, le 03/10).

`repack_apk.py` a besoin de **`JAVA_HOME` autant que d'`ANDROID_SDK_ROOT`** : il
allège et réaligne sans, puis échoue à la dernière ligne sur `apksigner sign`,
qui est un programme Java. Le message d'erreur s'affiche *au-dessus* de la
progression, ce qui le fait lire comme si l'allègement avait échoué.

Compter **environ 17 minutes** pour `assembleRelease`.

### Deux versions, deux commandes

**Version de test — celle qui circule par Bluetooth ou Xender.** Aucun serveur
n'est indiqué : l'application travaille entièrement sur l'appareil.

```bash
flutter build apk --release --target-platform android-arm,android-arm64
```

Sans `ACALIA_API`, l'application ne sonde aucun serveur, n'attend jamais au
démarrage, et le code unique hors ligne ouvre les comptes. C'est le
comportement voulu tant que l'API n'est pas en ligne : une adresse inventée
ferait patienter l'utilisateur toutes les 45 secondes devant un serveur qui
n'existe pas.

**Version publiée**, une fois l'API déployée :

```bash
flutter build apk --release \
  --dart-define=ACALIA_API=https://<api>/api/v1 \
  --dart-define=OFFLINE_OTP=false \
  --target-platform android-arm,android-arm64
```

`OFFLINE_OTP=false` coupe le code de secours. Même sans cela, le code unique
est refusé dès que le serveur répond — mais un cran de plus ne coûte rien sur
la porte d'entrée des comptes.

| Réglage | Test | Publié |
|---|---|---|
| `ACALIA_API` | absent | l'adresse de l'API |
| `OFFLINE_OTP` | `true` (défaut) | `false` |
| Bandeau réseau | masqué | affiché selon l'état |
| Synchronisation | file locale, inerte | active |

Ce que la version de test fait **sans serveur** : créer un compte des trois
profils, remplir le parcours d'inscription, publier une offre, réserver un
professeur à domicile, inscrire un enfant, construire un cours avec
l'assistant de démonstration et le télécharger en Word. Rien de tout cela
n'attend le serveur.

Ce qu'elle ne fait pas : envoyer un vrai SMS, synchroniser entre deux
téléphones, appeler Gemini. Ces trois-là demandent l'API, et l'écran
« Synchronisation » le dit en clair.

### Si le démon Gradle disparaît en cours de route

```
Gradle build daemon disappeared unexpectedly
../../runtime/vm/os_thread.cc: error: Could not start thread DartWorker: 22
```

La machine n'a plus assez de threads ou de mémoire — c'est arrivé après
plusieurs compilations enchaînées. Arrêter les démons, puis brider la
compilation :

```bash
cd android && ./gradlew --stop
export GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx2g -Dorg.gradle.workers.max=2"
```

### Si Gradle refuse de supprimer un dossier

```
Execution failed for task ':app:stripReleaseDebugSymbols'
> Unable to delete directory '...stripped_native_libs...'
```

Un démon Gradle d'une compilation précédente tient encore `libflutter.so`.
Arrêter les démons, puis effacer le dossier :

```bash
cd android && ./gradlew --stop
rm -rf build/app/intermediates/stripped_native_libs
```

### Et iOS ?

Pas depuis une machine Windows : compiler pour iOS exige Xcode, qui n'existe
que sur macOS. Le code Dart, lui, est portable — les dix greffons natifs du
projet déclarent tous iOS, et `lib/` ne contient aucune particularité Android.

Le blocage réel n'est pas la compilation, c'est la distribution. L'APK se
partage par Bluetooth et s'installe sur un téléphone neuf ; iOS n'a pas
d'équivalent. App Store et TestFlight demandent un compte développeur à
99 $/an et une revue Apple ; l'installation Ad Hoc plafonne à 100 appareils,
chaque identifiant matériel étant enregistré à la main. Tant que la
distribution se fait de main en main, Android est la seule voie.

## 5. Vérifier après déploiement

```bash
curl https://<api>/api/v1/health
# → {"status":"ok","database":"configured"}

curl https://<api>/api/v1/subjects
```

Puis, depuis le site en ligne : la page se charge, la connexion répond, une
offre s'affiche. Si `database` vaut `missing`, les variables Supabase ne sont
pas visibles par la fonction.

## 6. Revenir en arrière

Vercel garde chaque déploiement : **Deployments → … → Promote to Production**
sur la version précédente. Une migration SQL, elle, ne se défait pas toute
seule — d'où la règle : une migration n'est jamais modifiée après avoir été
appliquée, on en ajoute une nouvelle.

---

## Points de vigilance

**Le projet Supabase se met en pause** après une période d'inactivité sur
l'offre gratuite. Il redémarre à la première requête, mais celle-ci est lente :
réveiller le projet avant une démonstration.

**La clé `service_role` contourne toutes les règles d'accès.** Si elle fuit, la
régénérer immédiatement depuis le tableau de bord Supabase.

**L'APK est signé avec la clé de débogage.** Il faut une vraie clé de
publication avant toute diffusion large : en changer plus tard oblige chaque
utilisateur à désinstaller puis réinstaller.

**Les documents d'identité ne devraient pas rester sur une offre gratuite.**
Le §52 demande une analyse juridique guinéenne avant toute mise en production.

## Problèmes fréquents

| Symptôme | Cause / correction |
|---|---|
| Le site affiche les données de démonstration | `VITE_API_BASE_URL` vide ou absente au moment du build |
| Appels bloqués par le navigateur (CORS) | `ALLOWED_ORIGINS` ne contient pas l'URL exacte du site |
| `database: missing` sur `/health` | variables Supabase absentes du projet Vercel |
| APK de ~340 Mo | l'étape `repack_apk.py` a été sautée |
| `GeneratedPluginRegistrant.java: cannot find symbol <X>Plugin` | Un plugin à implémentation Kotlin dont le `build.gradle` n'applique le plugin Kotlin que si AGP est antérieur à 9. Ce projet est en AGP 9.0.1 : ses sources Kotlin ne sont jamais compilées. Épingler une version Java du plugin — c'est pourquoi `file_picker` est figé en 8.3.7 et non en 11.x |
| `repack_apk.py` : « échec … apksigner.bat sign » | `JAVA_HOME` n'est pas exporté dans le shell. Le script a déjà allégé les bibliothèques : exporter puis relancer suffit, inutile de rebâtir |
| « Application non installée » sur un téléphone | APK 64 bits seul : rebâtir avec les deux architectures |
| L'application semble inchangée après mise à jour | données de l'ancienne version encore présentes : effacer les données de l'application |
