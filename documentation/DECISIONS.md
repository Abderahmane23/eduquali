# Journal des décisions

Purpose: garder la trace de ce qui a été décidé, pourquoi, et ce qui reste ouvert.
Audience: développeurs et responsable produit.
Last updated: 04/10/2026 — Owner: équipe Eduquali.

Une entrée par décision structurante. Les plus récentes en haut. On ne
réécrit jamais une entrée passée : on en ajoute une qui la remplace.

Ce qui reste à faire vit dans [ROADMAP.md](ROADMAP.md).

---

## 2026-10-04 — Un groupe de discussion naît d'une relation, jamais d'une invitation

**Décision.** Les discussions de groupe existent, en forme de messagerie
moderne (Discord mobile), mais **on n'en crée pas et on n'en rejoint pas**. Un
groupe s'ouvre tout seul autour d'une relation — un cours en direct — et ses
membres sont ceux que cette relation lie.

**Contexte.** Trois profils sur quatre avaient un onglet de messagerie, et
`conversations` est strictement à deux. Un cours suivi par quinze familles n'a
donc nulle part où exister : les questions de l'une servent aux autres, et les
reposer en quinze fils privés fait quinze fois le travail.

**Les trois modèles, et pourquoi celui-ci.**

Un groupe ouvert avec code d'invitation ou annuaire — le modèle Discord — pose
une question qu'on ne sait pas encore traiter : des adolescents et des adultes
dans une même salle, sans signalement, sans modération, sans personne pour
lire. Le refuser maintenant coûte une fonction ; l'accepter coûterait une
responsabilité.

L'appartenance est donc **dérivée** (`est_membre_groupe`, migration 0027) et
jamais stockée. C'est la même règle que le répertoire du professeur :
**l'accès suit la relation**. Une place annulée, un contrat terminé, et la
porte se referme sans que personne ait à retirer une ligne. Une table de
membres serait une copie qui diverge.

**Ce qui a été repris de Discord, et ce qui ne l'a pas été.** Des lignes et non
des bulles — un fil à bulles perd un tiers de l'écran en marges, et ici quinze
personnes écrivent. Les messages consécutifs d'un même auteur se regroupent
sous un seul en-tête. Le dièse, qui dit « salon » sans explication. Pas de
salons dans un groupe : un groupe de maths de Terminale a besoin d'un endroit,
pas de cinq. Ni fichiers, ni réactions, ni réponse à un message précis — un
envoi de fichier dans un groupe d'enfants n'est pas une fonction d'affichage.

**Pourquoi les messages sont conservés, alors que le fil d'une séance en
direct ne l'est pas.** Les deux ne font pas le même travail. Le fil du direct
commente une vidéo pendant qu'elle passe et ne vaut rien le lendemain ; un
groupe de cours porte la question posée le soir sur l'exercice 3, et une
question dont la réponse a disparu ne sert à personne.

**⚠ Ce que cela ouvre et qui n'est pas fait.** Ni signalement, ni suppression
par un tiers, ni durée de conservation. Les messages ne s'éditent pas et ne se
suppriment pas — ce n'est pas une position sur la modération, c'est son absence
assumée : laisser un auteur réécrire après coup rendrait un signalement futur
inexploitable. Inscrit dans ROADMAP.md.

---

## 2026-10-04 — Une réponse d'inscription a une destination, ou la question disparaît

**Décision.** Toute question posée pendant l'inscription doit aboutir dans une
colonne lue par un écran. Celles qui n'en avaient pas en ont reçu une
(migration `0026`) ; celle qui n'en méritait pas a été retirée.

**Contexte.** L'audit du 04/10 a comparé chaque `fieldId` des quatre parcours
aux clés réellement lues par `SignupCompletion` : le parcours professeur
exploitait 7 réponses sur 15, celui de l'établissement 8 sur 17.

**Les trois issues, et laquelle pour quoi.**

1. **Lui donner sa destination** — matières, niveaux, ce qu'il cherche, sa
   mobilité, ses créneaux, les critères de l'établissement. Ces réponses
   décrivent un état courant, donc des colonnes et non des tables : il n'y a
   qu'un seul « ce que je cherche » par compte, et le remplacer est tout ce
   qu'on en fera.

