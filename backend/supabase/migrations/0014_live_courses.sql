-- Les cours en direct : la définition récurrente et ses séances (02/10).
--
-- Deux tables, et la distinction entre elles porte tout le reste :
--
--   `live_courses`  — ce qu'un professeur déclare une fois : « Mathématiques,
--                     Terminale, 45 000 GNF par élève, mardi et jeudi 18 h ».
--   `live_sessions` — les occurrences, générées à l'avance : le mardi 7, le
--                     jeudi 9, le mardi 14… C'est à une occurrence qu'un élève
--                     s'inscrit et qu'il paie, pas à la définition.
--
-- Confondre les deux obligerait à recréer un cours chaque semaine, et à
-- rattacher les paiements à un objet qui change.
--
-- --- Ce qui n'est pas réutilisé, et pourquoi ------------------------------
--
-- `tutoring_sessions` existe déjà, mais elle référence `tutoring_requests` :
-- un cours particulier, un élève, une demande. Une séance de groupe accueille
-- quinze élèves et ne naît d'aucune demande individuelle. Les deux concepts se
-- ressemblent et ne sont pas le même ; les mélanger aurait rendu toute requête
-- de planning ambiguë.

-- --- La définition récurrente --------------------------------------------

create table if not exists live_courses (
  id          text primary key default gen_random_uuid()::text,
  teacher_id  text not null references teachers (id) on delete cascade,
  subject_id  text not null references subjects (id),
  level_id    text not null references levels (id),

  title       text,
  description text,

  -- Prix payé par CHAQUE élève pour CHAQUE séance, et non prix de la séance
  -- entière partagé entre les inscrits. C'est la lecture qui rend les repères
  -- de la stratégie cohérents (voir strategy.md §5.1). La borne haute est une
  -- garde-fou contre une faute de frappe à sept chiffres, pas une règle
  -- commerciale.
  price       integer not null check (price between 1000 and 1000000),

  -- Quinze au maximum : au-delà, un professeur ne peut plus répondre à chacun
  -- pendant les pauses, ce qui est précisément ce qu'on vend.
  seats       integer not null default 15 check (seats between 1 and 15),

  -- Les identifiants de créneaux choisis — `WD_18`, `SAT_10`… La liste fermée
  -- vit dans `shared/scheduling/slots.json`, lue par le serveur et les deux
  -- clients. Elle n'est PAS recopiée en contrainte SQL : une contrainte à
  -- mettre à jour à chaque changement d'horaire finirait par mentir, et c'est
  -- le générateur qui refuse un créneau inconnu.
  slot_ids    text[] not null default '{}',

  status      text not null default 'DRAFT'
                check (status in ('DRAFT', 'PUBLISHED', 'ARCHIVED')),

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists live_courses_teacher_idx
  on live_courses (teacher_id, status);
create index if not exists live_courses_lookup_idx
  on live_courses (subject_id, level_id, status);

-- --- Les occurrences ------------------------------------------------------

create table if not exists live_sessions (
  id              text primary key default gen_random_uuid()::text,
  live_course_id  text not null references live_courses (id) on delete cascade,

  -- Le créneau dont cette séance est l'occurrence. Conservé pour pouvoir
  -- regénérer, comparer, et dire « le cours du mardi 18 h » sans recalculer.
  slot_id         text not null,

  starts_at       timestamptz not null,

  -- 90 minutes par défaut. Une colonne et non une constante : la salle se
  -- ferme sur cette valeur, donc un format plus court — rattrapage, révision
  -- avant examen — ne demandera ni migration ni déploiement.
  duration_minutes integer not null default 90
                     check (duration_minutes between 15 and 240),

  status          text not null default 'PLANNED'
                    check (status in ('PLANNED', 'LIVE', 'DONE', 'CANCELLED')),

  -- Le nom de la salle chez le fournisseur de visioconférence. Nul tant que
  -- le fournisseur n'est pas choisi : cette migration ne présuppose pas lequel.
  room_name       text,
  recording_url   text,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  -- Une seule séance par cours et par moment. C'est ce qui rend le générateur
  -- rejouable : il tourne chaque nuit et ne crée pas de doublons.
  unique (live_course_id, starts_at)
);

create index if not exists live_sessions_agenda_idx
  on live_sessions (starts_at, status);
create index if not exists live_sessions_course_idx
  on live_sessions (live_course_id, starts_at);

-- --- Qui voit quoi --------------------------------------------------------

alter table live_courses  enable row level security;
alter table live_sessions enable row level security;

-- Un cours publié est une vitrine : il se consulte sans compte, comme la
-- recherche de professeurs et le programme des cours vidéo. Un brouillon
-- n'appartient qu'à son auteur.
create policy "cours en direct : la vitrine est publique" on live_courses
  for select using (status = 'PUBLISHED' or teacher_id = my_teacher_id());

create policy "cours en direct : son professeur le gere" on live_courses
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

-- Une séance suit la visibilité de son cours : on doit pouvoir lire l'emploi
-- du temps avant de s'inscrire, sinon on paie sans savoir quand.
create policy "seance : visible avec son cours" on live_sessions
  for select using (
    exists (
      select 1 from live_courses c
      where c.id = live_course_id
        and (c.status = 'PUBLISHED' or c.teacher_id = my_teacher_id())
    )
  );

-- Le professeur annule ou renomme une séance ; il ne les crée pas à la main.
create policy "seance : son professeur la modifie" on live_sessions
  for update using (
    exists (
      select 1 from live_courses c
      where c.id = live_course_id and c.teacher_id = my_teacher_id()
    )
  );

-- **Aucune politique `insert` ni `delete`.** Les séances sont posées par le
-- générateur, sous la clé de service : laisser un client en créer ouvrirait
-- la porte à des séances hors créneau, hors prix, hors planning. L'absence est
-- la règle, pas un oubli.

comment on table live_courses is
  'Definition recurrente d''un cours en direct. price = par eleve et par '
  'seance (strategy.md §5.1).';
comment on table live_sessions is
  'Occurrences generees d''un live_course. C''est a une seance qu''on '
  's''inscrit et qu''on paie.';
