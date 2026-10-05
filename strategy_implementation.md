# Mise en œuvre de la stratégie

Purpose : traduire [strategy.md](strategy.md) en tâches exécutables sur le code
existant.
Audience : développeurs.
Last updated : 02/10/2026 — Owner : équipe Eduquali.

Chaque tâche est découpée en quatre volets :

| Volet | Ce qu'il couvre |
|---|---|
| **Fonctions** | logique métier : dépôts, cas d'usage, points d'entrée serveur |
| **Éléments** | écrans et composants à créer ou modifier, dans les deux clients |
| **UX / UI** | ce que la personne voit et comprend, et pourquoi |
| **Base** | tables, colonnes, politiques RLS, migrations |

L'ordre est un ordre de **dépendance**, pas de préférence : chaque tâche
s'appuie sur les précédentes.

---

## Ce qui existe déjà et qu'on réutilise

Rien de ce qui suit n'est à écrire : c'est l'inventaire de ce sur quoi on
s'appuie.

| Besoin de la stratégie | Ce qui existe |
|---|---|
| Vendre et encaisser | `course_purchases` + Djomy (`_lib/djomy.ts`), états `PENDING`/`PAID` |
| Lecteur vidéo et chapitres | `course_player_page.dart`, `course_chapters`, `course_items` |
| Commentaires sous une vidéo | `course_comments` |
| Comptes, rôles, identité partagée | Supabase Auth + `profiles`, mot de passe choisi |
| Messagerie et notifications | `conversations`, `messages`, `notifications` |
| Dépôt de photos | `document_pipeline.dart` (CV, diplômes) — à étendre aux devoirs |
| Tests et banques de questions | `tests`, `test_questions`, `test_sessions` |
| Programme officiel guinéen | `shared/curriculum/guinea.json` |

**Ce qui n'existe nulle part :** la visioconférence, un planning de créneaux
récurrents, la présence en direct, les points, et la correction de devoirs.

---

## Décision bloquante, avant la phase B

**Quel fournisseur de visioconférence ?** C'est la seule décision dont tout le
reste du produit en direct dépend, et elle n'est ni dans le dépôt ni dans la
stratégie.

Recommandation : **LiveKit Cloud**. Serveur de diffusion sélective — il n'envoie
à chaque élève que ce que sa connexion supporte, ce qui compte plus que tout le
reste en Guinée. SDK Flutter et web. Enregistrement natif vers un stockage S3,
donc vers **Cloudflare R2**, déjà recommandé pour la vidéo. Offre gratuite pour
démarrer.

Ordre de grandeur du coût, aux tarifs habituels de ~1 $ / 1 000 minutes
participant : une séance de 90 min à 15 élèves fait 1 350 minutes participant ;
8 séances par semaine font environ **47 000 minutes par mois et par professeur,
soit ~47 $**. En face, le même professeur rapporte à la plateforme 8 × 15 ×
40 000 × 40 % ≈ **1,9 million GNF par semaine**. Le coût vidéo est marginal.

> ⚠ **Vérifier le `android/build.gradle` du SDK avant de s'engager.** Ce projet
> compile avec AGP 9, et tout greffon dont les sources Kotlin sont conditionnées
> à `AGP < 9` ne compile pas : le build échoue au bout de huit minutes sur un
> `GeneratedPluginRegistrant` qui ne trouve pas une classe. C'est arrivé deux
> fois (`file_picker`, épinglé en 8.3.7 pour cette raison). Repli si le SDK est
> incompatible : ouvrir la salle dans une `WebView` vers l'application web — pas
> de code natif, donc pas de risque, au prix d'un contrôle moindre sur la
> qualité.

**Deux bonnes nouvelles qui évitent de l'infrastructure :**

- **Supabase Realtime Presence** répond exactement au besoin « le parent voit en
  direct si son enfant suit un cours » et au bouton « lever la main ». Pas de
  table, pas de serveur : un canal par séance. Déjà disponible côté web via
  `@supabase/supabase-js`.
- Côté Flutter, le paquet `realtime_client` est **du Dart pur** : aucun code
  natif, donc aucun risque AGP.

---

# Phase A — Vendre mieux ce qui existe déjà

Aucune visioconférence, aucun nouveau concept lourd. C'est la recette la plus
rapide, et elle finance le reste.

## A1. Le pass brevet — 50 000 GNF, 24 heures, tout le catalogue

**Fonctions**
- `AccessPassRepository` : ouvrir un pass, calculer `expires_at = now + 24 h`,
  dire si un pass est actif.