2. **Retenir sans accorder** — la formule. `profiles.pending_plan` est
   distincte de `plan` parce que **rien n'est encaissé à l'inscription** :
   écrire dans `plan` offrirait l'abonnement. La facturation présente la
   formule choisie, et seul le paiement déplace la valeur.

3. **Retirer la question** — le numéro Orange Money. Son propre libellé disait
   « Le même que votre numéro de compte, en général », et le serveur prend
   déjà le numéro du compte comme payeur par défaut tout en acceptant un autre
   numéro au moment de payer. La question se pose là où le montant est à
   l'écran, pas douze écrans avant. Deux parcours raccourcis d'un écran.

**Ce qui empêche la rechute.** `signup_end_to_end_test.dart` couvre désormais
le chemin professeur et le chemin établissement. Leur absence est exactement
ce qui avait laissé passer le défaut : le test vérifiait l'apprenant, le seul
chemin qui fonctionnait.

---

## 2026-10-04 — La personnalisation classe, elle ne cache pas

**Décision.** Le niveau et les matières déclarés **remontent** ce qui
correspond ; ils ne retirent rien. Le catalogue arrive trié, une section
« Pour votre niveau » met en avant jusqu'à quatre cours, et rien ne disparaît.

**Contexte.** Ces réponses n'étaient lues par aucun écran de contenu : un
universitaire voyait le catalogue d'un élève de CE2, et un compte neuf
n'affichait que trois sections vides.

**Pourquoi pas un filtre.** Un cours d'une autre classe sert à réviser l'année
passée ou à préparer la suivante. Et une liste qui rétrécit en silence fait
croire qu'il n'y a que trois cours — c'est le raisonnement déjà tenu pour le
filtre par palier des professeurs, qui s'annonce et se retire.

**Le corollaire.** Une section qui ne trouve rien de pertinent **disparaît**
au lieu de se remplir au hasard : « Pour votre niveau » au-dessus de cours
d'un autre niveau serait un titre qui ment.

**Au passage.** Le rapprochement des offres d'emploi, lui, existait déjà et
était correct — `offersInSubjects` puis `MatchingEngine.score`. Mais
`offersInSubjects` rend `const []` sans matière déclarée : comme l'inscription
jetait les matières, tout professeur fraîchement inscrit avait un onglet
« Offres » **entièrement vide**, avec un message lui demandant d'aller saisir
ce qu'il venait de saisir. Un défaut de branchement à l'inscription
désactivait en silence un sous-système entier.

---

## 2026-10-04 — Le répertoire du professeur est dérivé, jamais stocké

**Décision.** Le professeur voit un « répertoire » des familles qu'il connaît
déjà. Aucune table ne le contient : `/live/teacher/contacts` le recalcule à
chaque appel à partir des liens qui existent — les inscriptions payées à ses
propres séances, et les contrats de travail `PENDING` ou `ACTIVE`.

**Contexte.** « Inviter depuis mon répertoire » demandait une liste de
contacts. Trois façons de la constituer étaient sur la table : une table
`contacts` alimentée à la main, le carnet d'adresses du téléphone via
`READ_CONTACTS`, ou la dérivation.

**Pourquoi la dérivation.**
- **L'accès suit la relation.** Un contrat se termine, la ligne disparaît
  d'elle-même. Une table recopiée diverge : le contrat finit, la ligne reste,
  et un professeur garde indéfiniment les coordonnées d'un enfant qu'il
  n'enseigne plus. Pour un produit qui traite des mineurs, c'est la propriété
  qui décide.
- **`READ_CONTACTS` est une permission lourde** pour un carnet dont la quasi
  totalité des entrées ne sont pas des comptes Eduquali, et le greffon pèserait
  sur un APK déjà à 77,9 Mo distribué par Bluetooth.
- Il n'y a **rien à synchroniser** : pas de migration, pas de purge, pas de
  question « que devient le répertoire quand le compte ferme ».

**Ce que ça coûte.** Un professeur ne peut pas inviter quelqu'un qu'il n'a
jamais eu en cours ni sous contrat. C'est assumé : la première séance se
remplit par la grille publique et le partage du lien, pas par le répertoire.

