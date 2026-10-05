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
