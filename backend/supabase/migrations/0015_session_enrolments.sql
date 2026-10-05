-- S'inscrire à une séance en direct (02/10).
--
-- --- Le problème des quinze places ---------------------------------------
--
-- Quinze places, et deux familles qui réservent la dernière au même instant.
-- Compter les inscriptions avant d'insérer ne suffit pas : les deux comptes
-- lisent 14, les deux insèrent, la séance en a 16. Le défaut est rare, invisible
-- en test, et il se manifeste le jour où un cours se remplit — c'est-à-dire le
-- jour où ça compte.
--
-- La parade est un compteur sur la séance et une mise à jour **conditionnelle**
-- (`where seats_taken < seats`). Postgres verrouille la ligne le temps de
-- l'écriture : la seconde tentative ne met à jour aucune ligne et le sait.
-- C'est la même règle que pour un solde — jamais lire-modifier-écrire.

alter table live_sessions
  add column if not exists seats_taken integer not null default 0
    check (seats_taken >= 0);

-- --- L'inscription --------------------------------------------------------

create table if not exists session_enrolments (
  id          text primary key default gen_random_uuid()::text,
  session_id  text not null references live_sessions (id) on delete cascade,

  -- Le compte qui paie : une famille, ou un étudiant majeur.
  parent_id   text not null references parents (id) on delete cascade,

  -- L'élève concerné. Nul quand c'est l'étudiant majeur lui-même : il partage
  -- l'espace de la famille sans être l'enfant de personne.
  child_id    text references children (id) on delete cascade,

  status      text not null default 'PENDING'
                check (status in ('PENDING', 'CONFIRMED', 'CANCELLED')),

  -- Une place retenue sans être payée ne doit pas l'être pour toujours. Le
  -- cron qui génère les séances libère ce qui a expiré.
  holds_until timestamptz,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Deux index partiels, et non une seule contrainte : dans Postgres, deux NULL
-- ne sont pas égaux, donc `unique (session_id, child_id)` laisserait un
-- étudiant majeur s'inscrire autant de fois qu'il le veut.
create unique index if not exists session_enrolments_child_idx
  on session_enrolments (session_id, child_id)
  where child_id is not null;

create unique index if not exists session_enrolments_self_idx
  on session_enrolments (session_id, parent_id)
  where child_id is null;

create index if not exists session_enrolments_session_idx
  on session_enrolments (session_id, status);
create index if not exists session_enrolments_parent_idx
  on session_enrolments (parent_id, created_at desc);

-- --- Prendre et rendre une place ------------------------------------------

/*
 * Prend une place, ou rend faux.
 *
 * La mise à jour conditionnelle est tout l'intérêt : `seats_taken < seats`
 * est évalué sous le verrou de ligne, donc deux appels simultanés ne peuvent
 * pas réussir tous les deux. Un `select` suivi d'un `update` le permettrait.
 */
create or replace function claim_session_seat(session text)
  returns boolean
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  touchees integer;
begin
  update live_sessions s
     set seats_taken = s.seats_taken + 1,
         updated_at = now()
   from live_courses c
  where s.id = session
    and c.id = s.live_course_id
    and s.status = 'PLANNED'
    and s.seats_taken < c.seats;

  get diagnostics touchees = row_count;
  return touchees > 0;
end;
$$;

/*
 * Rend une place.
 *
 * `greatest(…, 0)` plutôt qu'une soustraction nue : un double appel — reprise
 * manuelle, webhook rejoué — ne doit pas faire passer le compteur sous zéro et
 * offrir une place de plus que la salle n'en a.
 */
create or replace function release_session_seat(session text)
  returns void
  language sql
  security definer
  set search_path = public
as $$
  update live_sessions
     set seats_taken = greatest(seats_taken - 1, 0),
         updated_at = now()
   where id = session;
$$;

-- --- Un seul encaissement pour deux objets --------------------------------
--
-- `course_purchases` portait un `course_id` obligatoire vers `video_courses`.
-- Une séance en direct n'est pas un cours vidéo : l'insertion échouait.
--
-- Trois façons de faire, et une seule qui tient :
--
--   * une seconde table de paiements — il faudrait alors deux webhooks, deux
--     chemins d'idempotence, deux endroits où le prix pourrait être faux ;
--   * mettre la séance dans `video_courses` — mentir sur ce qu'est un cours ;
--   * **un achat qui pointe sur l'un ou l'autre**, ce qui est fait ici.
--
-- Le webhook Djomy retrouve la ligne par son identifiant, qui est la référence
-- marchande : il ne change pas. `has_bought_course()` filtre sur `course_id`,
-- et un NULL n'égale jamais rien : elle ne change pas non plus.
--
-- La référence ne va **que dans ce sens**. Si `session_enrolments` portait un
-- `purchase_id`, les deux tables se référenceraient mutuellement et aucune ne
-- pourrait être créée en premier.

alter table course_purchases
  alter column course_id drop not null;

alter table course_purchases
  add column if not exists enrolment_id text
    references session_enrolments (id) on delete cascade;

create unique index if not exists course_purchases_enrolment_idx
  on course_purchases (enrolment_id)
  where enrolment_id is not null;

-- Exactement un des deux, jamais zéro, jamais les deux. Sans cette contrainte,
-- un achat sans objet serait encaissé sans rien donner en échange.
alter table course_purchases
  drop constraint if exists course_purchases_target_check;
alter table course_purchases
  add constraint course_purchases_target_check
  check (
    (course_id is not null and enrolment_id is null)
    or (course_id is null and enrolment_id is not null)
  );

-- --- Qui voit quoi --------------------------------------------------------

alter table session_enrolments enable row level security;

-- Une famille voit ses inscriptions. Le professeur voit celles de ses séances
-- — il doit savoir qui vient, c'est sa classe.
create policy "inscription : la sienne, ou sa classe" on session_enrolments
  for select using (
    parent_id = my_parent_id()
    or exists (
      select 1
        from live_sessions s
        join live_courses c on c.id = s.live_course_id
       where s.id = session_id and c.teacher_id = my_teacher_id()
    )
  );

-- **Aucune politique d'écriture.** S'inscrire passe par le serveur, qui prend
-- la place et lance le paiement sous la clé de service. Un client qui pourrait
-- insérer contournerait le compteur de places et le prix.

comment on constraint course_purchases_target_check on course_purchases is
  'Un achat porte soit un cours video, soit une inscription a une seance. '
  'Jamais les deux, jamais aucun.';
comment on column session_enrolments.holds_until is
  'Une place retenue sans paiement expire. Le cron de generation libere.';
comment on function claim_session_seat(text) is
  'Prend une place de maniere atomique. Faux si la salle est pleine.';