**Conséquence.** Aucune invitation ne part par SMS. Prévenir écrit une ligne
dans `notifications` — gratuit, et lu dans l'application. Le SMS sera une
décision avec un budget, pas un effet de bord : quinze familles prévenues deux
fois par séance se chiffrent.

---

## 2026-10-04 — Un lien de notification est vérifié par un test

**Décision.** Tout chemin écrit dans `notifications.route` est comparé aux
routes déclarées dans `app_router.dart`
(`api/_lib/notification-routes.test.ts`).

**Contexte.** La notification « le cours commence » partait vers `/live/<id>` ;
la salle est enregistrée sous `/direct/<id>/salle`. Le professeur appuyait sur
« Prévenir », les familles recevaient la ligne, et la toucher n'ouvrait rien —
à l'instant précis où le cours commençait. Les deux côtés compilaient, les deux
suites passaient : le chemin est écrit dans le Worker et résolu par go_router,
et rien ne reliait les deux.

Le bouton « Voir la rediffusion » de la fin de séance souffrait de la même
classe de défaut pour une autre raison : il appelait
`Navigator.pushReplacementNamed` avec un *chemin*, alors que cette méthode
attend un *nom* de route — et aucune route du projet n'en porte. Il levait donc
à chaque fin de cours.

**Ce qui borne le risque.** Les chemins du direct ne sont plus écrits à la main
nulle part : `Routes.liveRoom(id)` et `Routes.sessionReplay(id)`. Le test porte
un plancher (au moins trois liens lus) pour qu'une expression de lecture cassée
échoue au lieu de passer au vert sans rien vérifier.

---

## 2026-09-16 — Un code unique hors ligne, et connexion par code

**Décision.** Tant que le serveur ne répond pas, le code `123456` ouvre la
session. La connexion se fait par numéro + code, plus par mot de passe.

**Contexte.** Aucun SMS ne peut partir sans serveur : les testeurs de l'APK
restaient bloqués à l'inscription. Par ailleurs un compte ouvert par le parcours
n'a jamais reçu de mot de passe — une fois déconnecté, il ne pouvait plus
revenir.

**Ce qui borne le risque.**
- Le code est refusé dès que le serveur répond, même si le drapeau est resté
  actif : il ne peut pas devenir une porte dérobée sur les vrais comptes.
- Un drapeau de compilation le coupe : `--dart-define=OFFLINE_OTP=false`.
- La règle vit dans une fonction pure (`otp_check.dart`), testée cas par cas.

**Conséquence.** À couper dans toute version publiée : la tâche figure dans la
feuille de route, partie 3.

**Au passage.** Chaque inscription de la v1.4 finissait sur « Compte
introuvable » : l'identifiant du compte était transmis sous la forme du texte
`$userId` (dollar échappé). L'URL de l'écran du code n'est plus écrite à la
main (`Routes.otpFor`), et un test échoue si l'ancienne forme revient.

---

## 2026-09-14 — Le compte appartient au parent, pas à l'élève

**Décision.** Le troisième profil est `PARENT`. Le rôle `STUDENT` envisagé le
12/09 est abandonné avant toute livraison.

**Contexte.** Un élève de collège ou de lycée est mineur : lui faire ouvrir un
compte déplaçait le consentement sur un enfant. Le parent ouvre le compte,
déclare ses enfants (prénom + classe) et agit pour eux. Les tables `parents`
et `children` de `0001` sont conservées et complétées, au lieu d'être
remplacées.

**Conséquence.** Migration `0004_enrolments.sql` : `enrolment_requests` est
rattachée au parent **et** à l'enfant — l'enfant désigne la scolarité
concernée, le parent reste la personne qui consent et que l'établissement
rappelle. Ferme la décision ouverte n° 1.

---

## 2026-09-14 — La Terminale entre au référentiel

**Décision.** Ajout du niveau `lvl_terminale` (SECONDARY), et passage des rangs
d'affichage de tous les niveaux en valeurs explicites.

**Contexte.** Le lycée guinéen s'achève en Terminale. Sans elle, un professeur
de lycée ne pouvait pas déclarer la classe qu'il enseigne le plus souvent, et
un parent ne pouvait pas situer un enfant en dernière année.

