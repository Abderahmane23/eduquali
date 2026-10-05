-- Contenu d'un cours video : chapitres, elements, commentaires (02/10).
--
-- Les trois tables existent cote application depuis la v23 du schema mobile.
-- Sans equivalent serveur, un cours construit sur un telephone partait dans
-- la file d'envoi et etait rejete en silence : le professeur voyait son
-- sommaire, l'eleve recevait un cours vide.
--
-- Le point delicat de cette migration n'est pas la forme des tables, c'est
-- **qui lit `local_path` et `remote_url`**. Ces deux colonnes designent le
-- fichier video. Un cours se vend ; les rendre publiques avec le reste du
-- sommaire donnerait le cours entier a qui sait interroger PostgREST avec la
-- cle anonyme, et la cle anonyme est dans le code du site. Le sommaire est la
-- vitrine, le fichier est la marchandise.

-- --- Les chapitres --------------------------------------------------------

create table if not exists course_chapters (
  id          text primary key,
  course_id   text not null references video_courses (id) on delete cascade,
  title       text not null,
  -- Ce que le chapitre traite, affiche sous la video.
  description text,
  -- Rang d'affichage, explicite et non deduit de la date de creation : un
  -- professeur reordonne ses chapitres, et l'ordre de saisie n'est pas
  -- l'ordre d'apprentissage.
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists course_chapters_course_idx
  on course_chapters (course_id, position);

-- --- Les elements d'un chapitre -------------------------------------------

create table if not exists course_items (
  id               text primary key,
  chapter_id       text not null
                     references course_chapters (id) on delete cascade,
  kind             text not null default 'VIDEO'
                     check (kind in ('VIDEO', 'DOCUMENT', 'LINK')),
  title            text not null,
  -- Le chemin sur l'appareil du professeur, le temps que le fichier monte.
  local_path       text,
  -- L'adresse du fichier une fois en ligne, ou l'URL elle-meme pour un lien.
  remote_url       text,
  -- Nulle quand on ne la connait pas : afficher « 0 min » serait faux.
  duration_seconds integer check (duration_seconds is null
                                  or duration_seconds >= 0),
  position         integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists course_items_chapter_idx
  on course_items (chapter_id, position);

-- --- Les commentaires sous une video --------------------------------------
--
-- Rattaches a l'element et non au cours : une question porte sur la video
-- qu'on vient de regarder, et la rattacher au cours entier la rendrait
-- introuvable des que le cours compte dix videos.

create table if not exists course_comments (
  id         text primary key,
  item_id    text not null references course_items (id) on delete cascade,
  author_id  uuid not null references profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  -- Le commentaire auquel celui-ci repond. Nul au premier niveau.
  parent_id  text references course_comments (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists course_comments_item_idx
  on course_comments (item_id, created_at);

-- --- Qui voit quoi --------------------------------------------------------

alter table course_chapters enable row level security;
alter table course_items    enable row level security;
alter table course_comments enable row level security;

-- Vrai quand le compte courant a paye ce cours.
create or replace function has_bought_course(course text)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
as $$
  select exists (
    select 1 from course_purchases p
    where p.course_id = course and p.parent_id = my_parent_id()
  );
$$;

-- Le cours auquel appartient un element, en remontant son chapitre.
create or replace function course_of_item(item text)
  returns text
  language sql
  stable
  security definer
  set search_path = public
as $$
  select ch.course_id
  from course_items ci
  join course_chapters ch on ch.id = ci.chapter_id
  where ci.id = item;
$$;

-- Le programme est la vitrine : on doit pouvoir lire les titres des
-- chapitres avant de payer, sinon on achete sans savoir quoi.
create policy "chapitre : le programme est public" on course_chapters
  for select using (
    exists (
      select 1 from video_courses v
      where v.id = course_id
        and (v.status = 'PUBLISHED' or v.teacher_id = my_teacher_id())
    )
  );

create policy "chapitre : son auteur le gere" on course_chapters
  for all using (
    exists (
      select 1 from video_courses v
      where v.id = course_id and v.teacher_id = my_teacher_id()
    )
  )
  with check (
    exists (
      select 1 from video_courses v
      where v.id = course_id and v.teacher_id = my_teacher_id()
    )
  );

-- La table des elements, elle, reste fermee : elle porte le chemin du
-- fichier. Seuls l'auteur et ceux qui ont paye y accedent.
create policy "element : l auteur et les acheteurs" on course_items
  for select using (
    exists (
      select 1 from course_chapters ch
      join video_courses v on v.id = ch.course_id
      where ch.id = chapter_id
        and (v.teacher_id = my_teacher_id() or has_bought_course(v.id))
    )
  );

create policy "element : son auteur le gere" on course_items
  for all using (
    exists (
      select 1 from course_chapters ch
      join video_courses v on v.id = ch.course_id
      where ch.id = chapter_id and v.teacher_id = my_teacher_id()
    )
  )
  with check (
    exists (
      select 1 from course_chapters ch
      join video_courses v on v.id = ch.course_id
      where ch.id = chapter_id and v.teacher_id = my_teacher_id()
    )
  );

-- Ce que la vitrine montre d'un element : son titre et sa duree, jamais son
-- fichier. Postgres n'a pas de politique par colonne — la restriction passe
-- donc par une vue, comme pour l'identite publique d'un enseignant (0009).
create or replace view course_item_titles as
  select
    ci.id,
    ci.chapter_id,
    ci.kind,
    ci.title,
    ci.duration_seconds,
    ci.position
  from course_items ci
  join course_chapters ch on ch.id = ci.chapter_id
  join video_courses v    on v.id = ch.course_id
  where v.status = 'PUBLISHED';

-- `security_definer` ici, comme pour `public_teacher_identities` : c'est la
-- vue qui garantit les colonnes rendues, et elle ne rend que celles-ci. En
-- `invoker`, elle se heurterait a la politique ci-dessus et rendrait zero
-- ligne a qui n'a pas achete — c'est-a-dire a tous les acheteurs
-- potentiels.
alter view course_item_titles set (security_invoker = false);

grant select on course_item_titles to anon, authenticated;

-- Les commentaires suivent la video : les lire suppose d'y avoir acces.
-- Ouvrir leur lecture a tout le monde laisserait deviner le contenu du cours
-- par les questions qu'il souleve, et surtout exposerait des eleves nommes.
create policy "commentaire : ceux qui suivent le cours" on course_comments
  for select using (
    exists (
      select 1 from video_courses v
      where v.id = course_of_item(item_id)
        and (v.teacher_id = my_teacher_id() or has_bought_course(v.id))
    )
  );

create policy "commentaire : on ecrit sous son nom" on course_comments
  for insert with check (
    author_id = auth.uid()
    and exists (
      select 1 from video_courses v
      where v.id = course_of_item(item_id)
        and (v.teacher_id = my_teacher_id() or has_bought_course(v.id))
    )
  );

-- On efface le sien. Le professeur efface aussi ce qui est ecrit sous son
-- cours : c'est lui qui en repond, et une insulte sous sa video lui est
-- imputee.
create policy "commentaire : le sien, ou chez soi" on course_comments
  for delete using (
    author_id = auth.uid()
    or exists (
      select 1 from video_courses v
      where v.id = course_of_item(item_id) and v.teacher_id = my_teacher_id()
    )
  );

-- Modifier un commentaire n'est pas prevu par le produit : une reponse deja
-- lue ne doit pas changer sous les yeux de qui l'a lue. Pas de politique
-- `update`, donc aucune mise a jour possible — l'absence est la regle, pas un
-- oubli.
