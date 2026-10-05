-- =====================================================================
-- Eduquali — schema complet pour un projet Supabase NEUF
-- =====================================================================
--
-- Genere le 2026-10-04 par `node backend/scripts/build-schema-file.mjs`.
-- NE PAS MODIFIER CE FICHIER : il est reecrit a chaque appel du script. La
-- verite vit dans `backend/supabase/migrations/`, que deux controles
-- verifient (`npm run check` dans `backend/`).
--
-- --- Ce qu'il fait ----------------------------------------------------------
--
-- Les 27 migrations, dans l'ordre. Certaines defont ce que les
-- precedentes ont fait — la 0008 retire le systeme de credits que la 0006
-- avait pose. C'est voulu : rejouer l'histoire donne exactement l'etat que les
-- deux controles valident, alors qu'un schema « nettoye » serait une version
-- que personne ne verifie.
--
-- --- Comment l'appliquer ----------------------------------------------------
--
-- Projet NEUF uniquement :
--   Supabase > SQL Editor > New query > coller ce fichier > Run.
--
-- Projet DEJA EN SERVICE : ne pas coller ceci. Appliquer seulement la
-- migration manquante, depuis `backend/supabase/migrations/`.
--
-- Puis, dans l'ordre :
--   1. `backend/supabase/seed.sql`            — matieres, niveaux, tests
--   2. `backend/supabase/seed_demo_teachers.sql` — donnees de demonstration
--      (a NE PAS charger sur une base destinee a de vrais comptes : elle
--      nomme des etablissements reels avec des offres inventees)
--
-- --- Ce qu'il ne fait pas ---------------------------------------------------
--
-- Il ne touche pas a `auth`. L'authentification reste celle de Supabase ;
-- `profiles.id` reference `auth.users (id)`, donc un compte metier n'existe
-- qu'en prolongement d'un compte d'authentification.
--
-- Il n'ouvre aucune donnee : chaque table est en RLS. **La cle anonyme est
-- publique par construction** — elle part dans le bundle du site — donc RLS
-- est la seule barriere. La cle `service_role` ne doit jamais quitter
-- `backend/.env`.
--
-- =====================================================================



-- Tout ou rien : une erreur en cours de route ne doit pas laisser la base a
-- moitie construite. Le DDL de Postgres est transactionnel.
begin;

-- ---------------------------------------------------------------------
-- 0001_schema.sql
-- ---------------------------------------------------------------------

-- Schema de la plateforme (§48).
--
-- Traduction du schema local Drift embarque dans l'application mobile. Les
-- noms de tables et de colonnes sont conserves a l'identique afin que la
-- synchronisation (§44) reste une correspondance directe, sans table de
-- transcodage.
--
-- Convention : identifiants texte (et non uuid) pour que le client puisse
-- creer une entite hors ligne et l'envoyer telle quelle (§41).

create extension if not exists "uuid-ossp";

-- --- Referentiel ----------------------------------------------------------

