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
