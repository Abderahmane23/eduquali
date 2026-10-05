-- Le minimum de Supabase pour que le schéma s'exécute sur un Postgres nu.
--
-- --- Pourquoi ce fichier -------------------------------------------------
--
-- Les 17 migrations s'appuient sur trois choses que Supabase fournit et qu'un
-- Postgres ordinaire n'a pas :
--
--   * `auth.uid()` — l'identifiant du compte appelant, lu 33 fois dans les
--     politiques RLS ;
--   * `auth.users` — la table des comptes, référencée deux fois par
--     `profiles.id` ;
--   * le rôle `anon`, destinataire de deux `grant`.
--
-- Sans eux, impossible de vérifier quoi que ce soit : la première politique
-- échoue et on ne sait pas si les seize migrations suivantes tiennent.
--
-- --- Ce que ce fichier n'est pas -----------------------------------------
--
-- **Ce n'est pas une imitation de Supabase et il ne prouve rien sur le
-- comportement de RLS.** `auth.uid()` rend ici une valeur de session que le banc
-- d'essai choisit lui-même ; chez Supabase elle est extraite du JWT. Ce qui est
-- vérifié avec ce fichier est que **le schéma s'exécute** : syntaxe, ordre des
-- dépendances, types, contraintes, index, fonctions plpgsql, vues. C'est
-- précisément ce que ni `check-sql.mjs` ni une relecture ne peuvent établir.
--
-- Ce qu'il ne vérifie pas, et qu'il faut garder en tête : qu'une politique
-- donnée ferme bien ce qu'elle doit fermer. Cela demande de vrais comptes et de
-- vrais jetons, donc un projet Supabase.

create schema if not exists auth;

/*
 * La table des comptes, réduite à ce que le schéma utilise.
 *
 * Supabase y met une quarantaine de colonnes (jetons de confirmation, méthodes
 * d'authentification, métadonnées). Les recopier donnerait l'illusion d'une
 * fidélité qui n'existe pas : seules `id` et l'existence de la ligne comptent
 * pour nos clés étrangères.
 */
create table if not exists auth.users (
  id    uuid primary key default gen_random_uuid(),
  email text,
  phone text
);

/*
 * Le compte appelant.
 *
 * Chez Supabase, cette fonction lit la revendication `sub` du JWT transmis par
 * PostgREST. Ici elle lit un réglage de session, que le banc d'essai pose avec
 * `set local request.jwt.claim.sub`. La forme est volontairement la même que
 * celle de Supabase, pour qu'un test écrit contre ce banc reste lisible.
 *
 * `nullif` : un réglage absent rend la chaîne vide, et `''::uuid` lève. Un
 * appelant anonyme doit rendre `null`, ce qui est le cas qui ferme les
 * politiques.
 */
create or replace function auth.uid() returns uuid as $$
  select nullif(
    current_setting('request.jwt.claim.sub', true),
    ''
  )::uuid;
$$ language sql stable;

/*
 * Les rôles de PostgREST.
 *
 * `anon` reçoit deux `grant` dans les migrations. `authenticated` et
 * `service_role` n'y figurent pas encore mais existent chez Supabase : les créer
 * ici évite qu'une migration future échoue sur le banc d'essai pour une raison
 * qui n'a rien à voir avec elle.
 *
 * `do` plutôt que `create role if not exists`, qui n'existe pas en Postgres.
 */
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;