Les rangs n'existaient qu'implicitement, par l'ordre du fichier : insérer une
classe au milieu changeait l'ordre affiché selon l'ordre d'insertion en base.
Ils sont désormais posés un par un dans `catalog.json` (clé `order`).

**Conséquence.** `_seedVersion` passe à `'2'` : le seed ne repasse que si cette
valeur change, donc sans ce coup de pouce la Terminale n'apparaîtrait jamais
sur une installation existante.

---

## 2026-09-14 — Fiche détaillée d'un établissement

**Décision.** `institutions` porte désormais `phone_alt`, `website`,
`founded_year`, `ownership`, `academic_system`, `degrees`, `specialties` et
`facilities`. Les listes sont des chaînes séparées par des virgules, pas des
tables.

**Contexte.** Une fiche réduite au nom, au type et à la ville ne dit pas ce
qu'un parent ou un candidat cherche : depuis quand l'établissement existe, ce
qu'on y étudie, ce qu'on y trouve, comment le joindre. L'Université Nongo
Conakry sert de référence réelle ; les autres portent des données plausibles.

**Options écartées.** *Une table de liaison par filière.* C'est une donnée
d'affichage : on ne cherche jamais « tous les établissements qui enseignent le
droit » depuis cet écran, et la jointure coûterait sans rien rendre. À revoir
le jour où la recherche par filière existe.

**Conséquence.** Migration Drift v3 (`addColumn` uniquement) et migration
Postgres `0005_institution_details.sql`. `generate-seed.mjs` propage les
colonnes, sans quoi le seed SQL les aurait laissées vides en silence.

---

## 2026-09-14 — Un espace par profil

**Décision.** `ParentShell` (Écoles · Professeurs · Profil) et redirection par
rôle dans une table unique.

**Contexte.** Un compte parent atterrissait dans l'espace enseignant, faute
d'avoir le sien. L'écran de profil ne lisait que `session.teacherId` : un
établissement comme un parent tombait sur « Profil indisponible » alors que
son compte existait.

**Conséquence.** Chaque rôle a son accueil, sa barre d'onglets et sa
déconnexion. Les professeurs proposés à un parent sont restreints à sa ville
et à `AVAILABLE` : proposer un professeur de Kankan à une famille de Conakry
ne sert personne. Sans ville renseignée, la liste reste large plutôt que vide,
une liste vide se lisant comme une panne.

---

## 2026-09-12 — Trois profils : enseignant, établissement, élève
> **Remplacée le 14/09/2026** par « Le compte appartient au parent ». Conservée
> pour mémoire : le profil élève n'a jamais été livré.

**Décision.** L'application couvre trois types de compte : `TEACHER`,
`INSTITUTION`, `STUDENT`. Le rôle `PARENT` introduit en v2 est supprimé.

**Contexte.** Le parcours d'inscription commence désormais par cinq écrans de
découverte communs, puis une question unique — « Parlez-nous de vous » — avec
trois boutons empilés. Le rôle choisi détermine le parcours suivant.
`PARENT` n'avait d'écran dans aucun des deux clients : aucune donnée en
production, donc bascule sans reprise.

**Options écartées.**
- *Le parent détient le compte pour les mineurs, l'élève pour les majeurs.*
  Le plus correct juridiquement, le plus coûteux : deux modèles de compte à
  maintenir pour une seule fonctionnalité.
- *Élève + parent rattaché comme payeur.* Repoussé : personne ne paie encore
  dans le produit.

**Conséquence.** `students` remplace `parents` / `children`.
`tutoring_requests.parent_id` devient `student_id`. Migration
`0003_students.sql`.

---

## 2026-09-12 — Les inscriptions vont de l'élève vers l'établissement
> **Amendée le 14/09/2026** : la demande part du parent, pour l'enfant qu'il
> désigne. Le sens — le demandeur propose, l'établissement décide — ne change
> pas.

**Décision.** « Faire des inscriptions » signifie : un élève envoie une
demande d'inscription à un établissement, qui l'accepte ou la refuse. Ce
n'est pas la gestion de listes d'élèves par l'école.

**Contexte.** Même forme que les candidatures à une offre d'emploi : le
demandeur propose, l'établissement décide. Une demande par élève, par
établissement et par année scolaire.

