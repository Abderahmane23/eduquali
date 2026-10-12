-- Ce qui manquait au navigateur (11/10).
--
-- --- Le constat qui a declenche ce fichier --------------------------------
--
-- La comparaison des deux clients a montre que le site sait inscrire un
-- professeur, lui faire passer un test et publier un cours — puis plus rien.
-- Il ne peut ni montrer ses pieces, ni savoir ce qu'il a gagne, ni etre
-- paye, ni parler a l'assistant. Les tables de ces trois choses existaient
-- deja pour les deux premieres (`teacher_documents`, `tutoring_*`) ; il
-- manquait de quoi demander un paiement et de quoi tenir une conversation
-- avec le modele.
--
-- Trois tables, donc, et pas une de plus : tout le reste est du code
-- d'appel.

-- ===========================================================================
-- 1. Les demandes de retrait
-- ===========================================================================
--
-- --- Pourquoi une demande et non un virement ------------------------------
--
-- Le paiement sortant est manuel au lancement : un operateur regarde la
-- demande, verifie, puis envoie l'argent par Orange Money. Automatiser la
-- sortie avant d'avoir vu passer dix virements reviendrait a confier a du
-- code non eprouve la seule operation qu'on ne peut pas annuler.
--
-- La table est donc une file d'attente, pas un journal de virements. Elle
-- porte ce que l'operateur doit savoir et rien de plus.
--
-- --- Ce qu'elle ne porte pas ---------------------------------------------
--
-- Pas de numero de compte complet, pas de solde. Le solde se **recalcule**
-- depuis les ventes et les retraits deja regles : un solde stocke finit par
-- s'ecarter de ses mouvements, et c'est alors lui qu'on croit.
--
-- `method_last4` suit la regle deja posee pour `payment_methods` — quatre
-- chiffres pour reconnaitre son propre numero, jamais le numero.

