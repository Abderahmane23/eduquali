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