**Conséquence.** Table `enrolment_requests`, routes `/enrolments`. Les
transitions autorisées vivent dans `api/_lib/domain.ts`
(`canSetEnrolmentStatus`) et sont testées : un élève ne peut pas s'accepter
lui-même, une décision rendue ne se rejoue pas.

---

## 2026-09-12 — Le rôle n'est plus modifiable par son porteur

**Décision.** `revoke update (role, suspended) on profiles`, doublé d'un
déclencheur qui rejette tout changement venant d'un client.

**Contexte.** La politique de mise à jour du profil ne restreignait aucune
colonne. N'importe quel compte pouvait s'attribuer `role = 'INSTITUTION'` —
et, depuis l'ajout du profil élève, lire la fiche de tous les élèves ayant
écrit à un établissement. Les fonctions `security definer` de `0002` se
voient également fixer un `search_path`.

**Conséquence.** Le changement de rôle et la suspension relèvent du
back-office (clé de service). Migration `0003_students.sql`.

---

## 2026-09-12 — Le parcours d'inscription a une seule source

**Décision.** Les parcours vivent dans `shared/onboarding/` et sont recopiés
vers les deux clients par `node shared/onboarding/sync.mjs`.

**Contexte.** Chaque client portait sa copie du JSON. Les deux avaient déjà
divergé : le web affichait une illustration que le mobile ignorait.

**Conséquence.** `frontend/web/public/data/` et
`frontend/mobile/assets/onboarding/` sont générés. Le script refuse un JSON
invalide, un type d'étape inconnu d'un des deux clients, une condition qui
vise un champ que personne ne renseigne, ou un prix à décimales.

---

## Décisions ouvertes

### 1. Consentement des mineurs — ~~bloquant~~ **tranché le 14/09/2026**

Le compte appartient au parent : le consentement est donné par un adulte. Ce
qui reste à cadrer relève du §52 (analyse juridique guinéenne sur les données
personnelles), pas du modèle de compte.

<details><summary>Énoncé d'origine</summary>

Un élève de collège ou de lycée est mineur. Le compte lui appartient
désormais (décision du 12/09/2026), ce qui pose trois questions non
tranchées :

- Qui consent au traitement des données ? `students.guardian_name` et
  `guardian_phone` existent pour porter le contact adulte, mais rien ne les
  exige ni ne les vérifie aujourd'hui.
- À partir de quel âge un compte autonome est-il acceptable ?
- Que montre-t-on à un établissement qui reçoit une demande d'un mineur ?

Le §52 du cahier des charges demande déjà une analyse juridique guinéenne
sur les données personnelles. Ce point s'y ajoute.

**Position d'origine :** la date de naissance et le contact du responsable
sont stockables mais facultatifs.
</details>

### 2. Questions d'état civil — **retirées le 14/09/2026**

« Êtes-vous marié(e) ? » et « Avez-vous des enfants ? » ne figurent plus au
parcours enseignant. Sans rapport avec la compétence, et c'est le type de
donnée qui fonde une discrimination à l'embauche. Elles n'avaient jamais été
persistées : elles ne vivaient que dans la description du parcours.

Un test le garantit (`onboarding_spec_test.dart`) pour qu'elles ne
reviennent pas par inadvertance.

### 3. Quatre écrans de découverte

Le `design_skill` (§10) plafonne un carrousel d'introduction à trois écrans
et demande de supprimer tout écran qui ne change pas ce que l'utilisateur
voit ensuite. Le parcours en compte quatre, à la demande du responsable
produit.

**À mesurer :** taux d'achèvement du parcours et première action utile en
session 1. Couper les écrans dont le retrait ne dégrade ni l'un ni l'autre.

### 4. Vérification réellement effectuée

Aucun chemin de code ne fait passer `identity_status`, `diploma_status` ou
`verification_status` à `VERIFIED` : il n'existe ni back-office ni service de
vérification branché. Les contrôles KYC embarqués sont des heuristiques de
taille de fichier, pas de la reconnaissance faciale.

**Conséquence tant que ce point reste ouvert :** aucun badge « vérifié » ne
peut apparaître en production, et le Trust Score plafonne à 55/100.