create table subjects (
  id          text primary key,
  name        text not null,
  code        text not null unique,
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table levels (
  id          text primary key,
  name        text not null,
  code        text not null unique,
  -- PRIMARY | SECONDARY | UNIVERSITY
  category    text not null,
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- --- Comptes --------------------------------------------------------------

-- Prolonge auth.users de Supabase : l'authentification (OTP) y reste geree,
-- ce profil ne porte que les donnees metier.
create table profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  role            text not null check (role in ('TEACHER', 'INSTITUTION', 'ADMIN', 'PARENT')),
  phone           text not null,
  email           text,
  first_name      text,
  last_name       text,
  city            text,
  photo_path      text,
  phone_verified  boolean not null default false,
  suspended       boolean not null default false,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index profiles_role_idx on profiles (role);

create table institutions (
  id                   text primary key default gen_random_uuid()::text,
  owner_id             uuid references profiles (id) on delete set null,
  name                 text not null,
  -- SCHOOL | HIGH_SCHOOL | UNIVERSITY | INSTITUTE | TRAINING_CENTER | OTHER
  type                 text not null,
  city                 text not null,
  address              text,
  manager_name         text,
  description          text,
  logo_path            text,
  verification_status  text not null default 'PENDING',
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index institutions_city_idx on institutions (city, type);

create table teachers (
  id                           text primary key default gen_random_uuid()::text,
  user_id                      uuid not null references profiles (id) on delete cascade,
  headline                     text,
  bio                          text,
  city                         text,
  years_experience             integer not null default 0,
  -- AVAILABLE | AVAILABLE_SOON | UNAVAILABLE
  availability                 text not null default 'AVAILABLE',
  available_from               date,
  identity_status              text not null default 'NONE',
  diploma_status               text not null default 'NONE',
  preferred_institution_types  text not null default '',
  preferred_contract_types     text not null default '',
  -- Option Visibilite+ (§35).
  boosted_until                timestamptz,
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  unique (user_id)
);

create index teachers_city_idx on teachers (city, availability);

-- --- Competences declarees ------------------------------------------------

create table teacher_subjects (
  id          text primary key default gen_random_uuid()::text,
  teacher_id  text not null references teachers (id) on delete cascade,
  subject_id  text not null references subjects (id),
  created_at  timestamptz not null default now(),
  unique (teacher_id, subject_id)
);

create index teacher_subjects_subject_idx on teacher_subjects (subject_id);

create table teacher_levels (
  id          text primary key default gen_random_uuid()::text,
  teacher_id  text not null references teachers (id) on delete cascade,
  subject_id  text not null references subjects (id),
  level_id    text not null references levels (id),
  created_at  timestamptz not null default now(),
  unique (teacher_id, subject_id, level_id)
);

create index teacher_levels_lookup_idx on teacher_levels (subject_id, level_id);

create table teacher_experiences (
  id                   text primary key default gen_random_uuid()::text,
  teacher_id           text not null references teachers (id) on delete cascade,
  institution_name     text not null,
  position             text not null,
  city                 text,
  start_date           date not null,
  end_date             date,
  is_current           boolean not null default false,
  description          text,
  verification_status  text not null default 'PENDING',
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table teacher_diplomas (
  id                 text primary key default gen_random_uuid()::text,
  teacher_id         text not null references teachers (id) on delete cascade,
  diploma_type       text not null,
  institution_name   text not null,
  field              text,
  speciality         text,
  graduation_year    integer not null,
  academic_level     text,
  document_id        text,
  status             text not null default 'PENDING',
  rejection_reason   text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- Documents sensibles (§46, §51-52).
--
-- Seul le chemin dans Supabase Storage est conserve ; aucune donnee extraite
-- d'une piece d'identite ne figure ici, et le bucket reste prive.
create table teacher_documents (
  id           text primary key default gen_random_uuid()::text,
  teacher_id   text not null references teachers (id) on delete cascade,
  -- SELFIE | ID_FRONT | ID_BACK | DIPLOMA | OTHER
  type         text not null,
  storage_path text,
  checksum     text,
  size_bytes   integer,
  status       text not null default 'PENDING_UPLOAD',
  -- Identifiant du travail de verification externe, sans son contenu.
  external_job_id text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index teacher_documents_teacher_idx on teacher_documents (teacher_id, type);

-- --- Evaluation (§10 a §13) -----------------------------------------------

create table tests (
  id                text primary key,
  subject_id        text not null references subjects (id),
  level_id          text not null references levels (id),
  title             text not null,
  question_count    integer not null,
  duration_minutes  integer not null,
  passing_score     integer not null default 70,
  rules             text,
  version           integer not null default 1,
  active            boolean not null default true,
  created_at        timestamptz not null default now(),
  unique (subject_id, level_id, version)
);

create table test_questions (
  id           text primary key,
  test_id      text not null references tests (id) on delete cascade,
  statement    text not null,
  options      jsonb not null,
  -- Jamais expose au client avant la correction : voir la vue publique.
  correct_key  text not null,
  domain       text not null,
  position     integer not null,
  difficulty   integer not null default 2,
  explanation  text
);

create index test_questions_test_idx on test_questions (test_id, position);

-- Vue sans la reponse : c'est elle que l'API sert pendant le test.
create view test_questions_public as
  select id, test_id, statement, options, domain, position, difficulty
  from test_questions;

create table test_sessions (
  id                 text primary key default gen_random_uuid()::text,
  teacher_id         text not null references teachers (id) on delete cascade,
  test_id            text not null references tests (id),
  -- IN_PROGRESS | SUBMITTED | EXPIRED | ABANDONED
  status             text not null default 'IN_PROGRESS',
  started_at         timestamptz not null default now(),
  expires_at         timestamptz not null,
  submitted_at       timestamptz,
  score              integer,
  passed             boolean,
  domain_scores      jsonb,
  correct_count      integer,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index test_sessions_teacher_idx on test_sessions (teacher_id, status);

create table test_answers (
  id           text primary key default gen_random_uuid()::text,
  session_id   text not null references test_sessions (id) on delete cascade,
  question_id  text not null references test_questions (id),
  answer_key   text,
  answered_at  timestamptz not null default now(),
  unique (session_id, question_id)
);

create table teacher_certifications (
  id          text primary key default gen_random_uuid()::text,
  teacher_id  text not null references teachers (id) on delete cascade,
  subject_id  text not null references subjects (id),
  level_id    text not null references levels (id),
  session_id  text references test_sessions (id),
  score       integer not null,
  issued_at   timestamptz not null default now(),
  expires_at  timestamptz,
  unique (teacher_id, subject_id, level_id)
);

create index certifications_lookup_idx
  on teacher_certifications (subject_id, level_id, score desc);

-- --- Offres et candidatures (§17, §18, §29) -------------------------------

create table jobs (
  id                      text primary key default gen_random_uuid()::text,
  institution_id          text not null references institutions (id) on delete cascade,
  title                   text not null,
  subject_id              text not null references subjects (id),
  level_ids               text[] not null default '{}',
  city                    text not null,
  contract_type           text not null,
  description             text,
  salary_min              integer,
  salary_max              integer,
  salary_published        boolean not null default false,
  min_experience          integer not null default 0,
  requires_certification  boolean not null default false,
  -- PUBLIC | PRIVATE (§29)
  visibility              text not null default 'PUBLIC',
  -- DRAFT | PUBLISHED | CLOSED | ARCHIVED
  status                  text not null default 'DRAFT',
  start_date              date,
  closes_at               timestamptz,
  published_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index jobs_status_idx on jobs (status, published_at desc);
create index jobs_subject_idx on jobs (subject_id, city);

create table applications (
  id                 text primary key default gen_random_uuid()::text,
  job_id             text not null references jobs (id) on delete cascade,
  teacher_id         text not null references teachers (id) on delete cascade,
  status             text not null default 'SENT',
  cover_note         text,
  -- Score fige au moment de la candidature, pour rester explicable (§22).
  match_score        integer,
  match_factors      jsonb,
  applied_at         timestamptz not null default now(),
  status_changed_at  timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (job_id, teacher_id)
);

create index applications_teacher_idx on applications (teacher_id, status);
create index applications_job_idx on applications (job_id, status);

-- --- Module parent / cours a domicile -------------------------------------

create table parents (
  id            text primary key default gen_random_uuid()::text,
  user_id       uuid not null references profiles (id) on delete cascade,
  city          text,
  district      text,
  address_line  text,
  landmark      text,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id)
);

create table children (
  id           text primary key default gen_random_uuid()::text,
  parent_id    text not null references parents (id) on delete cascade,
  first_name   text not null,
  level_id     text references levels (id),
  school_name  text,
  notes        text,
  created_at   timestamptz not null default now()
);

create table tutoring_services (
  id                 text primary key default gen_random_uuid()::text,
  teacher_id         text not null references teachers (id) on delete cascade,
  subject_id         text not null references subjects (id),
  level_ids          text[] not null default '{}',
  -- AT_STUDENT | AT_TEACHER | ONLINE
  mode               text not null default 'AT_STUDENT',
  hourly_rate        integer,
  city               text,
  districts          text[] not null default '{}',
  availability_note  text,
  description        text,
  active             boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index tutoring_lookup_idx on tutoring_services (active, subject_id, city);

create table tutoring_requests (
  id               text primary key default gen_random_uuid()::text,
  parent_id        text not null references parents (id) on delete cascade,
  service_id       text not null references tutoring_services (id) on delete cascade,
  child_id         text references children (id) on delete set null,
  status           text not null default 'SENT',
  message          text,
  preferred_start  date,
  responded_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- --- Journal de synchronisation (§44) -------------------------------------

-- Chaque changement recoit un numero croissant : le client redemande
-- uniquement ce qui suit son curseur.
create table sync_events (
  id          bigserial primary key,
  entity      text not null,
  entity_id   text not null,
  operation   text not null,
  -- Portee : qui doit recevoir ce changement.
  owner_id    uuid references profiles (id) on delete cascade,
  payload     jsonb,
  created_at  timestamptz not null default now()
);

create index sync_events_cursor_idx on sync_events (id, owner_id);

-- --- Horodatage automatique ------------------------------------------------

create or replace function touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'institutions', 'teachers', 'teacher_experiences',
    'teacher_diplomas', 'teacher_documents', 'test_sessions', 'jobs',
    'applications', 'parents', 'tutoring_services', 'tutoring_requests'
  ] loop
    execute format(
      'create trigger %I_touch before update on %I
       for each row execute function touch_updated_at()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 0002_rls.sql
-- ---------------------------------------------------------------------

-- Controle d'acces par role (§51).
--
-- Le controle vit dans la base, pas dans l'API : une requete directe depuis un
-- client, une cle publique fuitee ou un bug de routage ne doivent jamais
-- exposer les donnees d'autrui.
--
-- Regle structurante (§23, §30) : les coordonnees d'un enseignant restent
-- masquees tant que le recrutement n'est pas conclu. Le profil public est donc
-- une vue distincte, sans telephone ni email.

alter table profiles                enable row level security;
alter table teachers                enable row level security;
alter table teacher_subjects        enable row level security;
alter table teacher_levels          enable row level security;
alter table teacher_experiences     enable row level security;
alter table teacher_diplomas        enable row level security;
alter table teacher_documents       enable row level security;
alter table teacher_certifications  enable row level security;
alter table test_sessions           enable row level security;
alter table test_answers            enable row level security;
alter table institutions            enable row level security;
alter table jobs                    enable row level security;
alter table applications            enable row level security;
alter table parents                 enable row level security;
alter table children                enable row level security;
alter table tutoring_services       enable row level security;
alter table tutoring_requests       enable row level security;
alter table sync_events             enable row level security;

-- Le referentiel est public en lecture ; il n'est modifiable qu'en
-- back-office, via la cle de service qui contourne RLS.
alter table subjects       enable row level security;
alter table levels         enable row level security;
alter table tests          enable row level security;
alter table test_questions enable row level security;

create policy "referentiel lisible" on subjects for select using (true);
create policy "niveaux lisibles"    on levels   for select using (true);
create policy "tests lisibles"      on tests    for select using (true);

-- Les questions ne sont jamais lues directement par un client : l'API les
-- sert via la vue publique, sans la bonne reponse.
create policy "questions fermees" on test_questions for select using (false);

-- --- Helpers ---------------------------------------------------------------

create or replace function current_role_is(target text) returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role = target and not suspended
  );
$$ language sql stable security definer;

create or replace function my_teacher_id() returns text as $$
  select id from teachers where user_id = auth.uid();
$$ language sql stable security definer;

create or replace function my_institution_id() returns text as $$
  select id from institutions where owner_id = auth.uid();
$$ language sql stable security definer;

create or replace function my_parent_id() returns text as $$
  select id from parents where user_id = auth.uid();
$$ language sql stable security definer;

-- --- Profil ----------------------------------------------------------------

create policy "profil : lecture de soi" on profiles
  for select using (id = auth.uid());

create policy "profil : mise a jour de soi" on profiles
  for update using (id = auth.uid());

create policy "profil : creation de soi" on profiles
  for insert with check (id = auth.uid());

-- --- Enseignant ------------------------------------------------------------

-- Un enseignant gere sa fiche ; un etablissement consulte les fiches, mais
-- ne voit jamais la table `profiles` qui porte les coordonnees.
create policy "enseignant : gestion de sa fiche" on teachers
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "enseignant : consultable par un etablissement" on teachers
  for select using (current_role_is('INSTITUTION'));

do $$
declare t text;
begin
  foreach t in array array[
    'teacher_subjects', 'teacher_levels', 'teacher_experiences',
    'teacher_certifications'
  ] loop
    execute format($f$
      create policy "%1$s : gestion par l'enseignant" on %1$I
        for all using (teacher_id = my_teacher_id())
        with check (teacher_id = my_teacher_id());
      create policy "%1$s : lecture par un etablissement" on %1$I
        for select using (current_role_is('INSTITUTION'));
    $f$, t);
  end loop;
end $$;

-- Diplomes et documents : jamais visibles par un etablissement. Seul le
-- statut de verification transite, porte par la fiche enseignant (§14).
create policy "diplomes : prives" on teacher_diplomas
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "documents : prives" on teacher_documents
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

-- --- Sessions de test ------------------------------------------------------

create policy "sessions : les siennes" on test_sessions
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "reponses : les siennes" on test_answers
  for all using (
    session_id in (select id from test_sessions where teacher_id = my_teacher_id())
  ) with check (
    session_id in (select id from test_sessions where teacher_id = my_teacher_id())
  );

-- --- Etablissement ---------------------------------------------------------

create policy "etablissement : lecture publique" on institutions
  for select using (true);

create policy "etablissement : gestion par son responsable" on institutions
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Une offre publiee est visible de tous ; une offre privee (§29) ou un
-- brouillon ne l'est que de l'etablissement qui l'a creee.
create policy "offres : publiees visibles" on jobs
  for select using (
    (status = 'PUBLISHED' and visibility = 'PUBLIC')
    or institution_id = my_institution_id()
  );

create policy "offres : gestion par l'etablissement" on jobs
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

-- --- Candidatures ----------------------------------------------------------

create policy "candidatures : les siennes" on applications
  for select using (
    teacher_id = my_teacher_id()
    or job_id in (select id from jobs where institution_id = my_institution_id())
  );

create policy "candidatures : depot par l'enseignant" on applications
  for insert with check (teacher_id = my_teacher_id());

-- L'etablissement fait avancer le statut ; l'enseignant ne le modifie pas.
create policy "candidatures : suivi par l'etablissement" on applications
  for update using (
    job_id in (select id from jobs where institution_id = my_institution_id())
  );

-- --- Module parent ---------------------------------------------------------

create policy "parent : gestion de sa fiche" on parents
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "enfants : geres par le parent" on children
  for all using (parent_id = my_parent_id())
  with check (parent_id = my_parent_id());

-- Une offre de cours active est publique : c'est ce qu'un parent vient
-- chercher. L'enseignant reste seul a pouvoir la modifier.
create policy "cours : offres actives visibles" on tutoring_services
  for select using (active or teacher_id = my_teacher_id());

create policy "cours : gestion par l'enseignant" on tutoring_services
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "demandes : parent et enseignant concernes" on tutoring_requests
  for select using (
    parent_id = my_parent_id()
    or service_id in (select id from tutoring_services where teacher_id = my_teacher_id())
  );

create policy "demandes : envoi par le parent" on tutoring_requests
  for insert with check (parent_id = my_parent_id());

create policy "demandes : reponse de l'enseignant" on tutoring_requests
  for update using (
    service_id in (select id from tutoring_services where teacher_id = my_teacher_id())
  );

-- --- Synchronisation -------------------------------------------------------

create policy "sync : ses propres evenements" on sync_events
  for select using (owner_id is null or owner_id = auth.uid());

-- --- Profil public d'un enseignant (§15, §23) ------------------------------

-- Vue servie aux etablissements : identite professionnelle et preuves
-- verifiees, sans aucune coordonnee personnelle. Le telephone n'apparait
-- qu'apres signature du contrat, et il transite alors par l'API.
create view teacher_public_profiles as
  select
    t.id,
    p.first_name,
    p.last_name,
    p.photo_path,
    t.headline,
    t.bio,
    t.city,
    t.years_experience,
    t.availability,
    t.identity_status,
    t.diploma_status,
    t.boosted_until
  from teachers t
  join profiles p on p.id = t.user_id
  where not p.suspended;

-- La vue s'execute avec les droits de l'appelant : les politiques de
-- `teachers` et `profiles` continuent donc de s'appliquer.
alter view teacher_public_profiles set (security_invoker = true);


-- ---------------------------------------------------------------------
-- 0003_audit.sql
-- ---------------------------------------------------------------------

-- Journal d'audit (§5 du code_skill, §51).
--
-- « Qui a fait quoi, quand, depuis ou. » Une plateforme qui delivre des
-- certifications et manipule des pieces d'identite doit pouvoir le dire :
-- sans ce journal, une certification contestee est indefendable.
--
-- Ce que la table ne contient jamais : mots de passe, jetons, codes OTP et
-- reponses de test. L'assainissement a lieu dans l'API (api/_lib/audit.ts)
-- avant l'ecriture et avant le calcul de l'empreinte.

create table audit_events (
  id              bigserial primary key,
  method          text not null,
  path            text not null,
  status          integer not null,
  -- Nul pour un appel non authentifie : on garde la trace quand meme.
  user_id         uuid references profiles (id) on delete set null,
  ip              text,
  user_agent      text,
  duration_ms     integer not null default 0,
  -- Charge utile deja assainie, bornee cote API.
  payload         jsonb,
  -- Empreinte de la charge assainie : detecte une alteration a posteriori.
  payload_sha256  text not null,
  created_at      timestamptz not null default now()
);

create index audit_events_created_idx on audit_events (created_at desc);
create index audit_events_user_idx on audit_events (user_id, created_at desc);
create index audit_events_path_idx on audit_events (path, created_at desc);

-- Personne ne lit ce journal depuis un client. L'ecriture passe par la cle de
-- service, la lecture par le back-office administrateur (§57).
alter table audit_events enable row level security;
create policy "audit : ferme aux clients" on audit_events for select using (false);

-- La table ne fait que grossir : §4.6 demande une purge. A brancher sur un
-- cron une fois le back-office en place (retention 12 mois).
create or replace function purge_audit_events(retention_months integer default 12)
returns integer as $$
declare removed integer;
begin
  delete from audit_events
  where created_at < now() - make_interval(months => retention_months);
  get diagnostics removed = row_count;
  return removed;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;


-- ---------------------------------------------------------------------
-- 0004_enrolments.sql
-- ---------------------------------------------------------------------

-- Inscriptions scolaires et durcissement des roles (§55-bis).
--
-- Chaine : 0001 schema -> 0002 rls -> 0003 audit -> 0004 inscriptions.
--
-- Decision : le compte appartient au PARENT, pas a l'eleve.
--
-- Un eleve de college ou de lycee est mineur : lui faire ouvrir un compte
-- deplacait le consentement sur un enfant. Le parent ouvre le compte, declare
-- ses enfants (prenom + classe) et agit pour eux. Les tables `parents` et
-- `children` de 0001 sont donc conservees telles quelles ; cette migration
-- les complete au lieu de les remplacer.
--
-- Ce que le parent peut faire : demander une inscription dans un
-- etablissement, et demander un repetiteur.

-- --- Le role ------------------------------------------------------------
--
-- `PARENT` figurait deja dans la contrainte de 0001. On la reecrit seulement
-- pour qu'elle soit nommee et donc remplacable par la suite.

alter table profiles drop constraint if exists profiles_role_check;
alter table profiles
  add constraint profiles_role_check
  check (role in ('TEACHER', 'INSTITUTION', 'PARENT', 'ADMIN'));

-- --- La fiche enfant porte desormais sa scolarite ------------------------

alter table children
  add column if not exists status text not null default 'SEEKING'
    check (status in ('ENROLLED', 'SEEKING')),
  -- L'etablissement du catalogue quand il y figure...
  add column if not exists institution_id text
    references institutions (id) on delete set null;

-- ...et sa saisie libre sinon : le catalogue ne couvre pas tout le pays.
-- `school_name` existe deja en 0001 et joue ce role.

create index if not exists children_level_idx on children (level_id);

-- --- Demandes d'inscription ---------------------------------------------
--
-- Meme forme que `applications` : le demandeur propose, l'etablissement
-- decide. Une demande par enfant, par etablissement et par annee scolaire —
-- se reinscrire l'annee suivante est une nouvelle demande.
--
-- La demande est rattachee a l'enfant ET au parent : l'enfant designe la
-- scolarite concernee, le parent reste la personne qui consent et que
-- l'etablissement rappelle.

create table enrolment_requests (
  id                 text primary key default gen_random_uuid()::text,
  parent_id          text not null references parents (id) on delete cascade,
  child_id           text not null references children (id) on delete cascade,
  institution_id     text not null references institutions (id) on delete cascade,
  level_id           text references levels (id),
  -- SENT | VIEWED | ACCEPTED | REJECTED | CANCELLED
  status             text not null default 'SENT'
                     check (status in ('SENT', 'VIEWED', 'ACCEPTED', 'REJECTED', 'CANCELLED')),
  message            text check (char_length(message) <= 2000),
  -- « 2026-2027 » : porte par la demande pour rester lisible dans dix ans.
  school_year        text not null,
  responded_at       timestamptz,
  status_changed_at  timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (child_id, institution_id, school_year)
);

create index enrolment_parent_idx on enrolment_requests (parent_id, status);
create index enrolment_institution_idx
  on enrolment_requests (institution_id, status, created_at desc);

-- --- Cours a domicile : la demande designe l'enfant concerne -------------

alter table tutoring_requests
  add column if not exists mode text
    check (mode in ('AT_STUDENT', 'AT_TEACHER', 'ONLINE'));

-- --- Horodatage ----------------------------------------------------------

create trigger enrolment_requests_touch
  before update on enrolment_requests
  for each row execute function touch_updated_at();

-- --- Controle d'acces ----------------------------------------------------

alter table enrolment_requests enable row level security;

-- Les fonctions d'aide de 0002 n'avaient pas de `search_path` fige. Sans lui,
-- un schema place devant `public` par l'appelant detourne la resolution des
-- tables a l'interieur d'une fonction `security definer`. Une migration ne se
-- reecrit pas : on les remplace ici.
create or replace function current_role_is(target text) returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role = target and not suspended
  );
$$ language sql stable security definer set search_path = public, pg_temp;

create or replace function my_teacher_id() returns text as $$
  select id from teachers where user_id = auth.uid();
$$ language sql stable security definer set search_path = public, pg_temp;

create or replace function my_institution_id() returns text as $$
  select id from institutions where owner_id = auth.uid();
$$ language sql stable security definer set search_path = public, pg_temp;

create or replace function my_parent_id() returns text as $$
  select id from parents where user_id = auth.uid();
$$ language sql stable security definer set search_path = public, pg_temp;

create policy "inscriptions : les siennes" on enrolment_requests
  for select using (
    parent_id = my_parent_id()
    or institution_id = my_institution_id()
  );

create policy "inscriptions : depot par le parent" on enrolment_requests
  for insert with check (
    parent_id = my_parent_id()
    -- L'enfant designe doit bien etre le sien.
    and child_id in (select id from children where parent_id = my_parent_id())
  );

-- L'etablissement fait avancer le statut ; le parent ne peut qu'annuler, ce
-- que l'API traduit en `CANCELLED`.
create policy "inscriptions : reponse de l'etablissement" on enrolment_requests
  for update using (institution_id = my_institution_id());

create policy "inscriptions : annulation par le parent" on enrolment_requests
  for update using (parent_id = my_parent_id())
  with check (parent_id = my_parent_id());

-- Un etablissement ne voit un enfant que si une demande le lui a adresse.
create policy "enfants : visibles de l'etablissement sollicite" on children
  for select using (
    id in (
      select child_id from enrolment_requests
      where institution_id = my_institution_id()
    )
  );

-- --- Durcissement des roles ----------------------------------------------
--
-- Les politiques s'appuient sur `profiles.role`, et la politique de mise a
-- jour du profil ne restreint aucune colonne : un compte pouvait s'attribuer
-- `role = 'INSTITUTION'` et lire les fiches des enfants adressees a
-- n'importe quel etablissement. Le role cesse d'etre modifiable par son
-- porteur.

revoke update (role, suspended) on profiles from authenticated, anon;

-- Ceinture et bretelles : un GRANT reintroduit par erreur ne suffirait pas a
-- rouvrir la breche.
create or replace function profiles_guard() returns trigger as $$
begin
  if new.role is distinct from old.role then
    raise exception 'Le role d''un compte ne se change pas depuis le client.';
  end if;
  if new.suspended is distinct from old.suspended then
    raise exception 'La suspension d''un compte releve du back-office.';
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

create trigger profiles_guard_role
  before update on profiles
  for each row
  -- La cle de service porte le role `service_role` : le back-office passe.
  when (current_setting('request.jwt.claim.role', true) is distinct from 'service_role')
  execute function profiles_guard();


-- ---------------------------------------------------------------------
-- 0005_institution_details.sql
-- ---------------------------------------------------------------------

-- Fiche detaillee d'un etablissement (§19).
--
-- Chaine : 0001 schema -> 0002 rls -> 0003 audit -> 0004 inscriptions
--          -> 0005 fiche etablissement.
--
-- Ce qu'un candidat ou un parent regarde avant de s'engager : depuis quand
-- l'etablissement existe, qui le tient, ce qu'on y etudie et ce qu'on y
-- trouve. Colonnes additives : sans risque sur une base en service.
--
-- Les listes restent des chaines separees par des virgules plutot que des
-- tables. C'est une donnee d'affichage : on ne cherche jamais « tous les
-- etablissements qui enseignent le droit » depuis cet ecran, et une table de
-- liaison par filiere couterait une jointure pour rien. A revoir le jour ou
-- la recherche par filiere existe.

alter table institutions
  -- Les etablissements publient souvent deux numeros.
  add column if not exists phone           text,
  add column if not exists phone_alt       text,
  add column if not exists email           text,
  add column if not exists website         text,
  add column if not exists founded_year    integer
    check (founded_year is null or founded_year between 1800 and 2200),
  -- PUBLIC ou PRIVATE.
  add column if not exists ownership       text
    check (ownership is null or ownership in ('PUBLIC', 'PRIVATE')),
  -- « LMD » pour le superieur, « SECONDAIRE », « PROFESSIONNEL »...
  add column if not exists academic_system text,
  -- BTS, LICENCE, MASTER, DOCTORAT, CAP, BAC...
  add column if not exists degrees         text not null default '',
  add column if not exists specialties     text not null default '',
  add column if not exists facilities      text not null default '';

create index if not exists institutions_ownership_idx
  on institutions (ownership, city);


-- ---------------------------------------------------------------------
-- 0006_sync_parity.sql
-- ---------------------------------------------------------------------

-- Mise a niveau du schema serveur sur celui de l'application (24/09).
--
-- Au moment d'ecrire ceci, vingt et une des quarante-cinq tables de
-- l'application n'avaient aucun equivalent ici. Rien ne le signalait :
-- l'application fonctionne entierement hors ligne, donc tout marchait sur le
-- telephone pendant que le serveur etait incapable de recevoir la moitie de
-- ce qu'elle produit. `npm run check:schema` le signale desormais.
--
-- Meme convention que 0001 : identifiants texte, pour qu'une entite creee
-- hors ligne s'envoie telle quelle (§41). Noms de tables et de colonnes
-- identiques a ceux de Drift, pour que la synchronisation reste une
-- correspondance directe (§44).

-- --- Referentiel : profils de lycee (§9) ----------------------------------

create table filieres (
  id                 text primary key,
  name               text not null,
  code               text not null unique,
  note               text not null default '',
  cycle              text not null default 'LYCEE',
  -- Listes separees par des virgules, comme cote client : la sequence sert
  -- a l'affichage et n'est jamais jointe.
  level_ids          text not null default '',
  major_subject_ids  text not null default '',
  subject_ids        text not null default '',
  sort_order         integer not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

alter table children add column if not exists filiere_id text references filieres (id) on delete set null;
alter table levels   add column if not exists cycle text not null default '';
alter table levels   add column if not exists grouping boolean not null default false;
alter table subjects add column if not exists cycles text not null default '';
alter table teachers add column if not exists profile_views integer not null default 0;

-- --- Cours a domicile : les seances nees d'une demande acceptee -----------

create table tutoring_sessions (
  id                text primary key,
  request_id        text not null references tutoring_requests (id) on delete cascade,
  starts_at         timestamptz not null,
  duration_minutes  integer not null default 90,
  status            text not null default 'PLANNED'
                      check (status in ('PLANNED', 'DONE', 'CANCELLED')),
  topic             text,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index tutoring_sessions_request_idx on tutoring_sessions (request_id, starts_at);

-- --- Contrats de travail et echeances -------------------------------------
--
-- Distincts des contrats de recrutement (`contracts`, plus bas) : ceux-la
-- portent une signature et un PDF, ceux-ci portent un montant mensuel et un
-- echeancier. Un meme mot pour deux objets differents avait deja cree une
-- collision de noms cote client.

create table work_contracts (
  id              text primary key,
  teacher_id      text not null references teachers (id) on delete cascade,
  institution_id  text references institutions (id) on delete set null,
  parent_id       text references parents (id) on delete set null,
  child_id        text references children (id) on delete set null,
  subject_id      text references subjects (id) on delete set null,
  label           text not null,
  status          text not null default 'PENDING'
                    check (status in ('PENDING', 'ACTIVE', 'ENDED')),
  monthly_amount  integer not null default 0 check (monthly_amount >= 0),
  started_at      timestamptz,
  ended_at        timestamptz,
  end_reason      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- Un contrat lie un professeur a un employeur : une ecole ou une famille,
  -- jamais ni l'un ni l'autre.
  constraint work_contracts_employer
    check (institution_id is not null or parent_id is not null)
);

create index work_contracts_teacher_idx     on work_contracts (teacher_id);
create index work_contracts_institution_idx on work_contracts (institution_id);
create index work_contracts_parent_idx      on work_contracts (parent_id);

create table contract_payments (
  id           text primary key,
  contract_id  text not null references work_contracts (id) on delete cascade,
  due_on       timestamptz not null,
  amount       integer not null check (amount >= 0),
  status       text not null default 'DUE'
                 check (status in ('DUE', 'PAID', 'LATE')),
  paid_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index contract_payments_contract_idx on contract_payments (contract_id, due_on);

-- --- Catalogue de cours video ---------------------------------------------

create table video_courses (
  id              text primary key,
  teacher_id      text not null references teachers (id) on delete cascade,
  title           text not null,
  description     text,
  subject_id      text references subjects (id) on delete set null,
  level_ids       text not null default '',
  price           integer not null default 0 check (price >= 0),
  video_paths     text not null default '',
  cover_path      text,
  status          text not null default 'DRAFT'
                    check (status in ('DRAFT', 'PUBLISHED', 'HIDDEN')),
  purchase_count  integer not null default 0 check (purchase_count >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index video_courses_teacher_idx on video_courses (teacher_id, status);

create table course_purchases (
  id          text primary key,
  course_id   text not null references video_courses (id) on delete cascade,
  parent_id   text not null references parents (id) on delete cascade,
  -- Le prix et la commission sont figes a l'achat : changer le prix d'un
  -- cours ne doit pas reecrire ce qui a deja ete regle.
  amount      integer not null check (amount >= 0),
  commission  integer not null default 0 check (commission >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- On n'achete pas deux fois le meme cours.
  unique (course_id, parent_id)
);

-- --- Visibilite payante d'un etablissement --------------------------------

create table promotions (
  id              text primary key,
  institution_id  text not null references institutions (id) on delete cascade,
  title           text not null,
  message         text,
  media_paths     text not null default '',
  credit_cost     integer not null default 0 check (credit_cost >= 0),
  status          text not null default 'DRAFT'
                    check (status in ('DRAFT', 'ACTIVE', 'ENDED')),
  starts_at       timestamptz,
  ends_at         timestamptz,
  views           integer not null default 0 check (views >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- --- Moyens de paiement ---------------------------------------------------
--
-- Aucun numero complet n'est conserve : seulement les quatre derniers
-- chiffres et le porteur, de quoi reconnaitre le moyen sans pouvoir s'en
-- servir. Le prelevement passe par l'agregateur, qui detient le mandat.

create table payment_methods (
  id          text primary key,
  user_id     uuid not null references profiles (id) on delete cascade,
  kind        text not null check (kind in ('MOBILE_MONEY', 'CARD', 'CASH')),
  holder      text,
  last4       text not null default '' check (length(last4) <= 4),
  is_default  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index payment_methods_user_idx on payment_methods (user_id);

-- --- Espace de recrutement (§23 a §28) -------------------------------------

create table recruitment_rooms (
  id              text primary key,
  application_id  text references applications (id) on delete cascade,
  job_id          text references jobs (id) on delete cascade,
  teacher_id      text not null references teachers (id) on delete cascade,
  institution_id  text references institutions (id) on delete cascade,
  stage           text not null default 'APPLICATION',
  internal_notes  text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index recruitment_rooms_teacher_idx     on recruitment_rooms (teacher_id);
create index recruitment_rooms_institution_idx on recruitment_rooms (institution_id);

-- Fil entre une famille et un professeur (24/09).
--
-- Distinct d'un espace de recrutement : celui-la porte une candidature, une
-- offre, un contrat et des etapes, qui n'ont pas de sens entre un parent et
-- un repetiteur.
create table conversations (
  id          text primary key,
  teacher_id  text not null references teachers (id) on delete cascade,
  parent_id   text not null references parents (id) on delete cascade,
  request_id  text references tutoring_requests (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index conversations_teacher_idx on conversations (teacher_id);
create index conversations_parent_idx  on conversations (parent_id);

-- Une seule table de messages pour les deux familles de fils.
--
-- Deux tables auraient fini par ne plus masquer les memes coordonnees, et
-- c'est la seule regle du produit qu'on ne peut pas appliquer a moitie
-- (§30). `body` conserve le texte d'origine : le masquage est une couche
-- d'affichage, revocable une fois le recrutement conclu.
create table messages (
  id               text primary key,
  room_id          text references recruitment_rooms (id) on delete cascade,
  conversation_id  text references conversations (id) on delete cascade,
  sender_id        text not null,
  sender_role      text not null,
  body             text not null check (length(body) <= 4000),
  attachment_path  text,
  attachment_name  text,
  masked           boolean not null default false,
  sent_at          timestamptz not null default now(),
  read_at          timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- Un message appartient a l'un ou a l'autre, jamais aux deux, jamais a
  -- aucun : sans cette contrainte, un message orphelin reste invisible pour
  -- tout le monde et indetectable.
  constraint messages_one_thread check (
    (room_id is not null) <> (conversation_id is not null)
  )
);

create index messages_room_idx         on messages (room_id, sent_at);
create index messages_conversation_idx on messages (conversation_id, sent_at);

create table interviews (
  id            text primary key,
  room_id       text not null references recruitment_rooms (id) on delete cascade,
  scheduled_at  timestamptz not null,
  mode          text not null default 'ON_SITE',
  status        text not null default 'PROPOSED',
  location      text,
  meeting_link  text,
  comment       text,
  feedback      text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table recruitment_offers (
  id                 text primary key,
  room_id            text not null references recruitment_rooms (id) on delete cascade,
  position           text not null,
  subject_id         text references subjects (id) on delete set null,
  level_ids          text not null default '',
  contract_type      text not null,
  monthly_salary     integer not null check (monthly_salary >= 0),
  start_date         timestamptz not null,
  duration_months    integer check (duration_months > 0),
  trial_period_days  integer check (trial_period_days >= 0),
  schedule           text,
  extra_conditions   text,
  status             text not null default 'DRAFT',
  change_request     text,
  sent_at            timestamptz,
  responded_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table contracts (
  id                         text primary key,
  room_id                    text not null references recruitment_rooms (id) on delete cascade,
  offer_id                   text not null references recruitment_offers (id) on delete cascade,
  reference                  text not null unique,
  body_text                  text not null,
  pdf_path                   text,
  status                     text not null default 'DRAFT',
  teacher_signature_path     text,
  teacher_signed_at          timestamptz,
  institution_signature_path text,
  institution_signed_at      timestamptz,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);

create table recruitments (
  id                   text primary key,
  room_id              text not null references recruitment_rooms (id) on delete cascade,
  teacher_id           text not null references teachers (id) on delete cascade,
  institution_id       text not null references institutions (id) on delete cascade,
  contract_id          text references contracts (id) on delete set null,
  start_date           timestamptz not null,
  monthly_salary       integer not null check (monthly_salary >= 0),
  trial_period_days    integer check (trial_period_days >= 0),
  active               boolean not null default true,
  completed_milestones text not null default '',
  success_fee_amount   integer not null default 0 check (success_fee_amount >= 0),
  fee_paid             boolean not null default false,
  ended_at             timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table recruitment_events (
  id          text primary key,
  room_id     text not null references recruitment_rooms (id) on delete cascade,
  from_stage  text,
  to_stage    text not null,
  note        text,
  actor_id    text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index recruitment_events_room_idx on recruitment_events (room_id, created_at);

-- Note laissee par un etablissement apres un palier (§62).
create table teacher_reviews (
  id              text primary key,
  recruitment_id  text not null references recruitments (id) on delete cascade,
  teacher_id      text not null references teachers (id) on delete cascade,
  institution_id  text not null references institutions (id) on delete cascade,
  milestone_days  integer not null,
  punctuality     integer not null check (punctuality between 0 and 100),
  pedagogy        integer not null check (pedagogy between 0 and 100),
  subject_mastery integer not null check (subject_mastery between 0 and 100),
  professionalism integer not null check (professionalism between 0 and 100),
  attendance      integer not null check (attendance between 0 and 100),
  overall         integer not null check (overall between 0 and 100),
  comment         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- Un palier ne se note qu'une fois.
  unique (recruitment_id, milestone_days)
);

create table job_invitations (
  id          text primary key,
  job_id      text not null references jobs (id) on delete cascade,
  teacher_id  text not null references teachers (id) on delete cascade,
  status      text not null default 'SENT',
  message     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (job_id, teacher_id)
);

-- --- Notifications --------------------------------------------------------

create table notifications (
  id          text primary key,
  user_id     uuid not null references profiles (id) on delete cascade,
  kind        text not null,
  title       text not null,
  body        text not null,
  route       text,
  payload     text,
  read        boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index notifications_user_idx on notifications (user_id, read, created_at desc);

-- --- Assistant IA : credits et cours produits -----------------------------

-- Un grand livre, jamais un solde : le solde est la somme des lignes, ce qui
-- rend toute correction tracable et empeche deux ecritures concurrentes de
-- s'ecraser.
create table credit_ledger (
  id          bigserial primary key,
  owner_id    uuid not null references profiles (id) on delete cascade,
  kind        text not null,
  amount      integer not null,
  feature     text,
  reference   text,
  created_at  timestamptz not null default now()
);

create index credit_ledger_owner_idx on credit_ledger (owner_id, created_at);

create table ai_courses (
  id           text primary key,
  owner_id     uuid not null references profiles (id) on delete cascade,
  course_id    text not null,
  version      integer not null check (version > 0),
  title        text not null,
  course_json  jsonb not null,
  docx_path    text,
  xlsx_path    text,
  demo         boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Une version d'un cours n'existe qu'une fois.
  unique (course_id, version)
);

create index ai_courses_owner_idx on ai_courses (owner_id, created_at desc);


-- ---------------------------------------------------------------------
-- 0007_rls_parity.sql
-- ---------------------------------------------------------------------

-- Controle d'acces des tables ajoutees en 0006 (§51).
--
-- Une table sans RLS dans Supabase est lisible par n'importe quel porteur de
-- la cle publique — celle qui est, par construction, dans le site et dans
-- l'APK. Activer RLS sans ecrire de politique ferme tout ; ecrire la table
-- sans activer RLS ouvre tout. Les deux se font ici, dans le meme fichier,
-- pour qu'on ne puisse pas faire l'un sans l'autre.
--
-- Les fonctions `my_teacher_id()`, `my_parent_id()`, `my_institution_id()` et
-- `current_role_is()` viennent de 0002.

-- --- Referentiel : lisible par tous, ecrit en back-office -----------------

alter table filieres enable row level security;
create policy "profils de lycee lisibles" on filieres for select using (true);

-- --- Tout le reste : ferme par defaut -------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'tutoring_sessions', 'work_contracts', 'contract_payments',
    'video_courses', 'course_purchases', 'promotions', 'payment_methods',
    'recruitment_rooms', 'conversations', 'messages', 'interviews',
    'recruitment_offers', 'contracts', 'recruitments', 'recruitment_events',
    'teacher_reviews', 'job_invitations', 'notifications', 'credit_ledger',
    'ai_courses'
  ] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- --- Cours a domicile ------------------------------------------------------

-- Une seance se lit des deux cotes : la famille qui paie et le professeur
-- qui se deplace. Aucun des deux ne voit celles des autres.
create policy "seance : les deux parties" on tutoring_sessions
  for select using (
    exists (
      select 1
      from tutoring_requests r
      join tutoring_services s on s.id = r.service_id
      where r.id = request_id
        and (r.parent_id = my_parent_id() or s.teacher_id = my_teacher_id())
    )
  );

-- Seul le professeur programme, deplace ou annule : c'est lui qui se
-- deplace, et une seance modifiable des deux cotes finit par ne plus dire la
-- meme heure aux deux.
create policy "seance : le professeur la conduit" on tutoring_sessions
  for all using (
    exists (
      select 1
      from tutoring_requests r
      join tutoring_services s on s.id = r.service_id
      where r.id = request_id and s.teacher_id = my_teacher_id()
    )
  ) with check (
    exists (
      select 1
      from tutoring_requests r
      join tutoring_services s on s.id = r.service_id
      where r.id = request_id and s.teacher_id = my_teacher_id()
    )
  );

-- --- Contrats de travail et echeances -------------------------------------

create policy "contrat : les parties concernees" on work_contracts
  for select using (
    teacher_id = my_teacher_id()
    or institution_id = my_institution_id()
    or parent_id = my_parent_id()
  );

-- L'employeur ecrit le contrat ; le professeur le lit. Un professeur qui
-- pourrait modifier son propre montant mensuel n'aurait pas besoin d'en
-- discuter.
create policy "contrat : l employeur l ecrit" on work_contracts
  for all using (
    institution_id = my_institution_id() or parent_id = my_parent_id()
  ) with check (
    institution_id = my_institution_id() or parent_id = my_parent_id()
  );

create policy "echeance : les parties du contrat" on contract_payments
  for select using (
    exists (
      select 1 from work_contracts c
      where c.id = contract_id
        and (c.teacher_id = my_teacher_id()
             or c.institution_id = my_institution_id()
             or c.parent_id = my_parent_id())
    )
  );

-- Seul celui qui paie marque une echeance comme reglee.
create policy "echeance : celui qui paie" on contract_payments
  for update using (
    exists (
      select 1 from work_contracts c
      where c.id = contract_id
        and (c.institution_id = my_institution_id()
             or c.parent_id = my_parent_id())
    )
  );

-- --- Catalogue de cours video ---------------------------------------------

-- Un cours en vente est public : c'est une vitrine. Les brouillons et les
-- cours retires n'appartiennent qu'a leur auteur.
create policy "cours : la vitrine est publique" on video_courses
  for select using (status = 'PUBLISHED' or teacher_id = my_teacher_id());

create policy "cours : son auteur le gere" on video_courses
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "achat : l acheteur et le vendeur" on course_purchases
  for select using (
    parent_id = my_parent_id()
    or exists (
      select 1 from video_courses v
      where v.id = course_id and v.teacher_id = my_teacher_id()
    )
  );

create policy "achat : c est l acheteur qui achete" on course_purchases
  for insert with check (parent_id = my_parent_id());

-- --- Promotions ------------------------------------------------------------

create policy "promotion : visible quand elle est active" on promotions
  for select using (status = 'ACTIVE' or institution_id = my_institution_id());

create policy "promotion : son etablissement la gere" on promotions
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

-- --- Moyens de paiement ----------------------------------------------------
--
-- Strictement personnels. Aucun autre role, aucune lecture croisee.

create policy "moyen de paiement : le sien seulement" on payment_methods
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- --- Espace de recrutement -------------------------------------------------

create policy "salon : ses deux parties" on recruitment_rooms
  for select using (
    teacher_id = my_teacher_id() or institution_id = my_institution_id()
  );

create policy "salon : l etablissement le mene" on recruitment_rooms
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

create policy "conversation : ses deux parties" on conversations
  for select using (
    teacher_id = my_teacher_id() or parent_id = my_parent_id()
  );

create policy "conversation : ouverte par une partie" on conversations
  for insert with check (
    teacher_id = my_teacher_id() or parent_id = my_parent_id()
  );

-- Un message se lit si l'on appartient a son fil, quel qu'il soit.
create policy "message : lecture dans son fil" on messages
  for select using (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id
        and (r.teacher_id = my_teacher_id()
             or r.institution_id = my_institution_id())
    )
    or exists (
      select 1 from conversations c
      where c.id = conversation_id
        and (c.teacher_id = my_teacher_id() or c.parent_id = my_parent_id())
    )
  );

-- On n'ecrit que sous son propre nom, et seulement dans un fil dont on fait
-- partie. Sans la premiere condition, n'importe quel membre du fil pourrait
-- signer un message du nom de l'autre.
create policy "message : ecriture sous son nom" on messages
  for insert with check (
    sender_id = auth.uid()::text
    and (
      exists (
        select 1 from recruitment_rooms r
        where r.id = room_id
          and (r.teacher_id = my_teacher_id()
               or r.institution_id = my_institution_id())
      )
      or exists (
        select 1 from conversations c
        where c.id = conversation_id
          and (c.teacher_id = my_teacher_id() or c.parent_id = my_parent_id())
      )
    )
  );

-- Marquer comme lu est la seule modification permise ; le corps d'un message
-- envoye ne se reecrit pas.
create policy "message : marquer comme lu" on messages
  for update using (
    exists (
      select 1 from conversations c
      where c.id = conversation_id
        and (c.teacher_id = my_teacher_id() or c.parent_id = my_parent_id())
    )
    or exists (
      select 1 from recruitment_rooms r
      where r.id = room_id
        and (r.teacher_id = my_teacher_id()
             or r.institution_id = my_institution_id())
    )
  );

-- Entretiens, offres, contrats, embauches, journal : meme regle que leur
-- salon. L'etablissement ecrit, le professeur lit et repond via l'API.
do $$
declare t text;
begin
  foreach t in array array[
    'interviews', 'recruitment_offers', 'recruitment_events'
  ] loop
    execute format($f$
      create policy "%1$s : lecture dans son salon" on %1$I
        for select using (
          exists (
            select 1 from recruitment_rooms r
            where r.id = room_id
              and (r.teacher_id = my_teacher_id()
                   or r.institution_id = my_institution_id())
          )
        );
      create policy "%1$s : l etablissement ecrit" on %1$I
        for all using (
          exists (
            select 1 from recruitment_rooms r
            where r.id = room_id and r.institution_id = my_institution_id()
          )
        ) with check (
          exists (
            select 1 from recruitment_rooms r
            where r.id = room_id and r.institution_id = my_institution_id()
          )
        );
    $f$, t);
  end loop;
end $$;

create policy "contrat signe : lecture dans son salon" on contracts
  for select using (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id
        and (r.teacher_id = my_teacher_id()
             or r.institution_id = my_institution_id())
    )
  );

-- La signature passe par l'API, qui verifie l'ordre des etapes : une mise a
-- jour directe permettrait de signer a la place de l'autre.
create policy "contrat signe : l etablissement le redige" on contracts
  for all using (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id and r.institution_id = my_institution_id()
    )
  ) with check (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id and r.institution_id = my_institution_id()
    )
  );

create policy "embauche : ses deux parties" on recruitments
  for select using (
    teacher_id = my_teacher_id() or institution_id = my_institution_id()
  );

create policy "embauche : l etablissement la declare" on recruitments
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

-- Une note engage celui qui la donne et celui qui la recoit : les deux la
-- voient. Seul l'etablissement l'ecrit, et un palier ne se note qu'une fois
-- (contrainte d'unicite en 0006).
create policy "note : les deux parties" on teacher_reviews
  for select using (
    teacher_id = my_teacher_id() or institution_id = my_institution_id()
  );

create policy "note : l etablissement la donne" on teacher_reviews
  for insert with check (institution_id = my_institution_id());

create policy "invitation : l invite et l inviteur" on job_invitations
  for select using (
    teacher_id = my_teacher_id()
    or exists (
      select 1 from jobs j
      where j.id = job_id and j.institution_id = my_institution_id()
    )
  );

create policy "invitation : l etablissement invite" on job_invitations
  for all using (
    exists (
      select 1 from jobs j
      where j.id = job_id and j.institution_id = my_institution_id()
    )
  ) with check (
    exists (
      select 1 from jobs j
      where j.id = job_id and j.institution_id = my_institution_id()
    )
  );

-- --- Notifications, credits, cours produits -------------------------------
--
-- Strictement personnels. Le grand livre des credits est en lecture seule
-- pour son proprietaire : il ne s'ecrit que par la cle de service, sinon un
-- client pourrait se crediter lui-meme.

create policy "notification : la sienne" on notifications
  for select using (user_id = auth.uid());

create policy "notification : la marquer lue" on notifications
  for update using (user_id = auth.uid());

create policy "credits : lecture de son grand livre" on credit_ledger
  for select using (owner_id = auth.uid());

create policy "cours IA : les siens" on ai_courses
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());


-- ---------------------------------------------------------------------
-- 0008_drop_credits.sql
-- ---------------------------------------------------------------------

-- Fin du systeme de credits (25/09).
--
-- L'assistant IA, la mise en avant d'un etablissement et la messagerie sont
-- ouverts par l'abonnement (Basic, Pro, Master) : il n'y a plus rien a
-- decompter, donc plus rien a tenir en grand livre. Le client mobile a fait
-- le meme retrait dans sa migration locale v20.
--
-- Ce fichier s'ecrit en 0008 plutot qu'en corrigeant 0006 : une migration
-- deja appliquee ne se reecrit pas, et on ne sait pas depuis l'ici et
-- maintenant si 0006 a tourne sur l'instance. `if exists` rend le passage
-- sur une base ou rien n'a encore ete cree aussi sur que sur une base a
-- jour.

-- --- Le grand livre ------------------------------------------------------
--
-- La politique RLS part avec la table : supprimer une table emporte ses
-- politiques, mais l'ecrire ici rend l'intention lisible dans l'historique.
drop policy if exists "credits : lecture de son grand livre" on credit_ledger;
drop index if exists credit_ledger_owner_idx;
drop table if exists credit_ledger;

-- --- Le cout fige sur une promotion --------------------------------------
--
-- Il valait 50 credits a la mise en ligne. Une promotion ne se paie plus a
-- l'acte : la colonne ne porterait plus qu'un zero sur chaque ligne, et un
-- zero affiche se lit comme une information.
alter table promotions drop column if exists credit_cost;


-- ---------------------------------------------------------------------
-- 0009_public_teacher_read.sql
-- ---------------------------------------------------------------------

-- Lecture publique de la fiche enseignant (25/09).
--
-- Le client web parle desormais directement a PostgREST avec la cle
-- anonyme : il n'y a plus de serveur intermediaire pour decider qui voit
-- quoi. RLS est donc la seule barriere, et trois regles de 0002 ferment des
-- portes que le produit ouvre.
--
-- 1. `teachers` n'est lisible que par un compte INSTITUTION. Or la recherche
--    de professeurs est publique des l'ecran d'accueil, et une famille n'est
--    pas un etablissement : sur les deux clients, on cherche avant d'ouvrir
--    un compte.
-- 2. `profiles` n'est lisible que par soi-meme. La vue
--    `teacher_public_profiles` la joint en `security_invoker`, donc elle ne
--    rend rien — y compris a un etablissement, pour qui elle a ete ecrite.
-- 3. Les matieres, niveaux et certifications d'un enseignant suivent la meme
--    regle que `teachers` : sans eux, une fiche s'affiche sans ce qui la
--    rend utile.
--
-- Ce que cette migration n'ouvre PAS, et ne doit jamais ouvrir : le
-- telephone, le courriel, les diplomes et les documents. Ils restent fermes
-- par 0002, et la vue ci-dessous ne les expose pas. Les coordonnees ne
-- circulent qu'apres mise en relation (§30).

-- --- La fiche elle-meme ---------------------------------------------------

-- Un enseignant non suspendu est consultable par tout le monde, connecte ou
-- non. C'est ce que montre deja l'application mobile sans compte.
create policy "enseignant : fiche publique" on teachers
  for select using (
    exists (
      select 1 from profiles p
      where p.id = teachers.user_id and not p.suspended
    )
  );

-- --- L'identite professionnelle qui l'accompagne --------------------------
--
-- Le prenom, le nom et la photo d'un enseignant sont ce qu'il publie de
-- lui-meme : sans eux la recherche rend des fiches anonymes. Le telephone et
-- le courriel restent couverts par « profil : lecture de soi ».
--
-- Postgres n'a pas de politique par colonne : la restriction passe donc par
-- une vue, et l'acces direct a `profiles` n'est pas elargi.
create view public_teacher_identities as
  select
    p.id,
    p.first_name,
    p.last_name,
    p.photo_path,
    p.city
  from profiles p
  where p.role = 'TEACHER' and not p.suspended;

-- `security_definer` ici, a l'inverse de la vue de 0002 : c'est la vue qui
-- garantit les colonnes rendues, et elle ne rend que celles-ci. En
-- `invoker`, elle se heurterait a « lecture de soi » et rendrait zero ligne
-- — precisement le defaut qu'on corrige.
alter view public_teacher_identities set (security_invoker = false);

grant select on public_teacher_identities to anon, authenticated;

-- --- Ce qui qualifie la fiche ---------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'teacher_subjects', 'teacher_levels', 'teacher_certifications'
  ] loop
    execute format($f$
      create policy "%1$s : lecture publique" on %1$I
        for select using (true);
    $f$, t);
  end loop;
end $$;

-- Les experiences restent fermees au public : elles nomment des
-- etablissements et des dates, ce qui compose un parcours professionnel
-- identifiant. Un etablissement les voit deja (politique de 0002), et c'est
-- lui qui recrute.

-- --- Favoris (lacune signalee par check-schema.mjs) -----------------------
--
-- La table existe cote application depuis la v19 et n'avait aucun equivalent
-- serveur : une mise en favori partait dans la file d'envoi et etait rejetee
-- en silence.

create table if not exists favourites (
  id          text primary key default gen_random_uuid()::text,
  owner_id    uuid not null references profiles (id) on delete cascade,
  teacher_id  text not null references teachers (id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (owner_id, teacher_id)
);

create index if not exists favourites_teacher_idx on favourites (teacher_id);

alter table favourites enable row level security;

-- Chacun gere les siens. Le compte du professeur, lui, a besoin du nombre
-- de mises en favori sans connaitre qui : ce comptage passera par une
-- fonction dediee, pas par une lecture de la table.
create policy "favoris : les siens" on favourites
  for all using (owner_id = auth.uid())
  with check (owner_id = auth.uid());


-- ---------------------------------------------------------------------
-- 0010_course_content.sql
-- ---------------------------------------------------------------------

-- Contenu d'un cours video : chapitres, elements, commentaires (02/10).
--
-- Les trois tables existent cote application depuis la v23 du schema mobile.
-- Sans equivalent serveur, un cours construit sur un telephone partait dans
-- la file d'envoi et etait rejete en silence : le professeur voyait son
-- sommaire, l'eleve recevait un cours vide.
--
-- Le point delicat de cette migration n'est pas la forme des tables, c'est
-- **qui lit `local_path` et `remote_url`**. Ces deux colonnes designent le
-- fichier video. Un cours se vend ; les rendre publiques avec le reste du
-- sommaire donnerait le cours entier a qui sait interroger PostgREST avec la
-- cle anonyme, et la cle anonyme est dans le code du site. Le sommaire est la
-- vitrine, le fichier est la marchandise.

-- --- Les chapitres --------------------------------------------------------

create table if not exists course_chapters (
  id          text primary key,
  course_id   text not null references video_courses (id) on delete cascade,
  title       text not null,
  -- Ce que le chapitre traite, affiche sous la video.
  description text,
  -- Rang d'affichage, explicite et non deduit de la date de creation : un
  -- professeur reordonne ses chapitres, et l'ordre de saisie n'est pas
  -- l'ordre d'apprentissage.
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists course_chapters_course_idx
  on course_chapters (course_id, position);

-- --- Les elements d'un chapitre -------------------------------------------

create table if not exists course_items (
  id               text primary key,
  chapter_id       text not null
                     references course_chapters (id) on delete cascade,
  kind             text not null default 'VIDEO'
                     check (kind in ('VIDEO', 'DOCUMENT', 'LINK')),
  title            text not null,
  -- Le chemin sur l'appareil du professeur, le temps que le fichier monte.
  local_path       text,
  -- L'adresse du fichier une fois en ligne, ou l'URL elle-meme pour un lien.
  remote_url       text,
  -- Nulle quand on ne la connait pas : afficher « 0 min » serait faux.
  duration_seconds integer check (duration_seconds is null
                                  or duration_seconds >= 0),
  position         integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists course_items_chapter_idx
  on course_items (chapter_id, position);

-- --- Les commentaires sous une video --------------------------------------
--
-- Rattaches a l'element et non au cours : une question porte sur la video
-- qu'on vient de regarder, et la rattacher au cours entier la rendrait
-- introuvable des que le cours compte dix videos.

create table if not exists course_comments (
  id         text primary key,
  item_id    text not null references course_items (id) on delete cascade,
  author_id  uuid not null references profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  -- Le commentaire auquel celui-ci repond. Nul au premier niveau.
  parent_id  text references course_comments (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists course_comments_item_idx
  on course_comments (item_id, created_at);

-- --- Qui voit quoi --------------------------------------------------------

alter table course_chapters enable row level security;
alter table course_items    enable row level security;
alter table course_comments enable row level security;

-- Vrai quand le compte courant a paye ce cours.
create or replace function has_bought_course(course text)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
as $$
  select exists (
    select 1 from course_purchases p
    where p.course_id = course and p.parent_id = my_parent_id()
  );
$$;

-- Le cours auquel appartient un element, en remontant son chapitre.
create or replace function course_of_item(item text)
  returns text
  language sql
  stable
  security definer
  set search_path = public
as $$
  select ch.course_id
  from course_items ci
  join course_chapters ch on ch.id = ci.chapter_id
  where ci.id = item;
$$;

-- Le programme est la vitrine : on doit pouvoir lire les titres des
-- chapitres avant de payer, sinon on achete sans savoir quoi.
create policy "chapitre : le programme est public" on course_chapters
  for select using (
    exists (
      select 1 from video_courses v
      where v.id = course_id
        and (v.status = 'PUBLISHED' or v.teacher_id = my_teacher_id())
    )
  );

create policy "chapitre : son auteur le gere" on course_chapters
  for all using (
    exists (
      select 1 from video_courses v
      where v.id = course_id and v.teacher_id = my_teacher_id()
    )
  )
  with check (
    exists (
      select 1 from video_courses v
      where v.id = course_id and v.teacher_id = my_teacher_id()
    )
  );

-- La table des elements, elle, reste fermee : elle porte le chemin du
-- fichier. Seuls l'auteur et ceux qui ont paye y accedent.
create policy "element : l auteur et les acheteurs" on course_items
  for select using (
    exists (
      select 1 from course_chapters ch
      join video_courses v on v.id = ch.course_id
      where ch.id = chapter_id
        and (v.teacher_id = my_teacher_id() or has_bought_course(v.id))
    )
  );

create policy "element : son auteur le gere" on course_items
  for all using (
    exists (
      select 1 from course_chapters ch
      join video_courses v on v.id = ch.course_id
      where ch.id = chapter_id and v.teacher_id = my_teacher_id()
    )
  )
  with check (
    exists (
      select 1 from course_chapters ch
      join video_courses v on v.id = ch.course_id
      where ch.id = chapter_id and v.teacher_id = my_teacher_id()
    )
  );

-- Ce que la vitrine montre d'un element : son titre et sa duree, jamais son
-- fichier. Postgres n'a pas de politique par colonne — la restriction passe
-- donc par une vue, comme pour l'identite publique d'un enseignant (0009).
create or replace view course_item_titles as
  select
    ci.id,
    ci.chapter_id,
    ci.kind,
    ci.title,
    ci.duration_seconds,
    ci.position
  from course_items ci
  join course_chapters ch on ch.id = ci.chapter_id
  join video_courses v    on v.id = ch.course_id
  where v.status = 'PUBLISHED';

-- `security_definer` ici, comme pour `public_teacher_identities` : c'est la
-- vue qui garantit les colonnes rendues, et elle ne rend que celles-ci. En
-- `invoker`, elle se heurterait a la politique ci-dessus et rendrait zero
-- ligne a qui n'a pas achete — c'est-a-dire a tous les acheteurs
-- potentiels.
alter view course_item_titles set (security_invoker = false);

grant select on course_item_titles to anon, authenticated;

-- Les commentaires suivent la video : les lire suppose d'y avoir acces.
-- Ouvrir leur lecture a tout le monde laisserait deviner le contenu du cours
-- par les questions qu'il souleve, et surtout exposerait des eleves nommes.
create policy "commentaire : ceux qui suivent le cours" on course_comments
  for select using (
    exists (
      select 1 from video_courses v
      where v.id = course_of_item(item_id)
        and (v.teacher_id = my_teacher_id() or has_bought_course(v.id))
    )
  );

create policy "commentaire : on ecrit sous son nom" on course_comments
  for insert with check (
    author_id = auth.uid()
    and exists (
      select 1 from video_courses v
      where v.id = course_of_item(item_id)
        and (v.teacher_id = my_teacher_id() or has_bought_course(v.id))
    )
  );

-- On efface le sien. Le professeur efface aussi ce qui est ecrit sous son
-- cours : c'est lui qui en repond, et une insulte sous sa video lui est
-- imputee.
create policy "commentaire : le sien, ou chez soi" on course_comments
  for delete using (
    author_id = auth.uid()
    or exists (
      select 1 from video_courses v
      where v.id = course_of_item(item_id) and v.teacher_id = my_teacher_id()
    )
  );

-- Modifier un commentaire n'est pas prevu par le produit : une reponse deja
-- lue ne doit pas changer sous les yeux de qui l'a lue. Pas de politique
-- `update`, donc aucune mise a jour possible — l'absence est la regle, pas un
-- oubli.


-- ---------------------------------------------------------------------
-- 0011_student_role.sql
-- ---------------------------------------------------------------------

-- Le role ETUDIANT (02/10).
--
-- `intro.json` propose quatre profils depuis le 24/09 et
-- `student_onboarding.json` est copie dans les deux clients. La contrainte de
-- `profiles.role`, elle, n'en acceptait que trois : une inscription
-- « etudiant » partait, Supabase creait le compte d'authentification, puis
-- l'insertion du profil echouait sur
-- `profiles_role_check`. Le compte existait sans identite, et la personne ne
-- pouvait ni entrer ni recommencer — son numero etait deja pris.
--
-- Le defaut etait invisible tant que la base n'etait pas hebergee : le
-- backend simule du site ne verifie aucune contrainte.

alter table profiles drop constraint if exists profiles_role_check;
alter table profiles
  add constraint profiles_role_check
  check (role in ('TEACHER', 'INSTITUTION', 'PARENT', 'STUDENT', 'ADMIN'));

-- --- Ce qu'un etudiant majeur est, pour le reste du schema ---------------
--
-- Il partage l'espace de la famille : meme suivi, memes demandes de cours,
-- memes contrats. Sa fiche est donc une ligne de `parents`, et ce n'est pas un
-- bricolage — c'est le choix fait cote mobile (`UserRole.followsAStudent`),
-- et le dupliquer en une table jumelle aurait double chaque requete du
-- parcours famille.
--
-- Ce qui le distingue tient en une chose : c'est lui qui signe. La regle des
-- 18 ans se rattache au role, pas a la fiche.

-- Les politiques ecrites pour PARENT doivent donc le reconnaitre. Elles
-- passent toutes par `my_parent_id()`, qui lit `parents.user_id = auth.uid()`
-- sans regarder le role : rien a changer. Cette fonction est la raison pour
-- laquelle cette migration ne reecrit aucune politique.

-- --- Garde-fou ------------------------------------------------------------
--
-- `profiles_guard()` (0004) empeche un compte de changer son propre role.
-- Elle reste en place et couvre le nouveau role sans modification : elle
-- compare l'ancien et le nouveau sans enumerer les valeurs permises.

comment on constraint profiles_role_check on profiles is
  'Quatre profils choisissables dans intro.json, plus ADMIN pour le back-office.';


-- ---------------------------------------------------------------------
-- 0012_purchase_payment.sql
-- ---------------------------------------------------------------------

-- L'achat d'un cours devient un acte en deux temps (02/10).
--
-- --- Le defaut -------------------------------------------------------------
--
-- `course_purchases` ne portait aucun etat : une ligne existait, donc le cours
-- etait achete. Or il n'y a pas encore d'encaissement — aucun fournisseur de
-- paiement n'est branche. Inserer la ligne au clic aurait donc donne le cours
-- gratuitement a qui appuie sur « Acheter », et `has_bought_course` aurait
-- ouvert les fichiers video dans la seconde.
--
-- --- Ce que cette migration pose ------------------------------------------
--
-- Un etat, et de quoi rattacher la ligne a une transaction chez l'operateur.
-- L'entitlement suit l'etat `PAID`, jamais la simple existence de la ligne.
--
-- Trois etats, et pas quatre : `PENDING` (la demande est enregistree, l'argent
-- n'est pas arrive), `PAID` (il est arrive), `CANCELLED` (elle n'aboutira pas).
-- Un `FAILED` distinct de `CANCELLED` n'apporterait rien : des deux cotes le
-- cours n'est pas du.

alter table course_purchases
  add column if not exists status text not null default 'PENDING'
    check (status in ('PENDING', 'PAID', 'CANCELLED')),

  -- La reference de la transaction chez l'operateur (Orange Money, MTN MoMo).
  -- Nulle tant qu'aucun fournisseur n'est branche ; c'est elle qui permettra
  -- de rapprocher un paiement recu d'une demande enregistree, et de ne pas
  -- creer deux acces pour un seul reglement.
  add column if not exists provider_ref text,

  -- Quel operateur, quand il y en aura un. Non contraint a une liste : la
  -- contrainte devrait etre modifiee a chaque nouvel operateur guineen.
  add column if not exists provider text,

  add column if not exists paid_at timestamptz;

-- Une reference d'operateur ne vaut que si elle est unique : deux lignes
-- portant la meme transaction signifieraient un reglement compte deux fois.
create unique index if not exists course_purchases_provider_ref_idx
  on course_purchases (provider_ref)
  where provider_ref is not null;

create index if not exists course_purchases_pending_idx
  on course_purchases (status, created_at)
  where status = 'PENDING';

-- --- L'entitlement suit le paiement ---------------------------------------
--
-- Le seul changement qui compte dans cette migration. Sans lui, une demande en
-- attente ouvrirait les videos.

create or replace function has_bought_course(course text)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
as $$
  select exists (
    select 1 from course_purchases p
    where p.course_id = course
      and p.parent_id = my_parent_id()
      and p.status = 'PAID'
  );
$$;

-- --- Qui ecrit quoi -------------------------------------------------------
--
-- La politique d'insertion de 0007 laissait l'acheteur ecrire sa ligne,
-- montant compris. Elle est remplacee : **le client ne fixe plus le prix.**
-- Un montant envoye par le navigateur est un montant choisi par le navigateur,
-- et le prix d'un cours se lit dans `video_courses`, pas dans une requete.
--
-- L'insertion passe donc par le serveur (cle `service_role`), qui relit le
-- prix, calcule la commission et pose l'etat. Le client ne garde que la
-- lecture — savoir ou en est sa demande.

drop policy if exists "achat : c est l acheteur qui achete" on course_purchases;

-- Le passage a `PAID` releve du serveur lui aussi : il arrive apres la
-- confirmation de l'operateur, que le client ne peut pas prouver. Aucune
-- politique `update` n'est posee, donc aucune mise a jour n'est possible
-- depuis le navigateur ou le telephone — l'absence est la regle, pas un oubli.

comment on column course_purchases.status is
  'PENDING a la demande, PAID a la confirmation de l''operateur. '
  'L''acces aux videos suit PAID, via has_bought_course().';


-- ---------------------------------------------------------------------
-- 0013_djomy.sql
-- ---------------------------------------------------------------------

-- Encaissement par Djomy (02/10).
--
-- La migration 0012 a pose un etat sur l'achat sans savoir qui encaisserait.
-- Djomy est retenu : agregateur guineen couvrant Orange Money, MTN MoMo, Kulu
-- et les cartes. Cette migration aligne le schema sur ce que sa plateforme
-- envoie reellement.
--
-- --- Les etats ------------------------------------------------------------
--
-- Djomy rend CREATED, PENDING, SUCCESS, CANCELLED et FAILED, et ses webhooks
-- ajoutent `payment.timeout` et `payment.refunded`. Nos trois etats n'y
-- suffisaient pas : un echec technique etait indistinguable d'une annulation
-- par le client, ce qui rend le support aveugle — « j'ai paye et ca n'a pas
-- marche » ne se traite pas comme « j'ai renonce ».

alter table course_purchases drop constraint if exists course_purchases_status_check;
alter table course_purchases
  add constraint course_purchases_status_check
  check (status in ('PENDING', 'PAID', 'FAILED', 'CANCELLED', 'REFUNDED'));

-- --- Ce que l'operateur retient -------------------------------------------
--
-- L'exemple de webhook donne `paidAmount: 10000`, `receivedAmount: 9000`,
-- `fees: 1000`. Autrement dit **la commission de Djomy sort du montant
-- encaisse**, elle ne s'ajoute pas. Le professeur touche 80 % de quoi ? Si
-- c'est 80 % du prix affiche, la plateforme paie les frais de son propre
-- revenu ; si c'est 80 % du recu, le professeur les paie. La question n'est pas
-- tranchee, et le code ne la tranche pas a la place de qui doit le faire : on
-- enregistre les deux montants, et le calcul du reversement les lira.

alter table course_purchases
  add column if not exists provider_fees integer
    check (provider_fees is null or provider_fees >= 0),
  add column if not exists provider_received integer
    check (provider_received is null or provider_received >= 0),
  -- OM, MOMO, CARD… tel que l'operateur le nomme. Non contraint a une liste :
  -- Djomy en ajoute (SOUTRA_MONEY, PAYCARD, YMO sont annonces), et une
  -- contrainte a mettre a jour a chaque ajout ne protege de rien.
  add column if not exists provider_method text,
  -- Le numero qui a paye. Il n'est pas toujours celui du compte : on paie avec
  -- le portefeuille d'un parent, d'un oncle, d'un voisin. Le garder est la
  -- seule facon de rapprocher un reglement d'une reclamation.
  add column if not exists payer_identifier text;

-- --- Le journal des evenements, et pourquoi il est indispensable ----------
--
-- Djomy reessaie un webhook qui n'a pas repondu 200. Sans table de
-- deduplication, un seul reessai sur `payment.success` rejouerait le traitement
-- : deux incrementations de `purchase_count`, et le jour ou un reversement
-- automatique existera, deux paiements au professeur pour une vente.
--
-- La cle est `event_id`, fourni par Djomy et unique par evenement. L'insertion
-- se fait **avant** de toucher l'achat : si elle echoue sur la contrainte,
-- l'evenement est deja traite et il n'y a rien a faire.

create table if not exists payment_events (
  -- L'identifiant de Djomy, pas le notre : c'est lui qui porte l'unicite.
  event_id      text primary key,
  event_type    text not null,
  transaction_id text,
  -- La reference que nous avions envoyee : l'identifiant de l'achat. Elle
  -- permet de retrouver la ligne meme si `provider_ref` n'a pas pu etre
  -- enregistre a l'initiation.
  merchant_ref  text,
  status        text,
  paid_amount   integer,
  -- Le corps brut, tel que recu et signe. C'est la preuve : en cas de litige
  -- sur un montant, c'est ce texte qui tranche, pas nos colonnes derivees.
  payload       jsonb not null,
  received_at   timestamptz not null default now()
);

create index if not exists payment_events_transaction_idx
  on payment_events (transaction_id);
create index if not exists payment_events_merchant_ref_idx
  on payment_events (merchant_ref);

alter table payment_events enable row level security;

-- Aucune politique : la table n'est lisible et ecrivable que par la cle de
-- service. Un acheteur n'a rien a y faire, et un evenement de paiement nomme
-- des montants et des numeros de telephone. **L'absence de politique est la
-- regle**, pas un oubli : RLS activee sans politique ferme la table a tous les
-- roles clients.

comment on table payment_events is
  'Journal des webhooks de paiement. event_id porte la deduplication : un '
  'reessai de Djomy ne doit pas rejouer un encaissement.';


-- ---------------------------------------------------------------------
-- 0014_live_courses.sql
-- ---------------------------------------------------------------------

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


-- ---------------------------------------------------------------------
-- 0015_session_enrolments.sql
-- ---------------------------------------------------------------------

-- S'inscrire à une séance en direct (02/10).
--
-- --- Le problème des quinze places ---------------------------------------
--
-- Quinze places, et deux familles qui réservent la dernière au même instant.
-- Compter les inscriptions avant d'insérer ne suffit pas : les deux comptes
-- lisent 14, les deux insèrent, la séance en a 16. Le défaut est rare, invisible
-- en test, et il se manifeste le jour où un cours se remplit — c'est-à-dire le
-- jour où ça compte.
--
-- La parade est un compteur sur la séance et une mise à jour **conditionnelle**
-- (`where seats_taken < seats`). Postgres verrouille la ligne le temps de
-- l'écriture : la seconde tentative ne met à jour aucune ligne et le sait.
-- C'est la même règle que pour un solde — jamais lire-modifier-écrire.

alter table live_sessions
  add column if not exists seats_taken integer not null default 0
    check (seats_taken >= 0);

-- --- L'inscription --------------------------------------------------------

create table if not exists session_enrolments (
  id          text primary key default gen_random_uuid()::text,
  session_id  text not null references live_sessions (id) on delete cascade,

  -- Le compte qui paie : une famille, ou un étudiant majeur.
  parent_id   text not null references parents (id) on delete cascade,

  -- L'élève concerné. Nul quand c'est l'étudiant majeur lui-même : il partage
  -- l'espace de la famille sans être l'enfant de personne.
  child_id    text references children (id) on delete cascade,

  status      text not null default 'PENDING'
                check (status in ('PENDING', 'CONFIRMED', 'CANCELLED')),

  -- Une place retenue sans être payée ne doit pas l'être pour toujours. Le
  -- cron qui génère les séances libère ce qui a expiré.
  holds_until timestamptz,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Deux index partiels, et non une seule contrainte : dans Postgres, deux NULL
-- ne sont pas égaux, donc `unique (session_id, child_id)` laisserait un
-- étudiant majeur s'inscrire autant de fois qu'il le veut.
create unique index if not exists session_enrolments_child_idx
  on session_enrolments (session_id, child_id)
  where child_id is not null;

create unique index if not exists session_enrolments_self_idx
  on session_enrolments (session_id, parent_id)
  where child_id is null;

create index if not exists session_enrolments_session_idx
  on session_enrolments (session_id, status);
create index if not exists session_enrolments_parent_idx
  on session_enrolments (parent_id, created_at desc);

-- --- Prendre et rendre une place ------------------------------------------

/*
 * Prend une place, ou rend faux.
 *
 * La mise à jour conditionnelle est tout l'intérêt : `seats_taken < seats`
 * est évalué sous le verrou de ligne, donc deux appels simultanés ne peuvent
 * pas réussir tous les deux. Un `select` suivi d'un `update` le permettrait.
 */
create or replace function claim_session_seat(session text)
  returns boolean
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  touchees integer;
begin
  update live_sessions s
     set seats_taken = s.seats_taken + 1,
         updated_at = now()
   from live_courses c
  where s.id = session
    and c.id = s.live_course_id
    and s.status = 'PLANNED'
    and s.seats_taken < c.seats;

  get diagnostics touchees = row_count;
  return touchees > 0;
end;
$$;

/*
 * Rend une place.
 *
 * `greatest(…, 0)` plutôt qu'une soustraction nue : un double appel — reprise
 * manuelle, webhook rejoué — ne doit pas faire passer le compteur sous zéro et
 * offrir une place de plus que la salle n'en a.
 */
create or replace function release_session_seat(session text)
  returns void
  language sql
  security definer
  set search_path = public
as $$
  update live_sessions
     set seats_taken = greatest(seats_taken - 1, 0),
         updated_at = now()
   where id = session;
$$;

-- --- Un seul encaissement pour deux objets --------------------------------
--
-- `course_purchases` portait un `course_id` obligatoire vers `video_courses`.
-- Une séance en direct n'est pas un cours vidéo : l'insertion échouait.
--
-- Trois façons de faire, et une seule qui tient :
--
--   * une seconde table de paiements — il faudrait alors deux webhooks, deux
--     chemins d'idempotence, deux endroits où le prix pourrait être faux ;
--   * mettre la séance dans `video_courses` — mentir sur ce qu'est un cours ;
--   * **un achat qui pointe sur l'un ou l'autre**, ce qui est fait ici.
--
-- Le webhook Djomy retrouve la ligne par son identifiant, qui est la référence
-- marchande : il ne change pas. `has_bought_course()` filtre sur `course_id`,
-- et un NULL n'égale jamais rien : elle ne change pas non plus.
--
-- La référence ne va **que dans ce sens**. Si `session_enrolments` portait un
-- `purchase_id`, les deux tables se référenceraient mutuellement et aucune ne
-- pourrait être créée en premier.

alter table course_purchases
  alter column course_id drop not null;

alter table course_purchases
  add column if not exists enrolment_id text
    references session_enrolments (id) on delete cascade;

create unique index if not exists course_purchases_enrolment_idx
  on course_purchases (enrolment_id)
  where enrolment_id is not null;

-- Exactement un des deux, jamais zéro, jamais les deux. Sans cette contrainte,
-- un achat sans objet serait encaissé sans rien donner en échange.
alter table course_purchases
  drop constraint if exists course_purchases_target_check;
alter table course_purchases
  add constraint course_purchases_target_check
  check (
    (course_id is not null and enrolment_id is null)
    or (course_id is null and enrolment_id is not null)
  );

-- --- Qui voit quoi --------------------------------------------------------

alter table session_enrolments enable row level security;

-- Une famille voit ses inscriptions. Le professeur voit celles de ses séances
-- — il doit savoir qui vient, c'est sa classe.
create policy "inscription : la sienne, ou sa classe" on session_enrolments
  for select using (
    parent_id = my_parent_id()
    or exists (
      select 1
        from live_sessions s
        join live_courses c on c.id = s.live_course_id
       where s.id = session_id and c.teacher_id = my_teacher_id()
    )
  );

-- **Aucune politique d'écriture.** S'inscrire passe par le serveur, qui prend
-- la place et lance le paiement sous la clé de service. Un client qui pourrait
-- insérer contournerait le compteur de places et le prix.

comment on constraint course_purchases_target_check on course_purchases is
  'Un achat porte soit un cours video, soit une inscription a une seance. '
  'Jamais les deux, jamais aucun.';
comment on column session_enrolments.holds_until is
  'Une place retenue sans paiement expire. Le cron de generation libere.';
comment on function claim_session_seat(text) is
  'Prend une place de maniere atomique. Faux si la salle est pleine.';


-- ---------------------------------------------------------------------
-- 0016_video_providers.sql
-- ---------------------------------------------------------------------

-- LiveKit et Bunny Stream : ce que le schéma doit retenir (02/10).
--
-- Deux fournisseurs retenus, et une seule chose à en garder : leurs
-- identifiants. Ni les URL, ni les jetons.
--
-- --- Pourquoi aucune URL n'est stockée ------------------------------------
--
-- Une URL de lecture Bunny est **signée et expire**. La mettre en base
-- reviendrait à conserver un laissez-passer périmé : au mieux inutile, au pire
-- recopié tel quel dans une réponse et servi à quelqu'un qui n'a pas payé.
--
-- Ce qui est stocké est l'identifiant de la vidéo chez Bunny. L'URL est
-- recalculée à chaque lecture, **après** vérification de l'achat, et pour
-- quelques heures seulement.
--
-- Même raison pour le jeton LiveKit : nominatif, court, recalculé. Rien à
-- garder.

-- --- Les vidéos d'un cours -------------------------------------------------

alter table course_items
  -- L'identifiant de la vidéo chez Bunny Stream. `remote_url` existe encore et
  -- reste utilisable pour un lien externe — une annale sur un site public, par
  -- exemple — mais une vidéo de cours passe désormais par le fournisseur, qui
  -- la transcode en plusieurs débits. Un MP4 brut sur une ligne guinéenne ne se
  -- regarde pas.
  add column if not exists provider_video_id text,

  -- L'état du transcodage, tel que Bunny le rend. Une vidéo déposée n'est pas
  -- une vidéo lisible : il faut quelques minutes, et l'écran doit pouvoir dire
  -- « en préparation » au lieu d'ouvrir un lecteur noir.
  add column if not exists provider_status text;

create index if not exists course_items_provider_idx
  on course_items (provider_video_id)
  where provider_video_id is not null;

-- --- L'enregistrement d'une séance ----------------------------------------

alter table live_sessions
  -- L'egress LiveKit en cours. Conservé le temps de la séance pour pouvoir
  -- arrêter l'enregistrement : sans cet identifiant, un egress oublié continue
  -- de tourner et d'être facturé.
  add column if not exists egress_id text,

  -- La vidéo Bunny issue de l'enregistrement, une fois récupérée et transcodée.
  add column if not exists recording_video_id text,

  add column if not exists recording_status text
    check (
      recording_status is null
      or recording_status in ('RECORDING', 'TRANSFERRING', 'READY', 'FAILED')
    ),

  -- Quand la salle a réellement ouvert et fermé. `starts_at` est l'horaire
  -- prévu ; ces deux colonnes sont ce qui s'est passé. L'écart entre les deux
  -- est la seule façon de constater qu'un professeur commence en retard.
  add column if not exists opened_at timestamptz,
  add column if not exists closed_at timestamptz;

create index if not exists live_sessions_recording_idx
  on live_sessions (recording_status)
  where recording_status is not null;

comment on column course_items.provider_video_id is
  'Identifiant Bunny Stream. L''URL de lecture est signee a la demande, '
  'apres verification de l''achat, et expire.';
comment on column live_sessions.egress_id is
  'Egress LiveKit en cours. Sans lui, un enregistrement oublie continue '
  'd''etre facture.';


-- ---------------------------------------------------------------------
-- 0017_attendance.sql
-- ---------------------------------------------------------------------

-- Présence et temps de cours (02/10).
--
-- --- Pourquoi la présence ne vient pas du client --------------------------
--
-- On pourrait laisser le navigateur annoncer « je suis entré » puis « je sors ».
-- Deux raisons de ne pas le faire, et la seconde est la plus fréquente :
--
--   * un élève qui veut faire croire qu'il a suivi le cours n'a qu'à envoyer le
--     premier message et fermer l'onglet — et c'est précisément le compteur que
--     le parent paie pour lire ;
--   * un navigateur qui plante, un téléphone qui perd le réseau au milieu d'un
--     cours, n'envoie jamais le second. La ligne resterait ouverte indéfiniment
--     et le temps cumulé serait faux dans l'autre sens.
--
-- La présence vient donc des **webhooks LiveKit** : `participant_joined`,
-- `participant_left`, `room_finished`. C'est le serveur de visioconférence qui
-- constate, et lui seul constate aussi une déconnexion brutale.
--
-- --- À quoi une présence se rattache -------------------------------------
--
-- Un enfant n'a **pas de compte** : `children` est une fiche que le parent
-- possède (0001). Celui qui entre dans la salle est le titulaire du compte —
-- le parent, ou l'étudiant majeur. La présence porte donc deux liens :
--
--   `user_id`      — qui s'est connecté. C'est l'identité LiveKit.
--   `enrolment_id` — la place payée, qui porte elle-même le parent ET l'enfant.
--
-- C'est `enrolment_id` qui permet d'écrire « Fatoumata a suivi 90 minutes »
-- plutôt que « le compte 0xa3f… a suivi 90 minutes ». Il est nul pour le
-- professeur, qui est dans la salle sans y être inscrit.

create table if not exists session_attendance (
  id            text primary key default gen_random_uuid()::text,
  session_id    text not null references live_sessions (id) on delete cascade,

  -- Le compte connecté. `profiles.id`, et non `auth.uid()` directement : la
  -- présence doit survivre à une relecture par le professeur.
  user_id       uuid not null references profiles (id) on delete cascade,

  -- La place payée. Nul pour le professeur de la séance.
  enrolment_id  text references session_enrolments (id) on delete cascade,

  joined_at     timestamptz not null default now(),
  left_at       timestamptz,

  -- Minutes présentes, calculées à la sortie. Dérivée, et conservée quand
  -- même : c'est la colonne que le compteur hebdomadaire additionne, et refaire
  -- la soustraction à chaque lecture obligerait à balayer tout l'historique.
  minutes       integer check (minutes is null or minutes >= 0),

  created_at    timestamptz not null default now()
);

/*
 * Une seule ligne ouverte par identité et par séance.
 *
 * LiveKit envoie un `participant_joined` à chaque reconnexion — et sur une
 * ligne guinéenne il y en a. Le webhook ferme donc la ligne précédente avant
 * d'ouvrir la suivante, et cet index garantit qu'un oubli devient une erreur
 * visible plutôt que deux lignes ouvertes qui doublent le temps compté.
 *
 * L'identité étant la place (`enrolment_id`) et non le compte, deux enfants
 * d'une même famille inscrits à la même séance comptent séparément — c'est le
 * cas de deux frères sur deux tablettes, et il est réel.
 */
-- Les parenthèses autour du `coalesce` sont là pour la lecture, pas par
-- nécessité : la grammaire de Postgres range `COALESCE` parmi les expressions de
-- forme fonctionnelle, qu'un élément d'index accepte nues. (Vérifié en retirant
-- les parenthèses et en rejouant `npm run check:db` — la migration passe. Le
-- commentaire précédent affirmait le contraire ; c'était faux.)
create unique index if not exists session_attendance_open_idx
  on session_attendance (session_id, (coalesce(enrolment_id, user_id::text)))
  where left_at is null;

create index if not exists session_attendance_session_idx
  on session_attendance (session_id, joined_at);
create index if not exists session_attendance_enrolment_idx
  on session_attendance (enrolment_id, joined_at desc)
  where enrolment_id is not null;

-- Qui est en ligne en ce moment : c'est la requête du bandeau parent, et elle
-- se fait à chaque rafraîchissement.
create index if not exists session_attendance_live_idx
  on session_attendance (session_id)
  where left_at is null;

alter table session_attendance enable row level security;

/*
 * Qui voit la présence.
 *
 * Trois lecteurs, et chacun pour une raison différente :
 *
 *   * **le titulaire du compte** — il voit son propre temps de cours ;
 *   * **le parent de la place** — c'est la fonction qui justifie son
 *     abonnement. Il voit celle de ses inscriptions, et seulement d'elles ;
 *   * **le professeur de la séance** — il doit savoir qui est là, c'est sa
 *     classe.
 */
create policy "presence : soi, sa place, sa classe" on session_attendance
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from session_enrolments e
       where e.id = session_attendance.enrolment_id
         and e.parent_id = my_parent_id()
    )
    or exists (
      select 1
        from live_sessions s
        join live_courses lc on lc.id = s.live_course_id
       where s.id = session_attendance.session_id
         and lc.teacher_id = my_teacher_id()
    )
  );

-- **Aucune politique d'écriture.** La présence est constatée par LiveKit et
-- écrite sous la clé de service. Un client capable d'écrire ici fabriquerait le
-- temps de cours que le parent lit, ce qui viderait la fonction de son sens.

/*
 * --- La lecture, en une requête -----------------------------------------
 *
 * Le bandeau « Fatoumata suit Mathématiques — en direct depuis 23 min » et le
 * compteur « temps de cours cette semaine » ont besoin des mêmes jointures :
 * présence → place → enfant, et présence → séance → cours → matière. Les
 * refaire côté client demanderait cinq requêtes et autant d'occasions de se
 * tromper.
 *
 * `security_invoker` : la vue s'exécute avec les droits de l'appelant, donc la
 * politique ci-dessus s'applique à travers elle. Une vue en `security_definer`
 * — le défaut historique de Postgres — aurait rendu toute la présence de la
 * plateforme lisible par n'importe quel compte, et c'est exactement le genre de
 * fuite qu'on ne voit pas en testant avec son propre compte.
 *
 * Conséquence voulue : `child_name` est **nul pour le professeur**. La jointure
 * sur `children` passe par la politique « enfants : gérés par le parent », qui
 * ne lui ouvre rien. Il lit donc son effectif sans lire les fiches des familles
 * — ce n'est pas un défaut à corriger en élargissant cette politique, c'est la
 * limite qui fait que la fiche d'un enfant reste chez ses parents.
 */
create or replace view attendance_detail
  with (security_invoker = true) as
select a.id,
       a.session_id,
       a.enrolment_id,
       a.user_id,
       a.joined_at,
       a.left_at,
       a.minutes,
       -- Minutes en cours pour une ligne encore ouverte : le « depuis 23 min »
       -- se calcule ici, au moment de la lecture, et non à l'horloge du
       -- navigateur — celle d'un téléphone n'est pas toujours juste.
       case
         when a.left_at is null
           then greatest(0, floor(extract(epoch from (now() - a.joined_at)) / 60))::integer
         else a.minutes
       end as minutes_so_far,
       e.child_id,
       ch.first_name as child_name,
       s.starts_at,
       s.duration_minutes,
       s.status as session_status,
       lc.id    as live_course_id,
       lc.title as course_title,
       lc.teacher_id,
       sub.id   as subject_id,
       sub.name as subject_name
  from session_attendance a
  join live_sessions s  on s.id  = a.session_id
  join live_courses  lc on lc.id = s.live_course_id
  left join session_enrolments e  on e.id  = a.enrolment_id
  left join children          ch on ch.id = e.child_id
  left join subjects          sub on sub.id = lc.subject_id;

comment on table session_attendance is
  'Presence constatee par les webhooks LiveKit, jamais declaree par le '
  'client : un onglet ferme n''envoie pas de depart.';
comment on view attendance_detail is
  'Presence lisible : enfant, matiere, minutes en cours. security_invoker, '
  'donc la politique de session_attendance s''applique.';


-- ---------------------------------------------------------------------
-- 0018_checkpoints.sql
-- ---------------------------------------------------------------------

-- Les points de contrôle d'une séance et le résumé par l'IA (03/10).
--
-- --- Ce que cette table rend possible -------------------------------------
--
-- Une séance dure 90 minutes et se découpe en quatre modules de 15 minutes,
-- séparés par des pauses de 5 minutes, avec 30 minutes de questions à la fin.
-- À la fin de chaque module, le professeur ouvre un point de contrôle : *est-ce
-- passé ?* — oui, non, pas assez.
--
-- C'est le mécanisme qui distingue ce format d'une vidéo enregistrée. Dans un
-- amphithéâtre de quinze adolescents, personne ne dit « je n'ai pas compris ».
-- Trois boutons, dix secondes, et le professeur sait pendant la pause ce qu'il
-- doit reprendre — pas une semaine plus tard, sur une note.
--
-- --- Pourquoi l'inscription et non l'enfant ------------------------------
--
-- Comme pour `session_attendance` (0017) : `children` est une fiche que le
-- parent possède, pas un compte. Celui qui répond est le titulaire de la place.
-- La réponse se rattache donc à `session_enrolments`, qui porte à la fois le
-- parent et l'enfant — ce qui permet d'écrire « Fatoumata n'a pas suivi le
-- module 3 » plutôt que de désigner un compte.
--
-- Le plan (strategy_implementation.md §B5) prévoyait `child_id`. L'écart est le
-- même qu'en 0017 et pour la même raison.

create table if not exists session_checkpoints (
  id            text primary key default gen_random_uuid()::text,
  session_id    text not null references live_sessions (id) on delete cascade,

  -- 0 à 3 : les quatre modules de la séance. Borné plutôt que libre — un
  -- cinquième module n'existe pas dans le format, et une valeur de 47 serait
  -- une faute de frappe qu'on découvrirait sur un tableau de bord.
  module_index  integer not null check (module_index between 0 and 3),

  opened_at     timestamptz not null default now(),

  -- Nul tant que le point de contrôle accepte des réponses. C'est cette colonne
  -- qui ferme le vote, et non une minuterie côté client : un navigateur dont
  -- l'horloge est fausse, ou qu'on rouvre après coup, ne doit pas pouvoir
  -- répondre à un module terminé.
  closed_at     timestamptz,

  -- Le résumé rédigé par le serveur après la fermeture.
  --
  -- **C'est une aide, pas une note.** Il ne change aucun score, n'entre dans
  -- aucun calcul de confiance et ne s'affiche à aucun élève. Le jour où
  -- quelqu'un voudra s'en servir pour évaluer un professeur, cette ligne est là
  -- pour rappeler que ce n'était pas l'objet.
  summary       text,

  created_at    timestamptz not null default now(),

  -- Un seul point de contrôle par module et par séance. C'est ce qui rend
  -- l'ouverture rejouable : un professeur qui clique deux fois, ou dont le
  -- navigateur a planté, retrouve le même point de contrôle au lieu d'en ouvrir
  -- un second qui scinderait les réponses en deux.
  unique (session_id, module_index)
);

create index if not exists session_checkpoints_session_idx
  on session_checkpoints (session_id, module_index);

-- Celui qui est ouvert, s'il y en a un : c'est la requête que chaque élève fait
-- en boucle pendant la séance.
create index if not exists session_checkpoints_open_idx
  on session_checkpoints (session_id)
  where closed_at is null;

create table if not exists checkpoint_answers (
  checkpoint_id text not null
                  references session_checkpoints (id) on delete cascade,
  enrolment_id  text not null
                  references session_enrolments (id) on delete cascade,

  answer        text not null check (answer in ('YES', 'NO', 'PARTLY')),

  created_at    timestamptz not null default now(),

  -- Une réponse par place et par point de contrôle. La clé primaire plutôt
  -- qu'un index : il n'y a rien à dire d'une réponse en dehors de ce couple, et
  -- une colonne `id` inviterait à en stocker deux.
  primary key (checkpoint_id, enrolment_id)
);

create index if not exists checkpoint_answers_checkpoint_idx
  on checkpoint_answers (checkpoint_id, answer);

alter table session_checkpoints enable row level security;
alter table checkpoint_answers  enable row level security;

/*
 * --- Qui voit quoi, et pourquoi c'est asymétrique ------------------------
 *
 * **Les réponses sont anonymes pour la classe et nominatives pour le seul
 * professeur.** Ce n'est pas une préférence d'affichage, c'est la condition
 * pour que la réponse soit vraie : un élève qui sait que sa réponse s'affiche
 * devant quatorze camarades répond « oui ».
 *
 * D'où trois lecteurs et trois portées différentes :
 *
 *   * l'élève lit **sa** réponse — pour savoir qu'elle est partie ;
 *   * le parent lit celles de **ses** places — c'est le suivi qu'il paie ;
 *   * le professeur de la séance lit **tout** — c'est sa classe, et sans cela le
 *     point de contrôle ne sert à rien.
 *
 * Aucun élève ne lit la réponse d'un autre, et aucun ne lit l'agrégat : le
 * décompte « 9 oui, 4 pas assez » est calculé par le serveur pour le professeur.
 */
create policy "point de controle : visible avec sa seance" on session_checkpoints
  for select using (
    exists (
      select 1
        from live_sessions s
        join live_courses lc on lc.id = s.live_course_id
       where s.id = session_checkpoints.session_id
         and (
           lc.teacher_id = my_teacher_id()
           or exists (
             select 1 from session_enrolments e
              where e.session_id = s.id
                and e.parent_id = my_parent_id()
                and e.status = 'CONFIRMED'
           )
         )
    )
  );

-- Le professeur ouvre et ferme ; il ne les crée pas en base directement — c'est
-- le serveur qui pose la ligne — mais la politique de mise à jour lui permet
-- d'annoter sans passer par la clé de service.
create policy "point de controle : son professeur le gere" on session_checkpoints
  for update using (
    exists (
      select 1
        from live_sessions s
        join live_courses lc on lc.id = s.live_course_id
       where s.id = session_checkpoints.session_id
         and lc.teacher_id = my_teacher_id()
    )
  );

create policy "reponse : la sienne, la sienne d'enfant, sa classe"
  on checkpoint_answers
  for select using (
    exists (
      select 1 from session_enrolments e
       where e.id = checkpoint_answers.enrolment_id
         and e.parent_id = my_parent_id()
    )
    or exists (
      select 1
        from session_checkpoints c
        join live_sessions s on s.id = c.session_id
        join live_courses lc on lc.id = s.live_course_id
       where c.id = checkpoint_answers.checkpoint_id
         and lc.teacher_id = my_teacher_id()
    )
  );

/*
 * L'écriture d'une réponse.
 *
 * Permise au titulaire de la place, et à trois conditions qui tiennent toutes
 * dans la clause : la place est **la sienne**, elle est **payée**, et le point
 * de contrôle est **encore ouvert**. La dernière est celle qui compte : sans
 * elle, on répondrait à un module terminé depuis une heure, et le résumé déjà
 * envoyé au professeur deviendrait faux.
 */
create policy "reponse : sa place, payee, et le vote ouvert"
  on checkpoint_answers
  for insert with check (
    exists (
      select 1 from session_enrolments e
       where e.id = checkpoint_answers.enrolment_id
         and e.parent_id = my_parent_id()
         and e.status = 'CONFIRMED'
    )
    and exists (
      select 1 from session_checkpoints c
       where c.id = checkpoint_answers.checkpoint_id
         and c.closed_at is null
    )
  );

-- **Aucune politique de mise à jour ni de suppression sur les réponses.** Une
-- réponse se donne une fois. Pouvoir la changer après la fermeture reviendrait
-- à réécrire ce que le professeur a déjà lu, et pouvoir la supprimer
-- permettrait de recommencer le vote.

comment on table session_checkpoints is
  'Un point de controle par module (0-3). `summary` est une aide pour le '
  'professeur, jamais une note.';
comment on table checkpoint_answers is
  'Anonyme pour la classe, nominatif pour le seul professeur : un eleve qui '
  'sait que sa reponse s''affiche repond « oui ».';


-- ---------------------------------------------------------------------
-- 0019_curriculum.sql
-- ---------------------------------------------------------------------

-- Le programme scolaire guinéen en base (03/10).
--
-- --- Ce que ces tables apportent -----------------------------------------
--
-- Jusqu'ici, un cours portait une matière et une classe : « Mathématiques,
-- 10ème ». Utile pour filtrer, insuffisant pour décider. Un parent cherche
-- rarement « des maths » — il cherche **le chapitre que son enfant n'a pas
-- compris** : les fonctions affines, le théorème de Thalès, la nutrition des
-- plantes vertes.
--
-- `curriculum_chapters` met le programme à plat : 348 chapitres et
-- 1 228 sous-chapitres pour 14 matières et 7 classes, de la 7ème à la Terminale.
-- Un cours vidéo ou un cours en direct peut alors **se rattacher à un chapitre
-- du programme**, et c'est ce lien qui rend possible :
--
--   * « qui enseigne Thalès en 9ème ? » — la recherche que les familles font
--     réellement ;
--   * « il me manque le chapitre 4 » — un élève qui sait ce qu'il cherche ;
--   * « ce cours couvre 3 des 16 chapitres de 7ème » — un professeur qui voit
--     son programme avancer.
--
-- --- ⚠ Ce que ces données ne sont pas ------------------------------------
--
-- **Pas le programme officiel du ministère.** Les sources consultées ne
-- contiennent aucune publication ministérielle unique couvrant toutes les
-- matières et toutes les classes ; `shared/curriculum/guinea.json` porte un
-- avertissement que les deux clients affichent, et `content_status` le redit
-- ligne par ligne.
--
-- Cette honnêteté n'est pas une formalité : un professeur qui prépare un cours
-- sur un référentiel faux perd sa séance, et une famille qui l'a payée ne
-- revient pas. La colonne `content_status` et la table `curriculum_sources`
-- existent pour qu'on puisse toujours répondre à « d'où vient ce chapitre ? ».

-- --- Le programme ---------------------------------------------------------

create table if not exists curriculum_chapters (
  id            text primary key default gen_random_uuid()::text,

  -- Le référentiel existant, et non des noms libres : `sub_math`, `lvl_10`.
  -- Une matière inventée ici échouerait sur ces clés étrangères, ce qui est
  -- exactement l'intérêt — `shared/onboarding/sync.mjs` vérifie d'ailleurs la
  -- même chose avant le semis, pour que l'erreur se voie plus tôt.
  subject_id    text not null references subjects (id) on delete cascade,
  level_id      text not null references levels (id) on delete cascade,

  -- Rang du chapitre dans la progression de l'année. C'est l'ordre dans lequel
  -- un professeur l'enseigne, donc celui dans lequel un élève le cherche.
  position      integer not null check (position > 0),

  title         text not null check (length(title) between 2 and 200),
  summary       text,

  /*
   * Les sous-chapitres, en tableau plutôt qu'en table fille.
   *
   * 1 228 lignes pour une donnée qu'on lit **toujours** avec son chapitre et
   * jamais seule : aucune requête n'a de raison de chercher un sous-chapitre
   * sans savoir de quel chapitre il relève. Une table fille aurait ajouté une
   * jointure à chaque lecture du programme pour rien.
   *
   * Si un jour un sous-chapitre doit porter sa propre durée ou son propre
   * support, il devient une entité et mérite sa table. Pas avant.
   */
  subchapters   text[] not null default '{}',

  -- Ce que l'élève doit savoir faire. Présent pour 58 chapitres — la chimie du
  -- collège, seule source du corpus à le donner. Nul ailleurs, et c'est une
  -- information en soi.
  outcome       text,

  -- `complet` | `partiel`. Toutes les entrées valent `partiel` aujourd'hui : les
  -- sources le disent elles-mêmes. La colonne existe pour que ça change par
  -- matière, au fur et à mesure des vérifications, sans migration.
  content_status text not null default 'partiel'
                   check (content_status in ('complet', 'partiel')),

  -- Le fichier d'où vient ce chapitre (`chimie.txt`,
  -- `programme_guineen_college_lycee.json`…). Conservé parce que la question
  -- « d'où vient cette ligne ? » se pose dès qu'un professeur la contredit.
  source_ref    text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Un seul chapitre par rang, matière et classe. C'est ce qui rend le semis
  -- rejouable : il tourne à chaque déploiement sans créer de doublons.
  unique (subject_id, level_id, position)
);

create index if not exists curriculum_chapters_lookup_idx
  on curriculum_chapters (subject_id, level_id, position);

/*
 * La recherche plein texte sur les titres et les sous-chapitres.
 *
 * C'est la requête du produit : « qui enseigne Thalès ? ». Un parent tape le
 * chapitre, pas la matière.
 *
 * --- Pourquoi une colonne et un déclencheur, et non un index d'expression ---
 *
 * La forme évidente ne compile pas : un index GIN pose directement sur
 * `to_tsvector('french', title || ' ' || array_to_string(subchapters, ' '))`
 * échoue sur « functions in index expression must be marked IMMUTABLE ».
 *
 * (L'exemple est écrit en prose et non en SQL à dessein : `check-schema-file.mjs`
 * compte les instructions en cherchant leurs mots-clés dans le texte brut, et un
 * exemple commenté gonflait ce compte d'une unité — sa garde d'auto-aveuglement
 * signalait alors un nettoyage défectueux qui n'avait pas eu lieu.)
 *
 * `to_tsvector(regconfig, text)` est bien immuable — c'est pour cela qu'on passe
 * `'french'` explicitement plutôt que de laisser la configuration par défaut,
 * qui dépend d'un réglage de session. Le coupable est `array_to_string`, qui est
 * **STABLE** : sa signature générique passe par la fonction de sortie du type
 * d'élément, et pour certains types celle-ci dépend de réglages comme
 * `DateStyle`. Pour du `text[]` le résultat serait constant, mais Postgres juge
 * sur la signature, pas sur le cas d'usage.
 *
 * On pourrait emballer l'expression dans une fonction déclarée IMMUTABLE. Ce
 * serait mentir au planificateur, et un index construit sur un mensonge rend des
 * résultats faux sans jamais lever d'erreur — le pire des deux mondes.
 *
 * D'où la colonne maintenue par un déclencheur : c'est le motif documenté de
 * Postgres pour ce cas, et il reste juste quel que soit l'écrivain.
 *
 * `french` et non `simple` : la configuration française ramène « fonctions » et
 * « fonction » au même radical, ce qu'un parent qui tape de mémoire attend.
 */
alter table curriculum_chapters
  add column if not exists search tsvector;

create or replace function curriculum_chapters_search() returns trigger
  language plpgsql
  set search_path = public, pg_catalog
as $$
begin
  new.search := to_tsvector(
    'french',
    coalesce(new.title, '')
      || ' '
      || coalesce(array_to_string(new.subchapters, ' '), '')
      || ' '
      || coalesce(new.summary, '')
  );
  return new;
end;
$$;

drop trigger if exists curriculum_chapters_search_tg on curriculum_chapters;
create trigger curriculum_chapters_search_tg
  before insert or update of title, subchapters, summary
  on curriculum_chapters
  for each row execute function curriculum_chapters_search();

create index if not exists curriculum_chapters_search_idx
  on curriculum_chapters using gin (search);

-- --- Les manuels ----------------------------------------------------------

create table if not exists curriculum_textbooks (
  id            text primary key default gen_random_uuid()::text,

  -- Nul quand le libellé de la source ne correspond à aucune matière du
  -- référentiel (« Sciences physiques et biologie » en couvre deux). On garde
  -- alors `subject_label`, parce qu'un manuel sans matière reste utile à lire.
  subject_id    text references subjects (id) on delete set null,
  subject_label text not null,

  title         text not null,

  -- « 7e à 10e année », tel qu'écrit par la source. Texte et non `level_ids` :
  -- les sources donnent des plages approximatives (« Surtout 9e année »), et les
  -- convertir en identifiants inventerait une précision qu'elles n'ont pas.
  levels_label  text,

  -- « Manuel de référence couramment utilisé », « Manuel complémentaire ».
  -- Conservé parce que c'est cette nuance qui évite d'acheter le mauvais livre.
  status_note   text,

  created_at    timestamptz not null default now(),

  unique (subject_label, title)
);

-- --- La provenance --------------------------------------------------------

create table if not exists curriculum_sources (
  id          text primary key,
  kind        text not null default 'web',
  title       text not null,
  url         text,
  -- À quoi cette source a servi : « français collège », « histoire collège ».
  used_for    text,
  created_at  timestamptz not null default now()
);

-- --- Rattacher un cours à un chapitre du programme -----------------------
--
-- C'est le lien qui fait servir tout ce qui précède. Nul par défaut : un cours
-- n'a pas à se rattacher au programme — du soutien en méthodologie, un cours de
-- préparation au BEPC tous chapitres confondus. Rendre la colonne obligatoire
-- aurait forcé un rattachement faux.

alter table video_courses
  add column if not exists curriculum_chapter_id text
    references curriculum_chapters (id) on delete set null;

alter table live_courses
  add column if not exists curriculum_chapter_id text
    references curriculum_chapters (id) on delete set null;

create index if not exists video_courses_chapter_idx
  on video_courses (curriculum_chapter_id)
  where curriculum_chapter_id is not null;

create index if not exists live_courses_chapter_idx
  on live_courses (curriculum_chapter_id)
  where curriculum_chapter_id is not null;

-- --- Qui voit quoi --------------------------------------------------------

alter table curriculum_chapters  enable row level security;
alter table curriculum_textbooks enable row level security;
alter table curriculum_sources   enable row level security;

/*
 * Le programme est **public**, comme `subjects` et `levels` (0002).
 *
 * C'est un référentiel, pas une donnée de quelqu'un : un parent doit pouvoir
 * chercher « Thalès 9ème » avant d'ouvrir un compte, exactement comme il
 * consulte la grille des cours en direct. Le fermer obligerait à s'inscrire pour
 * savoir s'il y a une raison de s'inscrire.
 *
 * **Aucune politique d'écriture.** Le programme est posé par le semis, sous la
 * clé de service. Laisser un client l'écrire permettrait d'inventer un chapitre
 * officiel — et un faux chapitre dans un référentiel public est une erreur que
 * personne ne saurait attribuer.
 */
create policy "programme : lisible par tous" on curriculum_chapters
  for select using (true);
create policy "manuels : lisibles par tous" on curriculum_textbooks
  for select using (true);
create policy "sources du programme : lisibles par tous" on curriculum_sources
  for select using (true);

comment on table curriculum_chapters is
  'Programme guineen compile (PAS une publication officielle) : voir '
  'content_status et curriculum_sources. Genere depuis '
  'shared/curriculum/guinea.json.';
comment on column curriculum_chapters.subchapters is
  'Tableau et non table fille : toujours lu avec son chapitre, jamais seul.';
comment on table curriculum_textbooks is
  'Manuels de reference. `status_note` distingue reference et complement : la '
  'confusion fait acheter le mauvais livre.';


-- ---------------------------------------------------------------------
-- 0020_points.sql
-- ---------------------------------------------------------------------

-- Le grand livre de points et les concours (03/10) — phase D1 et D4.
--
-- --- Ce n'est pas le retour des crédits -----------------------------------
--
-- `credit_ledger` a été supprimé le 02/10 parce qu'il faisait payer l'usage de
-- l'IA à l'unité : on achetait des crédits, on les consommait, et une famille
-- sans crédit se retrouvait devant un mur au moment d'une question d'exercice.
--
-- Les points sont l'inverse : **une monnaie de fidélité qui se gagne et ne
-- s'achète jamais.** Aucune colonne de prix, aucun moyen de paiement, aucun lien
-- vers `course_purchases`. Si quelqu'un ajoute un jour « acheter des points »,
-- c'est l'ancien système qui revient sous un nouveau nom, et ce commentaire est
-- là pour qu'on s'en aperçoive.
--
-- --- Pourquoi un journal et non une colonne « solde » ---------------------
--
-- Un solde stocké se désynchronise au premier incident : une écriture perdue,
-- deux processus concurrents, et plus personne ne sait d'où vient le chiffre.
-- Ici le solde **est** la somme du journal, et chaque ligne dit pourquoi elle
-- existe. On peut toujours répondre « pourquoi ai-je 340 points ? », qui est la
-- seule question que l'élève posera.
--
-- Le journal est en ajout seul, et un déclencheur le fait respecter — pas
-- seulement une politique, parce que la clé de service contourne les politiques
-- mais pas les déclencheurs. Une erreur se corrige par une écriture inverse,
-- comme dans n'importe quelle comptabilité.

create table if not exists point_ledger (
  id          text primary key default gen_random_uuid()::text,
  owner_id    uuid not null references auth.users (id) on delete cascade,

  -- Positif pour un gain, négatif pour une dépense. Jamais nul : une ligne à
  -- zéro n'apprend rien et fait douter de celles qui l'entourent.
  delta       integer not null check (delta <> 0),

  -- Pourquoi ce point a été gagné, en clair, destiné à l'élève.
  --
  -- « Un solde qui monte sans raison lisible ne motive pas » : c'est la phrase
  -- du plan, et c'est pour cela que la colonne est obligatoire et bornée. Une
  -- raison vide rendrait l'historique illisible, et une raison de trois mille
  -- caractères casserait l'affichage.
  reason      text not null check (char_length(btrim(reason)) between 3 and 120),

  -- De quoi relier la ligne à ce qui l'a provoquée : une participation à un
  -- concours, une séance, un code. Libre à dessein — les sources de gains
  -- s'ajouteront, et une clé étrangère par source demanderait une migration
  -- chaque fois.
  reference   text,

  created_at  timestamptz not null default now()
);

-- L'historique d'une personne, du plus récent au plus ancien : c'est la seule
-- lecture que fait l'écran.
create index if not exists point_ledger_owner_idx
  on point_ledger (owner_id, created_at desc);

/*
 * En ajout seul, et pour de vrai.
 *
 * Une politique suffirait pour un client, mais le serveur travaille avec la clé
 * de service, qui les contourne toutes. Un déclencheur, lui, s'applique à tout
 * le monde : c'est la seule forme qui tienne contre un `update` lancé depuis
 * l'éditeur SQL un soir de correction de bug.
 */
create or replace function point_ledger_append_only() returns trigger as $$
begin
  raise exception
    'point_ledger est en ajout seul : corriger par une ecriture inverse '
    '(delta negatif) au lieu de modifier ou supprimer la ligne %.',
    old.id;
end;
$$ language plpgsql;

drop trigger if exists point_ledger_no_rewrite on point_ledger;
create trigger point_ledger_no_rewrite
  before update or delete on point_ledger
  for each row execute function point_ledger_append_only();

-- Le solde, calculé et jamais stocké.
--
-- `security_invoker` : la vue applique les politiques de celui qui l'interroge,
-- donc chacun n'y lit que son propre solde. Sans cette option, la vue
-- s'exécuterait avec les droits de son propriétaire et exposerait le solde de
-- tout le monde.
create or replace view point_balances with (security_invoker = true) as
  select owner_id, coalesce(sum(delta), 0)::integer as balance,
         count(*)::integer as entries, max(created_at) as last_entry_at
    from point_ledger
   group by owner_id;

alter table point_ledger enable row level security;

create policy "points : chacun lit le sien" on point_ledger
  for select using (owner_id = auth.uid());

-- **Aucune politique d'écriture.** Les points se gagnent par une décision du
-- serveur — un concours arbitré, un professeur qui juge une participation
-- pertinente, un code à usage unique. Un client qui pourrait écrire ici
-- s'accorderait lui-même la monnaie de fidélité, et la boutique n'aurait plus
-- aucun sens.

-- --- Les concours (D4) ----------------------------------------------------
--
-- Un concours est une fenêtre de temps posée sur un test. Le classement, lui,
-- n'est pas une table : c'est un calcul. Stocker un rang obligerait à le
-- recalculer à chaque participation et laisserait, le jour d'un incident, des
-- rangs qui ne correspondent plus aux scores — des chiffres saisis plutôt que
-- des chiffres calculés.

create table if not exists contests (
  id            text primary key default gen_random_uuid()::text,
  test_id       text not null references tests (id),
  title         text not null check (char_length(btrim(title)) >= 3),

  opens_at      timestamptz not null,
  closes_at     timestamptz not null,

  -- Ce que gagne le premier. Les suivants reçoivent une part décroissante,
  -- calculée côté serveur : la table ne fixe que l'enjeu annoncé.
  points_prize  integer not null default 0 check (points_prize >= 0),

  created_at    timestamptz not null default now(),

  -- Une fenêtre fermée avant d'être ouverte n'accepterait jamais personne, et
  -- l'erreur ne se verrait qu'au silence des participations.
  constraint contests_fenetre check (closes_at > opens_at)
);

create index if not exists contests_window_idx on contests (opens_at, closes_at);

/*
 * Une participation.
 *
 * Le plan prévoyait de réutiliser `test_sessions`. Ce n'est pas possible :
 * `test_sessions.teacher_id` référence `teachers`, c'est le test de compétence
 * d'un enseignant. Un concours d'élèves a besoin de sa propre table, rattachée
 * au compte — un élève majeur comme le parent d'un collégien participent tous
 * deux depuis un compte.
 */
create table if not exists contest_entries (
  id             text primary key default gen_random_uuid()::text,
  contest_id     text not null references contests (id) on delete cascade,
  user_id        uuid not null references auth.users (id) on delete cascade,

  -- Posés par le serveur à la correction : il détient les bonnes réponses.
  score          integer check (score between 0 and 100),
  correct_count  integer check (correct_count >= 0),

  started_at     timestamptz not null default now(),
  submitted_at   timestamptz,

  -- Une participation par concours. Sans cette contrainte, on recommencerait
  -- jusqu'à obtenir un bon score, et le classement ne voudrait plus rien dire.
  unique (contest_id, user_id)
);

create index if not exists contest_entries_rank_idx
  on contest_entries (contest_id, score desc, submitted_at asc)
  where submitted_at is not null;

alter table contests enable row level security;
alter table contest_entries enable row level security;

-- Un concours s'annonce : tout le monde doit pouvoir le voir avant d'y entrer.
create policy "concours : visibles de tous" on contests
  for select using (true);

create policy "participation : la sienne" on contest_entries
  for select using (user_id = auth.uid());

-- S'inscrire soi-même, et seulement pendant la fenêtre.
--
-- Le score n'est pas écrit ici : la colonne existe, mais aucune politique de
-- mise à jour ne la rend accessible au client. C'est le serveur qui corrige,
-- parce qu'il est le seul à voir `test_questions.correct_key`.
create policy "participation : s’inscrire pendant la fenetre" on contest_entries
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from contests c
       where c.id = contest_entries.contest_id
         and now() between c.opens_at and c.closes_at
    )
  );

-- **Aucune politique de mise à jour.** Un client qui pourrait écrire son propre
-- `score` se classerait premier.

comment on table point_ledger is
  'Monnaie de fidelite, en ajout seul. Elle se gagne et ne s''achete jamais : '
  'ce n''est pas le retour de credit_ledger, supprime le 02/10.';
comment on view point_balances is
  'Le solde est la somme du journal, jamais une colonne : un solde stocke se '
  'desynchronise et plus personne ne sait d''ou vient le chiffre.';
comment on table contest_entries is
  'Une participation par concours et par compte. Le score est pose par le '
  'serveur, seul a voir les bonnes reponses.';


-- ---------------------------------------------------------------------
-- 0021_shop.sql
-- ---------------------------------------------------------------------

-- La boutique et les lots (04/10) — phase D2.
--
-- --- Pourquoi une boutique, et pourquoi maintenant ------------------------
--
-- `point_ledger` existe depuis le 03/10 et les points s'accumulaient vers rien.
-- Une monnaie de fidelite qui n'achete rien est un nombre qui monte, et un
-- enfant s'en rend compte vite. C'est la contrepartie qui donne sa valeur a la
-- monnaie, pas l'inverse.
--
-- --- Le prix est en points, la valeur est en francs ----------------------
--
-- Les deux colonnes coexistent a dessein. « 30 000 points » ne veut rien dire
-- seul ; « 30 000 points — environ 5 000 000 GNF » rend le bareme lisible et
-- permet a une famille de juger si l'effort en vaut la peine. Le plan le
-- demandait explicitement.
--
-- `value_gnf` n'est PAS un prix de vente : rien ne s'achete ici avec de
-- l'argent. C'est un ordre de grandeur affiche, et le jour ou quelqu'un voudra
-- en faire un tarif, cette ligne dira que ce n'etait pas l'objet.

create table if not exists shop_items (
  id            text primary key,
  name          text not null check (char_length(btrim(name)) >= 2),
  summary       text,

  -- Le nom de base de l'illustration, sans extension ni densite :
  -- « lot-iphone-15 ». Le client ajoute « @2x » et « .webp » selon son ecran,
  -- comme pour les illustrations des parcours.
  image         text not null,

  points_price  integer not null check (points_price > 0),

  -- L'equivalent annonce, en francs guineens. Zero permis : un lot offert par
  -- un partenaire n'a pas toujours de valeur a afficher.
  value_gnf     bigint not null default 0 check (value_gnf >= 0),

  -- Combien il en reste. A zero, le lot reste visible mais ne s'echange plus :
  -- le retirer de l'affichage ferait croire qu'il n'a jamais existe, et c'est
  -- lui qui donne envie de continuer.
  stock         integer not null default 0 check (stock >= 0),

  active        boolean not null default true,
  position      integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists shop_items_ordre_idx
  on shop_items (position, points_price)
  where active;

/*
 * Une demande d'echange.
 *
 * `PENDING` tant qu'un humain n'a pas remis l'objet. Un telephone ne se livre
 * pas par une requete HTTP : quelqu'un le sort d'un carton et le donne en main
 * propre. La table enregistre donc une **demande**, pas une livraison, et c'est
 * la validation manuelle qui la clot.
 */
create table if not exists redemptions (
  id            text primary key default gen_random_uuid()::text,
  user_id       uuid not null references auth.users (id) on delete cascade,
  item_id       text not null references shop_items (id),

  -- Le prix au moment de l'echange, fige. Le bareme peut changer ensuite ;
  -- ce qui a ete preleve ne doit pas se mettre a jour tout seul.
  points_spent  integer not null check (points_spent > 0),

  status        text not null default 'PENDING'
                check (status in ('PENDING', 'DELIVERED', 'REFUSED')),

  requested_at  timestamptz not null default now(),
  decided_at    timestamptz,

  -- Pourquoi, quand c'est refuse. Un refus sans motif se vit comme un vol de
  -- points.
  note          text
);

create index if not exists redemptions_user_idx
  on redemptions (user_id, requested_at desc);
create index if not exists redemptions_pending_idx
  on redemptions (requested_at)
  where status = 'PENDING';

/*
 * Echanger, de maniere atomique.
 *
 * --- Pourquoi une fonction et non trois requetes ------------------------
 *
 * L'echange fait trois choses qui doivent tenir ensemble : verifier le solde,
 * debiter le journal, decrementer le stock. Faites separement depuis le
 * serveur, deux demandes simultanees passent toutes deux la verification de
 * solde et debitent deux fois — ou pire, prennent le dernier exemplaire deux
 * fois. Les telephones reessaient quand le reseau coupe, donc ce n'est pas un
 * cas theorique.
 *
 * Meme raison que `claim_session_seat` (0015) : la condition et l'ecriture dans
 * la meme instruction, et c'est Postgres qui arbitre.
 *
 * --- Ce qu'elle rend -----------------------------------------------------
 *
 * L'identifiant de la demande, ou `null` avec un motif. Pas d'exception : un
 * solde insuffisant est une reponse normale, pas une panne, et l'ecran doit
 * pouvoir dire « il vous manque 1 200 points » plutot qu'une erreur.
 */
create or replace function redeem_shop_item(item text)
  returns table (redemption_id text, reason text)
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  moi           uuid := auth.uid();
  prix          integer;
  solde         integer;
  restant       integer;
  nouvelle      text;
begin
  if moi is null then
    return query select null::text, 'NOT_SIGNED_IN';
    return;
  end if;

  -- Verrou sur la ligne du lot : deux demandes simultanees sur le dernier
  -- exemplaire se mettent en file au lieu de passer toutes les deux.
  select s.points_price, s.stock into prix, restant
    from shop_items s
   where s.id = item and s.active
     for update;

  if prix is null then
    return query select null::text, 'UNKNOWN_ITEM';
    return;
  end if;

  if restant <= 0 then
    return query select null::text, 'OUT_OF_STOCK';
    return;
  end if;

  -- Le solde est la somme du journal, jamais une colonne : il ne peut pas etre
  -- perime au moment ou on le lit.
  select coalesce(sum(delta), 0)::integer into solde
    from point_ledger where owner_id = moi;

  if solde < prix then
    return query select null::text, 'NOT_ENOUGH_POINTS';
    return;
  end if;

  update shop_items set stock = stock - 1, updated_at = now()
   where id = item;

  insert into redemptions (user_id, item_id, points_spent)
       values (moi, item, prix)
    returning id into nouvelle;

  -- Le debit porte le nom du lot : « un solde qui baisse sans raison lisible »
  -- est encore pire qu'un solde qui monte sans raison.
  insert into point_ledger (owner_id, delta, reason, reference)
       select moi, -prix, 'Echange — ' || s.name, 'redemption:' || nouvelle
         from shop_items s where s.id = item;

  return query select nouvelle, null::text;
end;
$$;

comment on function redeem_shop_item(text) is
  'Echange atomique : solde, stock et journal dans une seule instruction. '
  'Rend (null, motif) quand c''est refuse — un solde insuffisant est une '
  'reponse, pas une panne.';

alter table shop_items enable row level security;
alter table redemptions enable row level security;

-- Le catalogue s'annonce : on doit voir ce que les points permettent avant
-- d'en avoir.
create policy "boutique : visible de tous" on shop_items
  for select using (true);

create policy "echange : le sien" on redemptions
  for select using (user_id = auth.uid());

-- **Aucune politique d'ecriture sur les deux tables.** Un echange passe par
-- `redeem_shop_item`, qui est `security definer` : c'est le seul chemin, et il
-- est atomique. Une politique d'insertion sur `redemptions` permettrait de
-- demander un lot sans jamais debiter les points.

comment on table shop_items is
  'Les lots. `value_gnf` est un ordre de grandeur affiche, jamais un prix de '
  'vente : rien ne s''achete ici avec de l''argent.';
comment on table redemptions is
  'Une DEMANDE d''echange. Un telephone se remet en main propre ; la validation '
  'est humaine.';


-- ---------------------------------------------------------------------
-- 0022_shop_favorites.sql
-- ---------------------------------------------------------------------

-- Les lots mis de cote (04/10) — complement a D2.
--
-- --- Pourquoi une table, et pas un reglage local -------------------------
--
-- Un favori pourrait vivre dans SQLite, sur le telephone. Mais l'APK circule par
-- Bluetooth et se reinstalle souvent : la liste disparaitrait a la premiere
-- reinstallation, sans que personne comprenne pourquoi. Et l'ecran de la
-- boutique a de toute facon besoin du serveur — le solde en vient — donc un
-- favori local s'afficherait sur une page qui ne se charge pas hors ligne.
--
-- --- Ce que cette table a de different des points -----------------------
--
-- `point_ledger` n'a aucune politique d'ecriture : les points se gagnent par
-- une decision du serveur. Ici, au contraire, **le client ecrit lui-meme**. Un
-- favori n'a aucune valeur, ne donne droit a rien, et n'appartient qu'a la
-- personne : le lui faire demander au serveur serait une ceremonie inutile.
--
-- La difference est deliberee, et c'est la question a se poser pour toute table
-- suivante : ceci donne-t-il droit a quelque chose ? Si oui, le serveur decide.

create table if not exists shop_favorites (
  user_id     uuid not null references auth.users (id) on delete cascade,
  item_id     text not null references shop_items (id) on delete cascade,
  created_at  timestamptz not null default now(),

  -- La cle est la paire : mettre deux fois le meme lot de cote n'a pas de sens,
  -- et une contrainte evite d'avoir a verifier avant d'ecrire.
  primary key (user_id, item_id)
);

-- Les favoris d'une personne, du plus recent au plus ancien : c'est la seule
-- lecture que fait l'ecran d'accueil.
create index if not exists shop_favorites_user_idx
  on shop_favorites (user_id, created_at desc);

alter table shop_favorites enable row level security;

create policy "favoris : les siens" on shop_favorites
  for select using (user_id = auth.uid());

create policy "favoris : mettre de cote le sien" on shop_favorites
  for insert with check (user_id = auth.uid());

-- Et pouvoir le retirer. Sans cette politique, un favori serait definitif :
-- l'ecran proposerait un coeur qui ne s'eteint jamais.
create policy "favoris : retirer le sien" on shop_favorites
  for delete using (user_id = auth.uid());

-- **Aucune politique de mise a jour** : il n'y a rien a modifier dans une paire
-- (compte, lot). On ajoute ou on retire.

comment on table shop_favorites is
  'Lots mis de cote. Le client ecrit lui-meme, contrairement a point_ledger : '
  'un favori ne donne droit a rien.';


-- ---------------------------------------------------------------------
-- 0023_earning.sql
-- ---------------------------------------------------------------------

-- Gagner des points en apprenant (04/10) — la source qui manquait.
--
-- --- Le defaut que ceci corrige ------------------------------------------
--
-- Depuis le 03/10, la seule facon de gagner un point etait de remporter un
-- concours hebdomadaire. Un eleve qui n'en fait pas n'en aurait jamais tenu un
-- seul, et la boutique lui montrait des lots sans aucun chemin pour les
-- atteindre. Une monnaie sans source est un decor.
--
-- --- Pourquoi des declencheurs et non du code serveur --------------------
--
-- Les evenements qui meritent des points sont ecrits par **deux chemins
-- differents** : la presence vient des webhooks LiveKit, donc du serveur ; la
-- reponse a un point de controle est ecrite par le telephone lui-meme, sous
-- RLS. Mettre la regle dans le Worker ne crediterait que la moitie des cas.
--
-- Un declencheur couvre les deux, et c'est le meme raisonnement que pour
-- `point_ledger_no_rewrite` : ce qui doit valoir pour tout le monde se met dans
-- la base, pas dans un appelant.
--
-- --- Pourquoi on ne peut pas tricher -------------------------------------
--
-- Aucun de ces evenements n'est declare par le client :
--
--   * les minutes de presence sont comptees par le serveur de visioconference ;
--   * la reponse a un point de controle exige une place payee et un vote encore
--     ouvert, verifies par la politique d'insertion de 0018.
--
-- On ne peut donc pas moissonner des points en cliquant. C'est la difference
-- avec les plateformes ou l'XP recompense le fait d'avoir appuye sur
-- « continuer ».

-- Un point tous les cinq minutes de presence : une seance de 90 minutes en
-- rapporte 18. Assez pour voir le compteur bouger, trop peu pour que rester
-- connecte sans rien faire devienne une strategie.
create or replace function points_pour_minutes(minutes integer)
  returns integer
  language sql
  immutable
as $$
  select greatest(0, coalesce(minutes, 0) / 5);
$$;

/*
 * Crediter sans jamais crediter deux fois.
 *
 * Chaque gain porte une `reference` qui decrit l'evenement exact — la ligne de
 * presence, le vote. La fonction regarde si cette reference a deja paye avant
 * d'ecrire : un webhook rejoue par LiveKit, ou une mise a jour de presence qui
 * repasse, ne doit pas doubler les points.
 *
 * `security definer` : `point_ledger` n'a aucune politique d'ecriture, et c'est
 * voulu. Le declencheur ecrit donc avec les droits du proprietaire, ce qui
 * laisse la table fermee aux clients tout en permettant a la base de crediter.
 */
create or replace function crediter_points(
  beneficiaire uuid,
  montant integer,
  motif text,
  cle text
) returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
begin
  if beneficiaire is null or montant is null or montant <= 0 then
    return;
  end if;

  -- `delta <> 0` est une contrainte de la table : un gain nul ferait echouer
  -- l'operation qui l'a provoque — une sortie de salle, un vote — et c'est elle
  -- qui compte le plus.
  if exists (select 1 from point_ledger where reference = cle) then
    return;
  end if;

  insert into point_ledger (owner_id, delta, reason, reference)
       values (beneficiaire, montant, motif, cle);
end;
$$;

-- --- 1. Les cent points de bienvenue ---------------------------------------
--
-- Offerts a la creation du profil, quel que soit le chemin : inscription depuis
-- le telephone, depuis le site, ou creation a la main dans l'editeur SQL. Un
-- declencheur les couvre tous.
--
-- **Ils ne suffisent a rien acheter**, et c'est deliberé : le plus petit lot en
-- coute 250. Sinon creer des comptes deviendrait une facon de recolter des
-- forfaits internet, et le premier a le comprendre ne serait pas un eleve.
-- Leur role est de montrer un compteur qui n'est pas a zero le premier jour.
create or replace function accorder_points_bienvenue() returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
begin
  perform crediter_points(
    new.id, 100, 'Bienvenue sur Eduquali', 'welcome:' || new.id
  );
  return new;
end;
$$;

drop trigger if exists profiles_bienvenue on profiles;
create trigger profiles_bienvenue
  after insert on profiles
  for each row execute function accorder_points_bienvenue();

-- --- 2. La presence en seance ----------------------------------------------
--
-- Au moment ou la presence se ferme, et pas a l'entree : sinon rejoindre puis
-- partir aussitot paierait autant qu'assister.
create or replace function accorder_points_presence() returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  gagnes integer := points_pour_minutes(new.minutes);
begin
  perform crediter_points(
    new.user_id,
    gagnes,
    'Séance suivie — ' || coalesce(new.minutes, 0) || ' minutes',
    'attendance:' || new.id
  );
  return new;
end;
$$;

drop trigger if exists attendance_points on session_attendance;
create trigger attendance_points
  after update on session_attendance
  for each row
  -- Uniquement au passage de « en cours » a « terminee ». Sans cette garde, une
  -- correction ulterieure des minutes rejouerait le credit.
  when (old.left_at is null and new.left_at is not null)
  execute function accorder_points_presence();

-- --- 3. Repondre a un point de controle ------------------------------------
--
-- Deux points par vote, quatre votes par seance : huit points, soit a peu pres
-- la moitie de ce que rapporte la presence. Repondre compte, mais rester et
-- suivre compte davantage.
--
-- Le gain ne depend pas de la reponse donnee. Payer « oui » plus que « non »
-- apprendrait a dire qu'on a compris, et le professeur lirait un tableau faux —
-- ce que le resume de 0018 est justement cense eviter.
create or replace function accorder_points_checkpoint() returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  beneficiaire uuid;
begin
  -- La place payee porte le parent ; le parent porte le compte.
  select p.user_id into beneficiaire
    from session_enrolments e
    join parents p on p.id = e.parent_id
   where e.id = new.enrolment_id;

  perform crediter_points(
    beneficiaire,
    2,
    'Participation en séance',
    'checkpoint:' || new.checkpoint_id || ':' || new.enrolment_id
  );
  return new;
end;
$$;

drop trigger if exists checkpoint_points on checkpoint_answers;
create trigger checkpoint_points
  after insert on checkpoint_answers
  for each row execute function accorder_points_checkpoint();

comment on function crediter_points(uuid, integer, text, text) is
  'Credite une fois et une seule : la reference decrit l''evenement, et un '
  'webhook rejoue ne doit pas doubler les points.';
comment on function points_pour_minutes(integer) is
  'Un point par tranche de cinq minutes. Une seance de 90 minutes en vaut 18.';


-- ---------------------------------------------------------------------
-- 0024_raffle.sql
-- ---------------------------------------------------------------------

-- Le tirage au sort (04/10) — la sortie pour les lots de valeur.
--
-- --- Le probleme, en une ligne --------------------------------------------
--
-- Un telephone a 8 000 000 GNF ne s'achete pas avec la fidelite d'UN eleve. A
-- 26 points par semaine, l'iPhone 17 demandait 1 850 seances : on promettait
-- quelque chose que personne n'obtiendrait, ce qui demotive plus surement
-- qu'une boutique vide.
--
-- Baisser le prix ne reglait rien. L'arithmetique ne depend pas du bareme, elle
-- depend du fait qu'un eleve ne rapporte pas huit millions.
--
-- --- Ce que le tirage change ---------------------------------------------
--
-- Les points n'achetent plus l'objet, ils achetent une **chance**. La promesse
-- passe de « travaillez 1 850 seances » a « l'un de vous le gagnera », qui est
-- vraie, finançable, et motivante pour tout le monde en meme temps.
--
-- Cent eleves qui misent quelques entrees par mois rendent un Galaxy A5
-- mensuel soutenable, la ou le vendre a un seul ne l'etait jamais.
--
-- --- ⚠ Une question qui n'est pas technique ------------------------------
--
-- Un tirage au sort peut relever d'une reglementation locale. Ici les points se
-- **gagnent** et ne s'achetent pas — ce n'est donc pas une loterie payante,
-- plutot un jeu de fidelite —, mais la frontiere se verifie aupres de quelqu'un
-- qui connait le droit guineen, pas dans un fichier SQL.

-- Acheter l'objet, ou acheter une chance de l'avoir.
alter table shop_items
  add column if not exists kind text not null default 'DIRECT'
    check (kind in ('DIRECT', 'RAFFLE'));

-- La date du tirage, pour les lots qui s'en remettent au sort. Affichee :
-- « tirage le 30 novembre » transforme une attente en rendez-vous.
alter table shop_items add column if not exists draws_at timestamptz;

-- Le prix gele porte deja sur la demande ; son **genre** aussi, pour la meme
-- raison. Un lot qui passerait de DIRECT a RAFFLE ne doit pas reecrire ce que
-- les gens ont deja obtenu.
alter table redemptions
  add column if not exists kind text not null default 'DIRECT'
    check (kind in ('DIRECT', 'RAFFLE'));

-- Les entrees d'un tirage encore ouvert : la requete de l'ecran, et celle du
-- tirage lui-meme.
create index if not exists redemptions_raffle_idx
  on redemptions (item_id, status)
  where kind = 'RAFFLE';

/*
 * Echanger — ou tenter sa chance.
 *
 * La fonction de 0021 est remplacee plutot que doublee : deux fonctions qui
 * debitent des points finiraient par diverger sur la verification du solde, et
 * c'est exactement l'endroit ou une divergence coute de l'argent.
 *
 * Les deux branches partagent donc tout ce qui compte — verrou sur la ligne,
 * solde lu depuis le journal, debit nomme — et ne different que sur deux
 * points :
 *
 *   * **le stock** ne bouge pas pour un tirage. Il compte les objets a gagner,
 *     pas les entrees vendues ; le decrementer a chaque mise epuiserait le lot
 *     avant le tirage ;
 *   * **la repetition** est permise. Miser trois fois triple ses chances, et
 *     c'est tout l'interet. Un achat direct, lui, reste limite par le stock.
 */
create or replace function redeem_shop_item(item text)
  returns table (redemption_id text, reason text)
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  moi      uuid := auth.uid();
  prix     integer;
  restant  integer;
  genre    text;
  nom      text;
  solde    integer;
  nouvelle text;
begin
  if moi is null then
    return query select null::text, 'NOT_SIGNED_IN';
    return;
  end if;

  select s.points_price, s.stock, s.kind, s.name
    into prix, restant, genre, nom
    from shop_items s
   where s.id = item and s.active
     for update;

  if prix is null then
    return query select null::text, 'UNKNOWN_ITEM';
    return;
  end if;

  -- Un tirage sans objet a gagner n'accepte plus de mise : prendre des points
  -- pour une chance de gagner rien serait un vol.
  if restant <= 0 then
    return query select null::text, 'OUT_OF_STOCK';
    return;
  end if;

  -- Et un tirage deja passe non plus.
  if genre = 'RAFFLE' and exists (
    select 1 from shop_items s
     where s.id = item and s.draws_at is not null and s.draws_at < now()
  ) then
    return query select null::text, 'DRAW_CLOSED';
    return;
  end if;

  select coalesce(sum(delta), 0)::integer into solde
    from point_ledger where owner_id = moi;

  if solde < prix then
    return query select null::text, 'NOT_ENOUGH_POINTS';
    return;
  end if;

  if genre = 'DIRECT' then
    update shop_items set stock = stock - 1, updated_at = now()
     where id = item;
  end if;

  insert into redemptions (user_id, item_id, points_spent, kind)
       values (moi, item, prix, genre)
    returning id into nouvelle;

  insert into point_ledger (owner_id, delta, reason, reference)
       values (
         moi,
         -prix,
         case
           when genre = 'RAFFLE' then 'Participation au tirage — ' || nom
           else 'Echange — ' || nom
         end,
         'redemption:' || nouvelle
       );

  return query select nouvelle, null::text;
end;
$$;

/*
 * Tirer au sort.
 *
 * Reserve au serveur : la fonction decide qui gagne, et personne d'autre ne
 * doit pouvoir la declencher.
 *
 * Toutes les entrees sont traitees d'un coup — la gagnante passe `DELIVERED`,
 * les autres `REFUSED` avec un motif lisible. Laisser les perdantes en
 * `PENDING` donnerait des demandes eternellement en attente, et personne ne
 * saurait jamais que le tirage a eu lieu.
 *
 * **Les points ne sont pas rendus.** Une mise perdue reste depensee, c'est la
 * nature d'un tirage, et la phrase du refus le dit en clair plutot que de
 * laisser deviner.
 */
create or replace function draw_raffle(item text)
  returns table (winner uuid, entries integer)
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  gagnante text;
  total    integer;
  nom      text;
begin
  select s.name into nom from shop_items s where s.id = item for update;
  if nom is null then
    return;
  end if;

  select count(*) into total
    from redemptions r
   where r.item_id = item and r.kind = 'RAFFLE' and r.status = 'PENDING';

  if total = 0 then
    return query select null::uuid, 0;
    return;
  end if;

  -- Une entree au hasard parmi celles en attente : miser trois fois donne donc
  -- bien trois fois plus de chances, puisque chaque mise est une ligne.
  select r.id into gagnante
    from redemptions r
   where r.item_id = item and r.kind = 'RAFFLE' and r.status = 'PENDING'
   order by random()
   limit 1;

  update redemptions
     set status = 'DELIVERED',
         decided_at = now(),
         note = 'Tirage gagnant — un responsable vous contacte pour la remise.'
   where id = gagnante;

  update redemptions
     set status = 'REFUSED',
         decided_at = now(),
         note = 'Tirage du ' || to_char(now(), 'DD/MM/YYYY') ||
                ' : ce n''est pas passé cette fois. Les points misés restent ' ||
                'dépensés, comme annoncé.'
   where item_id = item and kind = 'RAFFLE' and status = 'PENDING';

  update shop_items
     set stock = greatest(stock - 1, 0), updated_at = now()
   where id = item;

  return query
    select r.user_id, total from redemptions r where r.id = gagnante;
end;
$$;

comment on function draw_raffle(text) is
  'Tire un gagnant parmi les entrees en attente et tranche toutes les autres. '
  'Les points mises ne sont pas rendus : c''est la nature d''un tirage.';
comment on column shop_items.kind is
  'DIRECT : les points achetent l''objet. RAFFLE : ils achetent une chance, '
  'parce qu''un telephone a 8 000 000 GNF ne s''achete pas avec la fidelite '
  'd''un seul eleve.';


-- ---------------------------------------------------------------------
-- 0025_gifts.sql
-- ---------------------------------------------------------------------

-- Offrir des points a quelqu'un (04/10) — phase D3, plafonnee a 2 par jour.
--
-- --- Le plafond -----------------------------------------------------------
--
-- Le plan prevoyait **10 points par jour**. C'est deux, decide le 04/10, et la
-- raison est arithmetique : une seance suivie en rapporte 18. A dix par jour, un
-- groupe de quatre comptes complices transfere tout son solde vers un seul en
-- quelques jours, et la boutique se vide au profit de qui a le plus d'amis
-- plutot que de qui a le plus suivi.
--
-- A deux, le geste garde son sens — remercier, encourager — sans devenir un
-- moyen de concentrer la monnaie.
--
-- --- Pourquoi une fonction et non deux ecritures depuis le serveur -------
--
-- Un transfert, ce sont **deux lignes qui doivent exister ensemble** : le debit
-- de l'un et le credit de l'autre. Faites separement, une panne entre les deux
-- fait disparaitre des points ou en invente. Ici les deux vivent dans la meme
-- instruction, et c'est Postgres qui garantit le tout ou rien.
--
-- Le plafond se verifie dans la meme instruction, sous le meme verrou : le lire
-- puis ecrire laisserait deux requetes simultanees passer toutes deux.

/** Ce qu'un compte peut offrir par jour. */
create or replace function plafond_don_quotidien() returns integer
  language sql immutable
as $$
  select 2;
$$;

/*
 * Offrir des points.
 *
 * Rend (false, motif) plutot que de lever : un plafond atteint est une reponse
 * normale, et l'ecran doit pouvoir dire « vous avez deja offert vos deux points
 * aujourd'hui » plutot qu'afficher une erreur.
 */
create or replace function offrir_points(
  destinataire uuid,
  montant integer
) returns table (ok boolean, reason text)
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  moi     uuid := auth.uid();
  solde   integer;
  deja    integer;
  qui     text;
  plafond integer := plafond_don_quotidien();
begin
  if moi is null then
    return query select false, 'NOT_SIGNED_IN';
    return;
  end if;

  if montant is null or montant <= 0 then
    return query select false, 'INVALID_AMOUNT';
    return;
  end if;

  -- S'offrir a soi-meme ne serait pas une fraude, juste une ecriture inutile
  -- qui salirait les deux journaux.
  if destinataire = moi then
    return query select false, 'SELF_GIFT';
    return;
  end if;

  select p.first_name into qui from profiles p where p.id = destinataire;
  if qui is null then
    return query select false, 'UNKNOWN_RECIPIENT';
    return;
  end if;

  -- Verrou sur le compte donneur : deux dons simultanes se mettent en file au
  -- lieu de passer tous les deux sous le plafond.
  perform 1 from profiles where id = moi for update;

  select coalesce(-sum(delta), 0)::integer into deja
    from point_ledger
   where owner_id = moi
     and delta < 0
     and reference like 'gift:%'
     -- Jour calendaire, et non « 24 heures glissantes » : « vous pourrez
     -- reoffrir demain » se comprend, « dans 7 h 12 » se subit.
     and created_at >= date_trunc('day', now());

  if deja + montant > plafond then
    return query select false, 'DAILY_LIMIT';
    return;
  end if;

  select coalesce(sum(delta), 0)::integer into solde
    from point_ledger where owner_id = moi;

  if solde < montant then
    return query select false, 'NOT_ENOUGH_POINTS';
    return;
  end if;

  -- Les deux ecritures, liees par la meme reference : on peut toujours
  -- rapprocher un debit de son credit, ce qu'une correction manuelle exigera
  -- le jour ou elle arrivera.
  declare
    lien text := 'gift:' || gen_random_uuid()::text;
    monNom text;
  begin
    select coalesce(p.first_name, 'Quelqu''un') into monNom
      from profiles p where p.id = moi;

    insert into point_ledger (owner_id, delta, reason, reference)
         values (moi, -montant, 'Offert à ' || qui, lien);

    insert into point_ledger (owner_id, delta, reason, reference)
         values (destinataire, montant, 'Offert par ' || monNom, lien);
  end;

  return query select true, null::text;
end;
$$;

comment on function offrir_points(uuid, integer) is
  'Transfert plafonne a 2 points par jour et par compte. Les deux ecritures '
  'dans la meme instruction : une panne entre les deux ferait disparaitre des '
  'points ou en inventerait.';
comment on function plafond_don_quotidien() is
  'Deux. A dix, quatre comptes complices concentraient leur monnaie en '
  'quelques jours.';


-- ---------------------------------------------------------------------
-- 0026_onboarding_answers.sql
-- ---------------------------------------------------------------------

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


-- ---------------------------------------------------------------------
-- 0027_chat_groups.sql
-- ---------------------------------------------------------------------

-- Les groupes de discussion (04/10).
--
-- --- Ce qui existait, et pourquoi ça ne suffit pas -------------------------
--
-- `conversations` est strictement à deux : un fil appartient à un professeur
-- et, en face, soit une famille soit un établissement. Trois personnes dans la
-- même discussion n'ont jamais été possibles. Or c'est ce que demande un cours
-- en direct suivi par quinze familles : les questions de l'une servent aux
-- autres, et les reposer en quinze fils privés fait quinze fois le travail.
--
-- Le fil à deux reste : il sert au premier contact, à une question qui ne
-- regarde que la famille, à la négociation d'un contrat. On ajoute le groupe à
-- côté, on ne le remplace pas.
--
-- --- L'appartenance est dérivée, jamais stockée ----------------------------
--
-- Décidé le 04/10, et c'est la même règle que pour le répertoire du
-- professeur : **l'accès suit la relation**.
--
-- Un groupe n'existe qu'autour de quelque chose qui existe déjà — un cours en
-- direct, un contrat — et ses membres sont ceux que cette chose lie. Il n'y a
-- donc ni table de membres, ni invitation, ni code à partager, et surtout
-- aucun moyen d'entrer dans un groupe d'adolescents sans y avoir sa place.
--
-- Une table `chat_group_members` serait une copie qui divergerait : la place
-- est annulée, le contrat se termine, et la ligne reste. Pour un produit qui
-- traite des mineurs, c'est la propriété qui décide — une personne perd
-- l'accès au moment où elle perd la relation, sans que personne ait à y
-- penser.
--
-- Le prix est assumé : on ne peut pas créer un groupe « entre amis ». Ce
-- n'était pas demandé, et ce serait une tout autre responsabilité.
--
-- --- Pourquoi les messages, eux, sont conservés ---------------------------
--
-- Le fil de discussion d'une séance en direct (`live_chat_overlay.dart`) est
-- volontairement éphémère : il commente une vidéo, il se lit pendant, et un
-- historique de salle de classe serait une charge à modérer pour rien.
--
-- Un groupe de cours est l'inverse : c'est là que vit la question posée le
-- soir sur l'exercice 3, et une question sans réponse lisible le lendemain ne
-- sert à personne. On conserve donc.
--
-- ⚠ Ce que cela ouvre et qui n'est **pas** traité ici : la modération et la
-- durée de conservation. Il n'existe ni signalement, ni suppression par un
-- tiers, ni purge automatique. Voir documentation/ROADMAP.md.

-- --- Le groupe -------------------------------------------------------------

create table if not exists chat_groups (
  id          text primary key default gen_random_uuid()::text,

  -- COURSE : un cours en direct et ses inscrits.
  -- CONTRACT : un contrat, donc le professeur et son employeur.
  kind        text not null check (kind in ('COURSE', 'CONTRACT')),

  -- La chose dont ce groupe est la discussion. Pas de clé étrangère : elle
  -- viserait deux tables selon `kind`, ce que Postgres ne sait pas exprimer.
  -- L'intégrité est tenue par `est_membre_groupe`, qui ne rend vrai que si la
  -- relation existe encore — un groupe orphelin devient donc inaccessible de
  -- lui-même, ce qui est le comportement voulu.
  source_id   text not null,

  -- Recopié à la création pour que la liste s'affiche sans joindre quatre
  -- tables. Le nom d'un cours ne change pas tous les jours.
  name        text not null,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  -- Un seul groupe par relation : deux rendraient la conversation illisible,
  -- chacun en voyant la moitié.
  unique (kind, source_id)
);

-- --- Les messages ----------------------------------------------------------

create table if not exists chat_messages (
  id         text primary key default gen_random_uuid()::text,
  group_id   text not null references chat_groups (id) on delete cascade,

  -- Le compte, et non la fiche : un professeur et un parent écrivent dans le
  -- même groupe, et `profiles.id` est ce qu'ils ont en commun.
  author_id  uuid not null references profiles (id) on delete cascade,

  -- Borné : sans limite, un envoi accidentel colle plusieurs mégaoctets dans
  -- une liste que quinze téléphones vont relire.
  body       text not null check (length(btrim(body)) between 1 and 2000),

  created_at timestamptz not null default now()
);

-- La seule lecture qui existe : les derniers messages d'un groupe.
create index if not exists chat_messages_group_idx
  on chat_messages (group_id, created_at desc);

/*
 * Cette personne a-t-elle sa place dans ce groupe ?
 *
 * `security definer` parce que la réponse demande de lire des tables que le
 * lecteur n'a pas le droit de parcourir — les inscriptions des autres
 * familles, par exemple. La fonction ne rend qu'un booléen : elle n'expose
 * rien de ce qu'elle a lu.
 *
 * Tout passe par ici : les politiques des deux tables, et rien d'autre. Une
 * deuxième définition de « membre » quelque part ailleurs finirait par
 * s'écarter de celle-ci, et c'est la porte d'un groupe d'enfants.
 */
create or replace function est_membre_groupe(groupe text, qui uuid)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from chat_groups g
     where g.id = groupe
       and (
         -- Le cours en direct : son professeur, et les familles qui ont une
         -- place payée sur l'une de ses séances.
         (g.kind = 'COURSE' and (
            exists (
              select 1
                from live_courses c
                join teachers t on t.id = c.teacher_id
               where c.id = g.source_id
                 and t.user_id = qui
            )
            or exists (
              select 1
                from live_sessions s
                join session_enrolments e on e.session_id = s.id
                join parents p on p.id = e.parent_id
               where s.live_course_id = g.source_id
                 and e.status = 'CONFIRMED'
                 and p.user_id = qui
            )
         ))
         -- Le contrat : le professeur, et l'employeur — famille ou
         -- etablissement. Un contrat termine (`ENDED`) ne donne plus acces :
         -- c'est exactement ce que « l'acces suit la relation » veut dire.
         or (g.kind = 'CONTRACT' and exists (
              select 1
                from work_contracts w
                left join teachers t      on t.id = w.teacher_id
                left join parents p       on p.id = w.parent_id
                left join institutions i  on i.id = w.institution_id
               where w.id = g.source_id
                 and w.status in ('PENDING', 'ACTIVE')
                 and (t.user_id = qui or p.user_id = qui or i.owner_id = qui)
         ))
       )
  );
$$;

-- --- Les politiques --------------------------------------------------------

alter table chat_groups   enable row level security;
alter table chat_messages enable row level security;

create policy "groupes : les siens" on chat_groups
  for select using (est_membre_groupe(id, auth.uid()));

-- Aucune politique d'ecriture sur `chat_groups` : un groupe nait d'une
-- relation, donc du serveur, qui l'ouvre sous la cle de service au moment ou
-- la relation nait. Un client qui pourrait en creer un choisirait ses propres
-- membres.

create policy "messages : ceux de ses groupes" on chat_messages
  for select using (est_membre_groupe(group_id, auth.uid()));

create policy "messages : ecrire dans ses groupes" on chat_messages
  for insert with check (
    author_id = auth.uid()
    and est_membre_groupe(group_id, auth.uid())
  );

-- Ni `update` ni `delete` : un message envoye reste.
--
-- Ce n'est pas une position sur la moderation, c'est son absence assumee pour
-- l'instant — il n'existe ni signalement ni suppression par un tiers, et
-- laisser un auteur reecrire son message apres coup rendrait un signalement
-- futur inexploitable. Le jour ou la moderation s'ecrit, elle passera par le
-- serveur, pas par une politique ouverte au client.

comment on table chat_groups is
  'Un groupe par relation (cours en direct, contrat). L''appartenance est '
  'derivee par est_membre_groupe() et jamais stockee : elle expire avec la '
  'relation, ce qui compte pour un produit qui traite des mineurs.';
comment on function est_membre_groupe(text, uuid) is
  'La seule definition de « membre ». Les deux tables s''y referent ; une '
  'seconde definition ailleurs finirait par s''en ecarter.';
comment on table chat_messages is
  'Conserves, contrairement au fil d''une seance en direct qui est ephemere : '
  'c''est ici que vit la question posee le soir sur l''exercice 3.';


commit;
