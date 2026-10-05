-- Les reponses de l'inscription ont enfin une destination (04/10).
--
-- --- Le defaut -------------------------------------------------------------
--
-- L'audit du 04/10 a compare chaque `fieldId` des quatre parcours
-- (`frontend/mobile/assets/onboarding/*.json`) aux cles reellement lues par
-- `SignupCompletion`, le seul endroit ou une reponse devient un compte :
--
--   professeur      7 reponses sur 15 exploitees
--   etablissement   8 sur 17
--   parent          13 sur 15
--   universitaire   12 sur 14
--
-- Un professeur remplissait sept ecrans — ce qu'il enseigne, a quels niveaux,
-- quels jours, s'il se deplace — et arrivait sur un compte qui n'en savait
-- rien. Sa fiche s'affichait sans aucune matiere, et il devait ressaisir les
-- memes faits dans `/teacher/subjects`, `/teacher/levels`, puis une troisieme
-- fois dans le formulaire d'offre.
--
-- --- Pourquoi des colonnes et non des tables -------------------------------
--
-- Ces reponses decrivent un **etat courant** et non un historique : il n'y a
-- qu'un seul « ce que je cherche » par professeur, et le remplacer est tout ce
-- qu'on fera jamais. Une table par reponse multiplierait les jointures pour
-- une ligne par compte.
--
-- Les deux exceptions restent des tables, parce qu'elles sont des relations et
-- non des attributs : `teacher_subjects` et `teacher_levels` existaient deja
-- et sont desormais remplies par l'inscription.
--
-- --- Au passage : trois colonnes qui manquaient depuis le debut ------------
--
-- `teachers.region` et `teachers.district` existent dans l'application depuis
-- la v9 et `registerTeacher` les met dans sa charge de synchronisation, mais
-- elles n'ont jamais existe ici : la region et le quartier d'un professeur
-- n'arrivaient donc jamais au serveur. Le controle de concordance ne l'a pas
-- vu parce qu'il compare les **noms de tables**, pas les colonnes.
--
-- Meme histoire pour les creneaux a domicile : `tutoring_repository.dart` les
-- enregistre localement et les pousse sous l'entite
-- `teacher_tutoring_availability` — une table que **aucune migration n'a
-- jamais creee**. Chaque envoi echouait donc en `42P01`. On range les creneaux
-- la ou l'application les tient deja, en deux colonnes sur `teachers`.

-- --- Le professeur ---------------------------------------------------------

alter table teachers
  -- Localisation : declarees par l'application depuis la v9, jamais arrivees.
  add column if not exists region          text,
  add column if not exists district        text,

  -- Creneaux pour les cours a domicile — l'etape `home_availability`.
  -- Codes de jours et de moments separes par des virgules, tels que
  -- `tutoring_repository.dart` les ecrit.
  add column if not exists tutoring_days   text not null default '',
  add column if not exists tutoring_slots  text not null default '',

  -- Les creneaux **par jour**, en JSON : {"MON":["MORNING"],"SAT":[...]}.
  --
  -- `tutoring_days` et `tutoring_slots` sont deux ensembles a plat : « mardi,
  -- jeudi » d'un cote, « matin, soir » de l'autre. On ne peut pas en deduire
  -- si le professeur vient le mardi matin ou le mardi soir. C'est precisement
  -- le defaut que l'etape `day_hours` du parcours a ete ecrite pour corriger.
  -- Les colonnes plates restent remplies, derivees de celle-ci, parce que
  -- l'ecran de disponibilite et les offres les lisent deja.
  add column if not exists tutoring_hours  text not null default '{}',

  -- Idem pour un poste en etablissement — l'etape `availability`. Separee a
  -- dessein : le parcours pose bien deux questions, les disponibilites pour
  -- une classe et pour un eleve seul n'etant pas les memes.
  add column if not exists work_hours      text not null default '{}',

  -- Ce qu'il cherche : HOME, FULL_TIME, ou les deux — l'etape
  -- `service_types`. C'est la reponse qui oriente tout le reste : une liste
  -- d'offres d'emploi n'interesse pas qui ne veut que des cours a domicile.
  add column if not exists service_types   text not null default '',

  -- STAY ou MOVE — l'etape `mobility`. Le pendant exact de
  -- `institutions.teacher_location`.
  add column if not exists mobility        text
    check (mobility is null or mobility in ('STAY', 'MOVE'));