create table if not exists payout_requests (
  id            text primary key default gen_random_uuid()::text,
  teacher_id    text not null references teachers (id) on delete cascade,

  -- En GNF, entier : la plus petite coupure en circulation est le billet de
  -- 1 000, il n'y a pas de centime a representer.
  amount        integer not null check (amount > 0),

  -- ORANGE | MTN | CASH — le canal demande, pas une reference de compte.
  method        text not null check (method in ('ORANGE', 'MTN', 'CASH')),
  method_last4  text check (method_last4 is null
                            or method_last4 ~ '^[0-9]{4}$'),

  status        text not null default 'REQUESTED'
                  check (status in ('REQUESTED', 'APPROVED', 'PAID',
                                    'REJECTED')),

  -- Ce que l'operateur ecrit quand il refuse. Affiche tel quel au
  -- professeur : un refus sans motif se relit comme une panne.
  decision_note text,

  requested_at  timestamptz not null default now(),
  settled_at    timestamptz,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists payout_requests_teacher_idx
  on payout_requests (teacher_id, requested_at desc);

-- Une seule demande en attente a la fois.
--
-- Sans cette contrainte, deux appuis sur « Demander » creent deux demandes du
-- meme montant, et l'operateur paie deux fois la meme somme. C'est l'index
-- qui le tient et non le code d'appel : le code d'appel a deja laisse passer
-- un double clic.
create unique index if not exists payout_requests_une_seule_en_cours
  on payout_requests (teacher_id)
  where status in ('REQUESTED', 'APPROVED');

-- ===========================================================================
-- 2. L'assistant : les conversations et leur cout
-- ===========================================================================
--
-- --- Ce qui part chez Google, et ce qui n'en part pas --------------------
--
-- `_lib/gemini.ts` pose la regle depuis le premier jour : aucune donnee
-- personnelle ne quitte le serveur par ce module, et c'est a l'appelant de
-- construire une invite qui ne porte pas de noms. Un assistant de devoirs la
-- met a l'epreuve — la question de l'eleve part forcement.
--
-- Ce qui reste tenu : **l'invite ne porte ni prenom, ni identifiant, ni
-- ville**. Le serveur envoie la matiere, le niveau et le texte de la
-- question. Google ne peut pas relier deux questions a la meme personne.
--
-- --- Pourquoi le cout est stocke en dollars ------------------------------
--
-- C'est la monnaie de la facture Google. Le convertir en francs a l'ecriture
-- figerait un taux de change dans une ligne qu'on ne reecrit jamais, et la
-- somme de la colonne ne vaudrait plus rien un an plus tard.

create table if not exists ai_conversations (
  id          text primary key default gen_random_uuid()::text,
  owner_id    uuid not null references profiles (id) on delete cascade,

  -- HOMEWORK : aide aux devoirs. COURSE : preparation d'un cours.
  -- GENERAL : tout le reste.
  feature     text not null default 'GENERAL'
                check (feature in ('HOMEWORK', 'COURSE', 'GENERAL')),

  -- Le premier message, tronque : c'est ce qui s'affiche dans la liste.
  -- Recalculer un titre a chaque lecture demanderait de lire le premier
  -- message de chaque fil.
  title       text,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists ai_conversations_owner_idx
  on ai_conversations (owner_id, updated_at desc);

create table if not exists ai_messages (
  id              text primary key default gen_random_uuid()::text,
  conversation_id text not null
                    references ai_conversations (id) on delete cascade,
  role            text not null check (role in ('USER', 'MODEL')),
  body            text not null check (length(body) <= 8000),
  created_at      timestamptz not null default now()
);

create index if not exists ai_messages_conversation_idx
  on ai_messages (conversation_id, created_at);

-- --- Le journal des appels -------------------------------------------------
--
-- Jamais modifie, seulement complete : c'est ce qui permet de repondre a
-- « combien l'assistant a-t-il coute ce mois-ci » sans faire confiance a un
-- compteur. Aucune politique d'ecriture, comme `point_ledger` : seules les
-- fonctions `security definer` et la cle de service y ecrivent.
create table if not exists ai_usage (
  id            text primary key default gen_random_uuid()::text,
  owner_id      uuid not null references profiles (id) on delete cascade,
  feature       text not null,
  model         text not null,
  tokens_in     integer not null default 0 check (tokens_in >= 0),
  tokens_out    integer not null default 0 check (tokens_out >= 0),

  -- numeric et non float : une somme de flottants sur dix mille lignes
  -- derive. Six decimales suffisent — un message coute 0,002 $.
  cost_usd      numeric(12, 6) not null default 0 check (cost_usd >= 0),

  duration_ms   integer,
  status        text not null default 'OK' check (status in ('OK', 'ERROR')),
  created_at    timestamptz not null default now()
);

create index if not exists ai_usage_owner_jour_idx
  on ai_usage (owner_id, created_at desc);

create index if not exists ai_usage_mois_idx
  on ai_usage (created_at desc);

-- ===========================================================================
-- 3. Les fonctions de lecture
-- ===========================================================================

/*
 * Combien de messages ce compte a-t-il envoyes aujourd'hui.
 *
 * `security definer` parce que `ai_usage` est fermee en lecture directe : le
 * client ne doit pas pouvoir lire le cout, seulement savoir ou il en est de
 * sa limite. La fonction ne rend qu'un nombre.
 *
 * La journee est celle d'Afrique/Conakry (UTC+0, sans heure d'ete) : un
 * decompte qui se remet a zero a 1 h du matin locale serait incomprehensible.
 */
create or replace function ai_messages_du_jour(qui uuid)
  returns integer
  language sql
  stable
  security definer
  set search_path = public, pg_temp
as $$
  select count(*)::integer
  from ai_usage
  where owner_id = qui
    and status = 'OK'
    and created_at >= date_trunc('day', now() at time zone 'Africa/Conakry');
$$;

/*
 * Ce que l'assistant a coute depuis le debut du mois, en dollars.
 *
 * Le garde-fou qui compte vraiment : une boucle dans un client, ou une
 * poignee de comptes qui decouvrent le jouet, et la facture part. Le serveur
 * lit cette somme avant chaque appel et s'arrete au plafond.
 */
create or replace function ai_cout_du_mois()
  returns numeric
  language sql
  stable
  security definer
  set search_path = public, pg_temp
as $$
  select coalesce(sum(cost_usd), 0)
  from ai_usage
  where created_at >= date_trunc('month',
                                 now() at time zone 'Africa/Conakry');
$$;

/*
 * Les revenus d'un professeur, calcules et non stockes.
 *
 * Trois sources, et elles n'ont pas la meme forme :
 *
 *   * les places payees sur ses seances en direct (`session_enrolments`
 *     confirmees, prix du cours, part professeur) ;
 *   * les achats de ses cours video (`course_purchases`, montant moins
 *     commission figee a l'achat) ;
 *   * les echeances reglees de ses contrats (`contract_payments` a l'etat
 *     PAID).
 *
 * --- Pourquoi 60 % sur le direct -----------------------------------------
 *
 * C'est le taux affiche au professeur au moment de publier
 * (`publish_course_page.dart`, carte « Ce que vous gagnez »). Il est ecrit
 * ici aussi, et c'est un doublon assume : la seule facon de ne pas l'ecrire
 * deux fois serait de figer la part dans `live_courses` a la publication, ce
 * qui est la bonne solution — mais elle demande une colonne et une reprise
 * des lignes existantes. Note dans la feuille de route.
 *
 * `security definer` : la fonction traverse `session_enrolments`, dont les
 * politiques sont ecrites pour la famille qui a paye, pas pour le professeur
 * qui encaisse. Sans cela elle rendrait zero — exactement le defaut de 0028,
 * ou une politique trop stricte se lisait comme une base vide.
 */
create or replace function revenus_enseignant(prof text)
  returns table (
    direct_gnf     bigint,
    videos_gnf     bigint,
    contrats_gnf   bigint,
    retire_gnf     bigint,
    en_cours_gnf   bigint,
    places         bigint,
    achats         bigint
  )
  language sql
  stable
  security definer
  set search_path = public, pg_temp
as $$
  with direct as (
    select
      coalesce(sum((lc.price * 60) / 100), 0)::bigint as montant,
      count(*)::bigint                                as places
    from session_enrolments se
    join live_sessions ls on ls.id = se.session_id
    join live_courses  lc on lc.id = ls.live_course_id
    where lc.teacher_id = prof
      and se.status = 'CONFIRMED'
  ),
  videos as (
    select
      coalesce(sum(cp.amount - cp.commission), 0)::bigint as montant,
      count(*)::bigint                                    as achats
    from course_purchases cp
    join video_courses vc on vc.id = cp.course_id
    where vc.teacher_id = prof
  ),
  contrats as (
    select coalesce(sum(pay.amount), 0)::bigint as montant
    from contract_payments pay
    join work_contracts wc on wc.id = pay.contract_id
    where wc.teacher_id = prof
      and pay.status = 'PAID'
  ),
  retraits as (
    select
      coalesce(sum(amount) filter (where status = 'PAID'), 0)::bigint
        as regle,
      coalesce(sum(amount) filter (where status in ('REQUESTED', 'APPROVED')),
               0)::bigint
        as en_cours
    from payout_requests
    where teacher_id = prof
  )
  select
    direct.montant,
    videos.montant,
    contrats.montant,
    retraits.regle,
    retraits.en_cours,
    direct.places,
    videos.achats
  from direct, videos, contrats, retraits;
$$;

-- `work_contracts.teacher_id` : verifie a l'ecriture de cette migration.
-- Si la colonne porte un autre nom, `npm run check:db` le dira — une
-- fonction qui ne compile pas leve a la creation, pas a l'appel.

-- ===========================================================================
-- 4. Les politiques
-- ===========================================================================

alter table payout_requests  enable row level security;
alter table ai_conversations enable row level security;
alter table ai_messages      enable row level security;
alter table ai_usage         enable row level security;

-- --- Les retraits ---------------------------------------------------------
--
-- Le professeur lit les siens. Il n'ecrit pas : c'est la route qui insere,
-- apres avoir verifie que le montant demande ne depasse pas ce qui est
-- disponible. Laisser le client inserer permettrait de demander un million
-- sur un solde de zero.
create policy "retraits : les siens" on payout_requests
  for select using (
    teacher_id in (select id from teachers where user_id = auth.uid())
  );

-- --- L'assistant ----------------------------------------------------------
--
-- Les conversations et les messages appartiennent a leur proprietaire, et a
-- personne d'autre. Pas de politique d'ecriture sur `ai_messages` : les deux
-- cotes d'un echange sont ecrits par la route, dans la meme transaction, et
-- un client qui pourrait inserer un message `MODEL` pourrait se faire dire
-- n'importe quoi par un faux assistant.
create policy "assistant : ses conversations" on ai_conversations
  for select using (owner_id = auth.uid());

create policy "assistant : ses messages" on ai_messages
  for select using (
    conversation_id in (
      select id from ai_conversations where owner_id = auth.uid()
    )
  );

-- `ai_usage` : aucune politique. Le cout en dollars n'a aucune raison d'etre
-- lisible par un client, et `ai_messages_du_jour` suffit a lui dire ou il en
-- est. Une table sans politique est fermee a tout le monde sauf la cle de
-- service et les fonctions `security definer`.

-- Les fonctions de lecture ne s'appellent pas depuis un navigateur : le
-- plafond global et le cout du mois sont des informations de gestion.
revoke all on function ai_cout_du_mois() from public, anon, authenticated;
revoke all on function revenus_enseignant(text) from public, anon;

-- Celle-ci, si : l'ecran de l'assistant affiche « 12 messages sur 100
-- aujourd'hui », et le faire calculer par le serveur a chaque affichage
-- couterait un aller-retour pour un nombre.
grant execute on function ai_messages_du_jour(uuid) to authenticated;
grant execute on function revenus_enseignant(text) to authenticated;
