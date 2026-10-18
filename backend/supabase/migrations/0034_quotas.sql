-- Ce qu'un compte a consommé, et sur quelle période (18/10).
--
-- --- Pourquoi cette table ------------------------------------------------
--
-- Les formules vendues ne sont plus « ouvert / fermé » mais des quantités :
-- quatre cours et deux directs par mois pour Découverte, un direct par
-- quinzaine et un cours par mois pour le gratuit. Rien ne comptait ces
-- gestes. Une limite qu'on ne sait pas compter est une limite qu'on
-- n'applique pas — et elle finit par s'apprendre, puis se contourner.
--
-- L'assistant, lui, était déjà compté : `ai_messages_du_jour` lit
-- `ai_messages`. On ne le double pas ici. Cette table couvre les deux gestes
-- qui ne laissaient aucune trace exploitable : rejoindre un direct, et
-- ouvrir un cours enregistré.
--
-- --- Pourquoi une ligne par geste, et non un compteur ---------------------
--
-- Un compteur qu'on incrémente ne sait pas se remettre à zéro : il faudrait
-- une tâche qui passe à minuit, le premier du mois, et tous les quinze jours
-- glissants — trois horloges pour une seule question. Une ligne par geste,
-- horodatée, répond aux trois en comptant sur une fenêtre.
--
-- Elle sert aussi à autre chose : « combien de familles ont rejoint un
-- direct cette semaine » est la même requête. Un compteur l'aurait perdue.
--
-- --- Ce qui n'est pas ici -------------------------------------------------
--
-- Aucun paiement. `payments` n'est pas configuré sur le Worker, et une
-- formule payante ne s'obtient pas encore toute seule. Cette table compte ce
-- qui est consommé ; elle ne décide pas qui a payé.

-- --- La formule, enfin cote serveur --------------------------------------
--
-- `profiles` ne portait **aucune** colonne de formule. Le niveau d'abonnement
-- ne vivait que dans la base SQLite du telephone (`users.planRenewsAt`), ou
-- il est modifiable par qui tient l'appareil — et l'APK circule par Bluetooth.
-- Autrement dit : ce qui est vendu n'etait ecrit nulle part d'opposable.
--
-- `pending_plan` existait, mais c'est l'intention declaree a l'inscription,
-- explicitement « pas encore payee ». Elle ne peut pas servir de droit.
--
-- Les deux colonnes sont donc ajoutees ici. Rien ne les ecrit encore : aucun
-- paiement n'est branche, et c'est voulu. Un compte reste gratuit, avec ses
-- sept jours d'essai comptes depuis `created_at`.
alter table profiles
  add column if not exists plan text
    check (plan is null or plan in ('FREE', 'PRO', 'MASTER')),
  add column if not exists plan_renews_at timestamptz;

comment on column profiles.plan is
  'Formule payee. Vide vaut gratuit. Sans `plan_renews_at` dans le futur, '
  'elle ne donne aucun droit : sinon il suffirait de l''ecrire.';
comment on column profiles.plan_renews_at is
  'Fin de la periode payee. Le jour meme compte encore.';

create table if not exists usage_events (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references auth.users (id) on delete cascade,

  -- `direct` ou `cours`. Contrainte plutôt qu'enum : ajouter une ressource
  -- se fait alors sans verrou de table, et la liste reste lisible ici.
  ressource  text not null check (ressource in ('direct', 'cours')),

  -- Ce qui a été consommé : la séance, ou le cours. Deux ouvertures du même
  -- cours ne comptent qu'une fois — voir l'index unique plus bas.
  cible_id   text not null,

  consomme_le timestamptz not null default now()
);

comment on table usage_events is
  'Un geste consommé sur un quota : rejoindre un direct, ouvrir un cours. '
  'Horodaté pour que la même table réponde au jour, au mois et à la '
  'quinzaine glissante.';

-- La lecture est toujours « ce compte, cette ressource, depuis telle date ».
create index if not exists usage_events_fenetre
  on usage_events (owner_id, ressource, consomme_le desc);

/*
 * Un même cours ouvert deux fois ne consomme qu'une place.
 *
 * Sans cette unicité, refermer et rouvrir un cours mangerait le quota du
 * mois en quatre gestes — et la personne aurait raison de trouver cela
 * malhonnête. Elle paie l'accès à quatre cours, pas quatre ouvertures.
 *
 * Pour un direct, la cible est la séance : la rejoindre deux fois après une
 * coupure de réseau ne doit pas compter double non plus.
 */
create unique index if not exists usage_events_une_fois
  on usage_events (owner_id, ressource, cible_id);

alter table usage_events enable row level security;

/*
 * On lit ce qu'on a consommé soi-même, et rien d'autre.
 *
 * L'écriture n'a pas de politique : elle passe par la clé de service, dans
 * le Worker, au moment où il accorde le geste. Un client qui pourrait
 * écrire ici pourrait aussi ne pas écrire — c'est-à-dire ne jamais
 * consommer son quota.
 */
drop policy if exists usage_events_lecture on usage_events;
create policy usage_events_lecture on usage_events
  for select using (owner_id = auth.uid());

/**
 * Combien de fois ce compte a consommé cette ressource depuis `depuis`.
 *
 * `security definer` : la fonction est appelée par le Worker avec la clé de
 * service, et elle ne rend qu'un nombre — jamais les lignes.
 */
create or replace function usage_compte(
  qui uuid,
  quoi text,
  depuis timestamptz
) returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer
    from usage_events
   where owner_id = qui
     and ressource = quoi
     and consomme_le >= depuis;
$$;

comment on function usage_compte is
  'Le nombre de gestes consommés depuis une date. Rend un nombre, jamais '
  'les lignes : le quota n''a pas besoin de savoir quoi, seulement combien.';

grant execute on function usage_compte to service_role;