-- Chercher les professeurs d'une region qui acceptent de bouger : c'est la
-- requete que le rapprochement etablissement/professeur fera.
create index if not exists teachers_region_mobility_idx
  on teachers (region, mobility);

-- --- L'etablissement ------------------------------------------------------
--
-- Aucune de ces six reponses n'avait de colonne. Consequence : a chaque offre
-- publiee, le formulaire redemandait la matiere, les niveaux et jusqu'a la
-- ville — pourtant obligatoire et deja connue.

alter table institutions
  -- Fonction du responsable : le nom etait garde, la fonction perdue.
  add column if not exists manager_role       text,

  -- Matieres cherchees, separees par des virgules. C'est un besoin permanent,
  -- distinct d'une offre : c'est ce qui prefixe la prochaine.
  add column if not exists needed_subject_ids text not null default '',

  -- FAST | CHOICE | CONTRACT | VERIFIED, separes par des virgules.
  add column if not exists priorities         text not null default '',

  -- IN_TOWN ou CAN_MOVE : accepte-t-il quelqu'un pret a se rapprocher.
  add column if not exists teacher_location   text
    check (teacher_location is null
           or teacher_location in ('IN_TOWN', 'CAN_MOVE')),

  add column if not exists work_days          text not null default '',
  add column if not exists work_start         text,
  add column if not exists work_end           text,

  -- 1_5 | 5_10 | 10_PLUS.
  add column if not exists max_distance       text
    check (max_distance is null
           or max_distance in ('1_5', '5_10', '10_PLUS'));

-- --- La famille : trois colonnes qui manquaient aussi ---------------------
--
-- Meme cause que `teachers.region` : l'application les tient depuis sa v7 et
-- sa v9, et elles n'ont jamais existe ici.
--
-- `children.subject_ids` est la plus couteuse des trois. C'est la reponse a
-- « dans quelles matieres a-t-il besoin d'aide », et c'est desormais elle qui
-- alimente la section « Pour sa classe » de l'accueil et le classement du
-- catalogue : sans elle, l'accueil se reconstruit vide sur un autre appareil.

alter table children
  -- L'enfant porte en general le nom du compte, mais pas toujours — familles
  -- recomposees, enfant confie a un oncle.
  add column if not exists last_name   text,
  -- Separees par des virgules, comme cote application.
  add column if not exists subject_ids text not null default '';

alter table parents
  -- `district` existe depuis 0001 ; la region, non.
  add column if not exists region text;

alter table institutions
  add column if not exists region   text,
  add column if not exists district text;

-- --- La formule choisie a l'inscription -----------------------------------
--
-- Le dernier ecran des quatre parcours propose une formule et rangeait sa
-- reponse sous `subscription` — une cle que **personne ne lisait** : la chaine
-- n'apparaissait nulle part dans le code de l'application. On choisissait PRO
-- et on obtenait un compte FREE, a rechoisir depuis la facturation.
--
-- Pourquoi une colonne distincte de `plan` : rien n'est encaisse a
-- l'inscription. L'ecrire dans `plan` offrirait la formule. On garde donc
-- l'intention, la facturation la presente en premier, et seul le paiement
-- deplace la valeur vers `plan`.
alter table profiles
  add column if not exists pending_plan text
    check (pending_plan is null
           or pending_plan in ('FREE', 'PRO', 'MASTER'));

comment on column teachers.service_types is
  'HOME, FULL_TIME ou les deux. Oriente ce qu''on lui montre : les offres '
  'd''emploi n''interessent pas qui ne veut que des cours a domicile.';
comment on column teachers.tutoring_days is
  'Creneaux a domicile. Pousses depuis le 03/10 vers une table inexistante '
  '(teacher_tutoring_availability) : chaque envoi echouait en 42P01.';
comment on column institutions.needed_subject_ids is
  'Besoin permanent, distinct d''une offre : prefixe la prochaine offre et '
  'sert a classer les professeurs des l''accueil.';
comment on column profiles.pending_plan is
  'Formule choisie a l''inscription et pas encore payee. Dans `plan`, elle '
  'serait offerte : rien n''est encaisse a l''inscription.';
