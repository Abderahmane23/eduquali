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
