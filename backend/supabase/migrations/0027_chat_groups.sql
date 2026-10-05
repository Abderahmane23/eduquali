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
