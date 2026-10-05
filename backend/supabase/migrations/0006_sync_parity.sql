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