- Serveur : étendre `POST /purchases` pour accepter un `passId` au lieu d'un
  `courseId` — même chemin Djomy, même webhook, même idempotence.
- Fonction SQL `has_active_pass()` à ajouter à côté de `has_bought_course()`.

**Éléments**
- Web : une carte « Révisions brevet » en tête de `/cours`, et une page
  `/cours/brevet` listant les matières couvertes.
- Mobile : la même entrée dans `catalog_page.dart`.

**UX / UI**
- Le compte à rebours est l'information centrale : **« il vous reste 19 h 40 »**,
  pas une date. Un pass de 24 h sans décompte visible se perd.
- Dire ce qui est couvert avant l'achat — les quatre matières, le nombre de
  vidéos — parce que 50 000 GNF pour « tout » ne veut rien dire.

**Base**
- `access_passes` : `id`, `parent_id`, `kind` (`BREVET_24H`), `starts_at`,
  `expires_at`, `purchase_id`.
- Modifier la politique de lecture de `course_items` : l'accès suit
  `has_bought_course(...) OR has_active_pass()`.
- Migration `0014`.

## A2. Aligner la commission : 20 % ou 40 %

**Fonctions**
- `AppConstants.videoCourseCommission` vaut `0.20`. La stratégie arrête **40 %**
  pour les séances en direct. Décider si le taux est unique, puis le poser **à un
  seul endroit** et le faire lire partout — aujourd'hui il est dupliqué dans
  `app_constants.dart`, `_lib/djomy` (`COURSE_COMMISSION`) et `supabase-rows`.

**Éléments** — aucun, sauf l'affichage du net au professeur, qui lit déjà la
constante.

**UX / UI** — le professeur voit ce qui lui revient **avant** de publier : c'est
déjà le cas, il suffit que le chiffre reste juste.

**Base** — aucune. Le taux est figé à l'achat dans `course_purchases.commission`,
donc changer le taux ne réécrit pas le passé.

## A3. Le programme du brevet, matière par matière

**Fonctions**
- Un script de semis qui lit `shared/curriculum/guinea.json` et crée la coquille
  des cours : un cours par matière, des chapitres vides nommés selon le
  programme. Les vidéos viendront après.

**Éléments** — rien de neuf : le formulaire de cours et le lecteur existent.

**UX / UI**
- Un chapitre sans vidéo doit dire **« bientôt disponible »** plutôt que d'être
  grisé sans raison — c'est déjà le comportement du lecteur.

**Base** — données, pas de schéma.

---

# Phase B — Le cours en direct

Le cœur du produit. À ne commencer qu'une fois le fournisseur choisi.

## B1. Le planning : créneaux fixes et séances récurrentes

**Fonctions**
- `LiveCourseRepository` : définir un cours récurrent — professeur, matière,
  classe, prix (40 000–50 000 GNF), **15 places**, créneaux choisis.
- Un générateur de séances : à partir du cours récurrent, créer les occurrences
  des quatre prochaines semaines. Travail planifié côté Worker (cron
  Cloudflare, déjà disponible).
- Validation : les créneaux sont **une liste fermée** (`strategy.md` §1.4), pas
  une saisie libre. Un professeur choisit parmi les six créneaux, il n'en invente
  pas.
- **Un contrôle qui refuse une séance plus longue que son créneau.** Les six
  créneaux font 90 minutes et une séance en fait 90 : la règle est triviale
  aujourd'hui, et c'est précisément pour cela qu'il faut l'écrire maintenant —
  le jour où un créneau d'une heure réapparaît, c'est ce contrôle qui le
  signalera au lieu de laisser des séances se faire couper.

**Éléments**
- Mobile, professeur : `live_course_form_page.dart` — matière, classe, prix,
  cases à cocher sur les créneaux.
- Web et mobile, élève : `/cours-en-direct` — la grille de la semaine.

**UX / UI**
- **La grille, pas une liste.** Six créneaux fixes se lisent comme un emploi du
  temps scolaire ; une liste de dates ne se lit pas.
- Les places restantes sur chaque séance : « 11 places sur 15 ». La rareté est
  réelle, l'afficher est honnête et ça décide.
- Le professeur voit son planning comme une semaine, avec ses 8 séances visées.

**Base**
- `live_courses` : `id`, `teacher_id`, `subject_id`, `level_id`, `price`,
  `seats` (défaut 15), `slots` (text[]), `status`.
- `live_sessions` : `id`, `live_course_id`, `starts_at`, `duration_minutes`
  (**défaut 90**), `status` (`PLANNED`/`LIVE`/`DONE`/`CANCELLED`), `room_name`,
  `recording_url`.
  - Une colonne et non une constante : la salle se ferme sur la valeur de la
    ligne, pas sur une durée écrite dans le code. Un format plus court — une
    séance de rattrapage, une révision avant examen — ne demandera alors ni
    migration ni déploiement.
