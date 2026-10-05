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