- Contrainte : `duration_minutes` doit tenir dans le créneau choisi. Les deux
  valent 90 aujourd'hui, donc la contrainte ne refuse rien — elle existe pour le
  jour où ce ne sera plus vrai.
- RLS : une séance `PLANNED` est publique (c'est la vitrine) ; seul le
  professeur la modifie.
- Migration `0015`.

> **À ne pas réutiliser :** `tutoring_sessions` existe mais pointe sur
> `tutoring_requests` — un cours particulier, un élève. Une séance de groupe a
> quinze élèves et aucune demande individuelle. Les deux concepts se
> ressemblent et ne sont pas le même.

### ✅ Fait le 03/10 — côté Flutter, tout sauf la salle

Le téléphone sait désormais **consulter, retrouver et revoir**. Il ne sait pas
**entrer**, et ce découpage est le cœur de la décision.

**Ce qui marche sur le téléphone** : la grille publique par journée, « Mes
séances » (à venir, non payées, passées), la rediffusion dans un vrai lecteur, le
bandeau de présence et le compteur « cette semaine » sur le tableau de bord
parent. Fichiers : `core/scheduling/slots.dart`, `data/remote/live_api.dart`,
`domain/entities/live_models.dart`, `presentation/screens/live/` (grille, lecteur,
bandeau). Routes `/direct` et `/direct/:id/rediffusion`.

**Zéro mégaoctet ajouté à l'APK.** C'est la contrainte qui a dicté le découpage :
l'APK circule par Bluetooth et par Xender, son poids est commercial et non
technique. Tout ce qui précède tient avec les paquets déjà embarqués —
`video_player` lit HLS nativement par ExoPlayer sur Android, là où le site doit
passer par le lecteur de Cloudflare Stream parce que Chrome et Firefox ne lisent
pas HLS sans
bibliothèque. Les deux clients prennent le chemin le moins coûteux de leur
plateforme, et `/live/sessions/:id/replay` rend les deux adresses pour cela.

**L'inscription et le paiement restent sur le site.** Porter le choix du
portefeuille, la redirection Djomy et l'attente du webhook dans l'application
doublerait un parcours qui fonctionne, pour un geste fait une fois par semaine.
La carte d'une séance disponible le dit en une ligne au lieu d'ouvrir un
deuxième tunnel de paiement à maintenir. *(Écart assumé avec les « Éléments »
ci-dessus, qui prévoyaient la feuille d'inscription sur mobile.)*

**La salle : décision séparée, pas un oubli.** `livekit_client` entraîne
`flutter_webrtc`, soit **+8 à 12 Mo par architecture** : l'APK passerait de 56 Mo
à 75–80 Mo. Les deux paquets sont compatibles AGP 9 — leur garde Kotlin tient
compte de `android.builtInKotlin`, vérifié dans le cache pub le 02/10 — donc
c'est faisable, et c'est une question de poids, pas de risque technique. Là où une
séance est ouverte, la carte dirige vers le navigateur plutôt que d'afficher un
bouton qui n'aboutit pas.

**Un défaut trouvé avant d'écrire une ligne d'écran** : `assets/scheduling/`
recevait `slots.json` depuis le 02/10 **sans être déclaré dans `pubspec.yaml`**.
Flutter n'embarque que les dossiers listés : le fichier était écrit à chaque
synchronisation et absent de l'APK, et la première lecture aurait levé chez
l'usager. `shared/onboarding/sync.mjs` vérifie désormais cette déclaration pour
chaque cible mobile, et un test du dépôt la vérifie aussi.

## B2. S'inscrire à une séance et la payer

**Fonctions**
- `enrol(sessionId)` côté Worker : vérifier les places, créer l'inscription,
  lancer le paiement Djomy — **le même chemin que `POST /purchases`**, avec la
  même idempotence par `event_id` et la même règle « le client n'envoie jamais
  le montant ».
- Libérer la place si le paiement échoue ou expire.

**Éléments**
- Web et mobile : la feuille d'inscription depuis la grille, avec le choix du
  portefeuille (Orange Money / MTN MoMo) déjà écrit pour les cours vidéo.

**UX / UI**
- Réutiliser le parcours de paiement existant à l'identique : l'acheteur
  confirme sur son téléphone, la page attend. Ne pas inventer un second
  parcours de paiement.
- Dire ce qui se passe si la séance est annulée **avant** de payer.

**Base**
- `session_enrolments` : `id`, `session_id`, `parent_id`, `child_id` (nullable —
  un étudiant majeur s'inscrit pour lui-même), `purchase_id`, `status`.
- Contrainte d'unicité `(session_id, child_id)`.
- Un index partiel sur les inscriptions payées, pour compter les places vite.

## B3. La salle : visioconférence et jeton d'accès

**Fonctions**
- Worker : `POST /sessions/:id/token` — vérifie que l'appelant est inscrit **et
  que la séance commence dans moins de 15 minutes**, puis signe un jeton de
  salle. Le jeton est court et nominatif ; sans cela un lien se partage.
- Le professeur reçoit un jeton de modérateur, les élèves un jeton de
  participant.

**Éléments**
- Mobile : `live_room_page.dart`.
- Web : `/direct/:sessionId`.
- Un composant partagé pour la barre de la salle : micro, caméra, main levée,
  quitter.

**UX / UI**
- **Un écran d'attente avant d'entrer** : vérifier micro et caméra, voir son
  image. Sur une connexion guinéenne, entrer directement en salle et découvrir
  que le micro ne marche pas gâche les dix premières minutes.
- Affichage par défaut : le professeur en grand, les élèves en bandeau. Quinze
  vignettes égales ne servent personne.
- Un indicateur de qualité de connexion, et une **option « audio seulement »**
  bien visible : c'est le mode qui sauve un cours sur une mauvaise ligne.

**Base**
- `live_sessions.room_name` suffit. Les jetons ne sont pas stockés : ils se
  régénèrent.

## B4. Présence : le compteur de temps et le parent qui regarde

**Fonctions**
- Canal Realtime par séance, avec **Presence** : qui est là, depuis quand.
- À la fermeture de la séance, écrire le temps cumulé par élève — la présence
  en direct est éphémère, le compteur affiché sur le compte ne l'est pas.

**Éléments**
- Compte élève : « temps de cours cette semaine ».
- Compte parent : un bandeau **« Fatoumata suit Mathématiques — en direct
  depuis 23 min »**.

**UX / UI**
- Pour le parent, c'est la fonction qui justifie l'abonnement : elle doit être
  sur l'accueil, pas dans un sous-menu.
- Ne jamais afficher la caméra de l'enfant au parent. C'est une présence, pas
  une surveillance vidéo — la distinction est à tenir dans le dessin comme dans
  le code.

**Base**
- `session_attendance` : `id`, `session_id`, `child_id`, `joined_at`,
  `left_at`, `minutes`.
- Pas de table pour la présence instantanée : Realtime la porte.

### ✅ Fait le 02/10 — et ce qui a changé par rapport au plan ci-dessus

Trois écarts, chacun pour une raison trouvée en écrivant le code.

**1. La présence ne vient pas de Realtime, mais des webhooks LiveKit.**
Le plan faisait déclarer sa présence par le client. Deux défauts, et le second
est le plus fréquent : un élève qui veut faire croire qu'il suit le cours n'a
qu'à ouvrir l'onglet et le fermer — et c'est précisément le compteur que le
parent paie pour lire ; et un navigateur qui plante n'envoie jamais son départ,
ce qui laisse une ligne ouverte pour toujours. LiveKit, lui, **constate** les
deux, déconnexion brutale comprise. Le serveur de visioconférence est donc la
source de vérité : `participant_joined`, `participant_left`, `room_finished`.

**2. `child_id` devient `enrolment_id`.** Un enfant n'a pas de compte :
`children` est une fiche que le parent possède (migration 0001). Celui qui entre
dans la salle est le titulaire du compte. La présence se rattache donc à la
**place payée**, qui porte à la fois le parent et l'enfant — et l'identité
LiveKit est cette place, ce qui donne au passage une propriété utile : *une place
payée, une connexion*. Deux frères sur deux tablettes comptent séparément ; un
mot de passe partagé ne donne pas deux entrées.

**3. Le bandeau parent interroge le serveur toutes les 30 s au lieu de tenir une
connexion Realtime.** Un WebSocket ouvert sur toutes les pages, pour une
information qui change toutes les quelques minutes, coûte plus sur une ligne
payée au mégaoctet — et ne se reprend pas tout seul après une coupure.

**Ce qui existe** : migration `0017_attendance.sql` (`session_attendance`, la vue
`attendance_detail` en `security_invoker`, **aucune politique d'écriture**),
`POST /live/webhooks/livekit`, `GET /live/presence`, `GET /live/study-minutes`,
`src/components/PresenceBanner.tsx` monté dans l'ossature du site, et le bloc
« Cette semaine » du profil parent. 25 contrôles dans
`frontend/web/src/api/presence.test.ts`.

**La limite est tenue dans le code** : `/live/presence` ne rend qu'un prénom, une
matière et des minutes — un test vérifie la liste exacte des champs, de sorte
qu'ajouter quoi que ce soit d'autre casse la suite. Le bandeau n'importe pas le
client vidéo.

## B5. Les points de contrôle et le résumé par l'IA

**Fonctions**
- À la fin de chaque module (4 par séance), le serveur ouvre un point de
  contrôle : *oui / non / pas assez*.
- Agrégation, puis **résumé par Gemini côté serveur** des points les moins
  compris, envoyé au professeur. La clé Gemini reste dans `backend/.env` — elle
  ne doit jamais atteindre un client.
- Le résumé est **une aide, pas une note** : il ne change aucun score.

**Éléments**
- Élève : trois gros boutons, dix secondes pour répondre.
- Professeur : un panneau latéral « ce qui bloque » qui se remplit pendant la
  pause.

**UX / UI**
- Les réponses sont **anonymes pour la classe** et nominatives pour le
  professeur seul. Un élève qui sait que sa réponse s'affiche répond « oui ».
- La pause de 5 minutes est le moment où le panneau compte : c'est là que le
  professeur réexplique.

**Base**
- `session_checkpoints` : `id`, `session_id`, `module_index` (0–3),
  `opened_at`, `closed_at`, `summary`.
- `checkpoint_answers` : `checkpoint_id`, `child_id`, `answer`
  (`YES`/`NO`/`PARTLY`). Unicité `(checkpoint_id, child_id)`.
- RLS : un élève écrit la sienne et ne lit que la sienne ; le professeur de la
  séance lit tout.

### ✅ Fait le 03/10

**Migration `0018_checkpoints.sql`** — `session_checkpoints` (un par module, 0–3)
et `checkpoint_answers`. Deux écarts avec le plan ci-dessus :

1. **`enrolment_id` et non `child_id`**, pour la même raison qu'en 0017 : un
   enfant n'a pas de compte, `children` est une fiche que le parent possède. La
   réponse se rattache à la place payée, qui porte le parent *et* l'enfant.
2. **Aucune politique de mise à jour ni de suppression sur les réponses.** Le
   plan disait « un élève écrit la sienne » ; il fallait ajouter qu'il ne la
   réécrit pas. Pouvoir la changer après la fermeture réécrirait ce que le
   professeur a déjà lu, et pouvoir la supprimer permettrait de recommencer le
   vote.

**L'anonymat est tenu par la forme de la réponse, pas par une consigne.** La
route `/live/sessions/:id/checkpoints` rend deux objets différents : le
professeur reçoit `counts` et `summary`, l'élève reçoit `myAnswer` et rien
d'autre. Un test vérifie que le côté élève ne contient ni l'un ni l'autre —
montrer « 11 sur 15 ont compris » lui apprendrait aussi qu'il est dans les
quatre, ce qui le pousserait à répondre « oui » au module suivant. Et l'écran le
**dit** : « Personne dans la classe ne voit votre réponse. » Une garantie que
personne ne lit ne change pas le comportement.

**Rien de personnel ne part chez Google.** `api/_lib/gemini.ts` reçoit une
matière, une classe, un numéro de module et trois nombres. La garantie tient dans
la **signature** : il n'y a pas de champ où mettre un prénom. Modèles dans
`shared/ai/models.json`, lu par le Worker et par `check-gemini.mjs` — les écrire
aux deux endroits les aurait fait diverger à la première rotation, et le contrôle
passerait alors sur un modèle que la production n'utilise pas.

**Ouvrir et fermer sont rejouables.** Ouvrir deux fois rend le même point de
contrôle (contrainte `unique (session_id, module_index)`) ; en ouvrir un second
scinderait les réponses en deux décomptes dont aucun ne serait vrai. Fermer deux
fois ne rappelle pas Gemini — ce serait payer deux fois la même phrase.

**Un échec de Gemini ne coûte pas le décompte.** Le professeur a besoin des
chiffres ; la phrase est un supplément. `/health` expose `aiSummary` pour qu'on
n'ait pas à chercher pendant un cours pourquoi elle n'arrive pas.

**Ce qui n'est pas fait** : la minuterie de dix secondes. Le plan la prévoyait ;
un seuil dur à dix secondes sur une ligne guinéenne écarterait exactement les
élèves qui peinent — ceux dont la réponse compte le plus. Les trois boutons
restent donc ouverts jusqu'à ce que le professeur ferme, et c'est lui qui juge
quand il a assez de réponses. Le format reste rapide par l'usage, pas par un
compte à rebours.

**Ce que cela débloque** : les bornes de modules que B7 attendait pour découper
une rediffusion. `session_checkpoints.opened_at` donne quatre horodatages par
séance — de quoi faire atterrir un élève sur le module qu'il a manqué, sans
couper au hasard.

## B6. Lever la main

**Fonctions** — un message sur le canal Realtime de la séance. Le professeur
accorde la parole, le serveur n'intervient pas.

**Éléments** — un bouton dans la barre de salle, une file d'attente côté
professeur.

**UX / UI**
- **Une file, pas une alerte.** Trois mains levées en même temps doivent se lire
  dans l'ordre d'arrivée.
- L'élève voit son rang : « vous êtes 2ᵉ ». Sans cela il repose la question.

**Base** — aucune. C'est éphémère ; le stocker créerait une table qu'on ne
relirait jamais.

## B7. L'enregistrement et le replay

**Fonctions**
- Déclencher l'enregistrement à l'ouverture de la séance, l'arrêter à la
  fermeture, écrire l'URL dans `live_sessions.recording_url`.
- Stockage **Cloudflare R2** — l'égress y est gratuit, ce qui est décisif : une
  séance de 90 min revue par quinze élèves, c'est le poste de coût qui
  dépasserait tout le reste chez un autre hébergeur.
- Découper par module, pour que « rejouer la partie manquée » soit possible sans
  faire défiler 90 minutes.

**Éléments** — réutiliser `course_player_page.dart` : le lecteur et les
chapitres existent déjà, un enregistrement découpé en 4 est un cours à 4
chapitres.

**UX / UI**
- L'élève arrivé en retard doit atterrir **sur le module qu'il a manqué**, pas au
  début.
- Le parent accède aux rediffusions : c'est sa preuve que l'enfant a travaillé.

**Base** — `live_sessions.recording_url`, plus des lignes `course_items` pour
les quatre segments. Rien de neuf.

### ✅ Fait le 02/10 — la chaîne complète, sauf le découpage

La chaîne fonctionne de bout en bout :

```
ouverture par le professeur ─► egress LiveKit ─► dépôt R2 (privé)
        │                                              │
        │                       webhook egress_ended ──┘
        ▼                                              │
  fermeture ─► egress arrêté ─► URL pré-signée 2 h ────┘
                                       │
                                       ▼
                        Cloudflare Stream transcode
                                       │
                                       ▼
                 /live/sessions/:id/replay (signé après vérification)
```

> **Changement du 03/10 : Bunny est remplacé par Cloudflare Stream.** La raison
> n'est pas le prix mais le réseau — R2 et Stream sont chez le même fournisseur,
> donc le transfert entre les deux ne traverse pas Internet et ne coûte pas
> d'egress. C'est aussi un fournisseur de moins à facturer, surveiller et
> intégrer, et cela a supprimé l'hypothèse la plus risquée du module vidéo : la
> chaîne à signer pour un jeton de lecture, que Bunny laissait calculer à la main
> avec un mode « chemin » qui changeait la formule. Stream émet le jeton par API.

**Le dépôt reste privé.** Le plan ne tranchait pas ; un dossier public
économisait cinquante lignes et rendait chaque séance de 90 minutes
téléchargeable par qui devine un nom de fichier — et un nom dérivé d'un
identifiant de séance se devine. Le serveur signe donc une URL valable deux
heures, le temps que Stream ingère : `backend/api/_lib/r2.ts`, signature AWS
version 4, vérifiée contre les vecteurs publiés par AWS (`s3.test.ts`).

**Deux écarts assumés :**

1. **Le découpage par module n'est pas fait.** La rediffusion est la séance
   entière. Découper demande soit quatre enregistrements successifs, soit un
   traitement après coup — et dans les deux cas les bornes des modules viennent
   de **B5**, qui n'existe pas encore. Promettre « atterrir sur le module
   manqué » sans ces bornes aurait voulu dire couper à 0, 22, 45 et 67 minutes au
   hasard, ce qui est pire que de ne pas couper. À reprendre avec B5.
2. **Le site lit la rediffusion dans le lecteur de Cloudflare Stream (`iframe`),
   pas dans le
   lecteur maison.** Le flux est en HLS : Safari le lit, Chrome et Firefox non.
   Il aurait fallu `hls.js` plus la gestion des qualités, de la reprise et des
   erreurs réseau sur 90 minutes de vidéo — le code qu'on écrit mal. Le morceau
   de code de l'écran pèse 1,1 ko compressé. La réutilisation de
   `course_player_page.dart` reste valable **côté Flutter**, où `video_player`
   lit HLS nativement : la route rend aussi une URL `hls` pour cela.

**Ce qui existe** : `POST /live/sessions/:id/open` (rejouable : recliquer ne
lance pas un second enregistrement), `POST /live/sessions/:id/close` (l'egress
s'arrête **avant** que la salle soit vidée, sinon le fichier finit sur du noir),
`GET /live/sessions/:id/replay` (état relu chez Bunny à la demande),
`GET /live/my-sessions` — sans cette liste, une séance payée disparaissait dès le
lendemain —, `frontend/web/src/screens/Replay.tsx` et la section « Mes séances »
de la grille.

**Ajouté au passage, et qui n'était pas au plan** : la salle **dit qu'elle
enregistre**, à tout le monde et non au seul professeur. Quinze élèves mineurs
filmés pendant 90 minutes : qu'ils le sachent n'est pas une option d'affichage.
L'état vient du serveur, dans la réponse du jeton d'entrée.

## B8. Noter le professeur à la fin de chaque séance

**Fonctions**
- `rateSession(sessionId, score, comment?)`, ouvert aux inscrits présents
  seulement — noter une séance qu'on n'a pas suivie n'apprend rien.
- Agrégation sur la fiche du professeur.

**Éléments** — une feuille qui s'ouvre à la fermeture de la salle.

**UX / UI**
- **Une seule question**, deux secondes. Un questionnaire de cinq critères à la
  fin de chaque séance ne sera rempli qu'une fois.
- La note du professeur s'affiche sur sa fiche publique une fois qu'il a assez de
  séances — sinon une seule mauvaise note le condamne.

**Base**
- `session_ratings` : `session_id`, `child_id`, `score` (1–5), `comment`,
  unicité `(session_id, child_id)`.
- **Ne pas réutiliser `teacher_reviews`** : cette table est liée à
  `recruitments` et aux jalons 30/60/90 jours d'un recrutement. Autre objet,
  autre cycle de vie.

---

# Phase C — Le suivi des devoirs

## C1. Envoyer un exercice en photo, le corriger, prévenir le parent

**Fonctions**
- Dépôt : étendre `document_pipeline.dart` — la compression et la limite de
  taille existent, il manque un type « devoir ».
- `submitHomework(sessionId?, subjectId, photos[])`.
- `correctHomework(id, score, comment)` — **le commentaire est obligatoire**,
  refusé vide côté serveur, pas seulement grisé dans l'écran.
- À la correction : notification au parent (`notifications` existe).

**Éléments**
- Élève : bouton « envoyer mon exercice » depuis la séance ou la matière.
- Professeur : une file « à corriger », groupée par semaine.
- Parent : la correction dans son suivi.

**UX / UI**
- **Le rythme est hebdomadaire et il doit être dit** : « corrigé chaque
  dimanche ». Un élève qui attend une correction immédiate la croit perdue.
- Le commentaire du professeur est ce que le parent lit vraiment — il passe
  avant la note dans l'écran.
- La file du professeur doit montrer le reste à faire : « 12 copies, environ
  40 min ».

**Base**
- `homework_submissions` : `id`, `child_id`, `teacher_id`, `subject_id`,
  `session_id` (nullable), `photo_paths`, `submitted_at`, `week_of`.
- `homework_corrections` : `submission_id`, `score`, `comment` (**not null,
  longueur minimale**), `corrected_at`.
- RLS : l'élève voit les siennes, le parent celles de ses enfants, le professeur
  celles qui lui sont adressées.

---

# Phase D — Points, boutique et rétention

À faire après que le produit payant fonctionne. Des points sans cours à suivre
ne retiennent personne.

## D1. Le grand livre de points

**Fonctions**
- `PointsRepository` : créditer, débiter, solde. **Écritures atomiques**
  (`UPDATE … SET solde = solde - ?`), jamais lire-modifier-écrire.
- Gains : participation jugée pertinente par le professeur, concours, codes QR.
- Le solde se calcule **côté serveur** et jamais dans le client.

**Éléments** — un solde visible sur le profil, un historique.

**UX / UI**
- Dire **pourquoi** chaque point a été gagné. Un solde qui monte sans raison
  lisible ne motive pas.

**Base**
- `point_ledger` : `id`, `owner_id`, `delta`, `reason`, `reference`,
  `created_at`. Append-only.
- RLS : chacun lit le sien ; **seul le serveur écrit**.

> **Ce n'est pas le retour des crédits.** `credit_ledger` a été supprimé le
> 02/10 parce qu'il faisait payer l'usage de l'IA à l'unité. Les points sont une
> monnaie de fidélité : on les gagne, on ne les achète pas. Le nom et la règle
> doivent rester distincts pour que personne ne refasse l'ancien système.

## D2. La boutique et les lots

**Fonctions** — catalogue, demande d'échange, validation manuelle avant remise
d'un objet physique.

**Éléments** — page `/boutique`, dans les deux clients.

**UX / UI**
- Prix en points **et** équivalent en GNF : 600 points ≈ 100 000 GNF rend le
  barème compréhensible.
- Montrer la distance au lot suivant : « encore 140 points ».

**Base** — `shop_items` (`points_price`, `stock`), `redemptions`
(`PENDING`/`DELIVERED`/`REFUSED`).

## D3. Se partager des points

**Fonctions** — transfert plafonné à **10 points par jour** offerts, ou 50 sur
décision. Deux écritures dans une transaction, jamais une seule.

**UX / UI** — un plafond annoncé avant le geste, pas après le refus.

**Base** — deux lignes `point_ledger` liées par la même `reference`.

## D4. Concours hebdomadaires et classement national

**Fonctions** — réutiliser `tests` et `test_sessions` avec un drapeau
« concours » et une fenêtre de temps. Le classement est **une requête SQL**, pas
une table : des chiffres calculés, jamais saisis.

**Éléments** — page `/concours`, podium, rang personnel.

**UX / UI**
- Afficher **son propre rang** avant le top 10 : c'est ce que l'élève cherche.
- Un classement national n'a de sens qu'avec assez de participants — ne pas
  l'ouvrir à 30 inscrits.

**Base** — `contests` (`test_id`, `opens_at`, `closes_at`, `points_prize`), et
une vue pour le classement.

## D5. Cosmétiques de profil

**Fonctions** — posséder, équiper. Rien d'autre.

**Éléments** — un sélecteur dans l'édition de profil.

**UX / UI** — les cosmétiques gagnés se distinguent des cosmétiques achetés :
c'est tout leur intérêt.

**Base** — `profile_items`, `owned_items` (`owner_id`, `item_id`, `source`).

## D6. Les codes QR des concerts

**Fonctions** — générer des lots de codes, un usage unique chacun ;
`redeem(code)` créditant 10 à 100 points.

**Éléments** — un champ « j'ai un code » à l'inscription et sur le profil.

**UX / UI**
- Le code se saisit **pendant l'inscription** : c'est le moment où la personne
  vient d'arriver par le billet, et le seul où elle a le code en main.

**Base** — `promo_codes` (`code` unique, `points`, `batch`, `used_by`,
`used_at`).

---

## Ce que cette mise en œuvre ajoute au schéma

Quinze tables, en six migrations :

| Migration | Tables |
|---|---|
| `0014` | `access_passes` |
| `0015` | `live_courses`, `live_sessions` |
| `0016` | `session_enrolments`, `session_attendance` |
| `0017` | `session_checkpoints`, `checkpoint_answers`, `session_ratings` |
| `0018` | `homework_submissions`, `homework_corrections` |
| `0019` | `point_ledger`, `shop_items`, `redemptions`, `profile_items`, `owned_items`, `contests`, `promo_codes` |

**Chaque table part avec RLS activée et une politique écrite dans la même
migration.** Une table livrée sans politique est soit fermée à tous — et la
fonction ne marche pas — soit ouverte à tous, et la clé anonyme est publique.
C'est la règle qui tient les 49 tables actuelles.

Côté Flutter, le schéma Drift passe de la **v23 à la v29**, une version par
migration serveur, et `npm run check:schema` vérifie que les deux concordent
après chaque étape.

---

## Ordre conseillé

```
Décision fournisseur vidéo  ─────► bloque toute la phase B

A1 pass brevet        ─┐
A2 commission          ├─ recette immédiate, aucun concept nouveau
A3 programme brevet   ─┘

B1 planning           ─► B2 inscription ─► B3 salle
                                            │
                        B4 présence ◄───────┤
                        B5 contrôles ◄──────┤
                        B6 main levée ◄─────┤
                        B7 replay ◄─────────┘
                        B8 notation

C1 devoirs            ─► après B4 : une correction se rattache à une séance

D1 points             ─► D2 boutique, D3 partage, D4 concours,
                         D5 cosmétiques, D6 codes QR
```

**Ne pas commencer la phase D avant que la phase B rapporte.** Des points à
dépenser dans une boutique, sans cours à suivre pour les gagner, c'est un jeu
sans produit.
