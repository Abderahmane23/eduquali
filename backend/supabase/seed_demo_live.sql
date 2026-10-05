-- Un cours en direct de demonstration, et son groupe de discussion (04/10).
--
-- --- Pourquoi ce fichier existe -------------------------------------------
--
-- Rien ne cree de cours en direct : il n'y a de parcours de creation ni sur le
-- telephone ni sur le site (voir ROADMAP.md). Sans cours, la grille « En
-- direct » est vide, l'ecran du professeur dit d'attendre, et les groupes de
-- discussion n'ont rien a montrer. Trois fonctions construites, et aucune
-- verifiable.
--
-- Ce script pose de quoi les voir toutes les trois.
--
-- --- A appliquer APRES --------------------------------------------------
--
--   1. les migrations jusqu'a `0027_chat_groups.sql`
--   2. `node scripts/seed-demo-accounts.mjs`, qui cree les comptes de
--      demonstration — une fiche professeur reference un compte `auth.users`,
--      que seule l'authentification peut creer.
--
-- Rejouable sans dommage : chaque insertion est conditionnelle.

do $$
declare
  prof       text;
  matiere    text;
  niveau     text;
  famille    text;
  seance     text;
begin
  -- Le premier professeur de demonstration qui a une fiche.
  select t.id into prof
    from teachers t
    join profiles p on p.id = t.user_id
   where p.role = 'TEACHER'
   order by t.created_at
   limit 1;

  if prof is null then
    raise notice 'Aucun professeur : lancez d''abord seed-demo-accounts.mjs.';
    return;
  end if;

  -- Mathematiques si elle existe, sinon la premiere matiere du referentiel.
  select id into matiere from subjects
   where code = 'MATH' or name ilike 'math%' order by code limit 1;
  if matiere is null then
    select id into matiere from subjects order by sort_order limit 1;
  end if;

  -- Une vraie classe, pas un en-tete de cycle : un cours s'adresse a une
  -- classe, et le filtre par palier s'appuie dessus.
  -- `l.grouping` qualifie : `grouping` est aussi une fonction d'agregation en
  -- SQL, et une reference nue se lit mal.
  select l.id into niveau from levels l
   where l.grouping = false
   order by l.code limit 1;

  if matiere is null or niveau is null then
    raise notice 'Referentiel absent : appliquez seed_curriculum.sql.';
    return;
  end if;

  -- --- Le cours ------------------------------------------------------------
  insert into live_courses
      (id, teacher_id, subject_id, level_id, title, description, price, seats,
       slot_ids, status)
  values
      ('lc_demo', prof, matiere, niveau,
       'Maths — révisions du soir',
       'Deux séances par semaine, questions en direct. Cours de '
       || 'démonstration.',
       20000, 15, array['WD_18'], 'PUBLISHED')
  on conflict (id) do nothing;

  -- --- Deux seances a venir ------------------------------------------------
  --
  -- La premiere dans une heure : assez proche pour que le bouton « Démarrer »
  -- du professeur s'allume (la salle ouvre quinze minutes avant), assez loin
  -- pour qu'on ait le temps de regarder l'ecran avant.
  insert into live_sessions (id, live_course_id, slot_id, starts_at, status)
  values
      ('ls_demo_1', 'lc_demo', 'WD_18', now() + interval '1 hour', 'PLANNED'),
      ('ls_demo_2', 'lc_demo', 'WD_18', now() + interval '8 days', 'PLANNED')
  on conflict (id) do nothing;

  -- --- Une place payee ----------------------------------------------------
  --
  -- C'est elle qui fait entrer la famille dans le groupe : l'appartenance se
  -- deduit d'une inscription `CONFIRMED`, rien d'autre.
  select pa.id into famille
    from parents pa
    join profiles p on p.id = pa.user_id
   where p.role in ('PARENT', 'STUDENT')
   order by pa.created_at
   limit 1;

  if famille is not null then
    insert into session_enrolments (id, session_id, parent_id, status)
    values ('se_demo_1', 'ls_demo_1', famille, 'CONFIRMED')
    on conflict (id) do nothing;
  else
    raise notice
      'Aucune famille : le groupe existera, avec le professeur seul dedans.';
  end if;

  -- --- Le groupe -----------------------------------------------------------
  --
  -- En service, le serveur l'ouvre au premier paiement confirme
  -- (`assurerGroupe`). Ici on l'ouvre a la main, puisque aucun paiement ne
  -- passe par le webhook sur une base de demonstration.
  insert into chat_groups (id, kind, source_id, name)
  values ('cg_demo', 'COURSE', 'lc_demo', 'Maths — révisions du soir')
  on conflict (kind, source_id) do nothing;

  select id into seance from chat_groups where source_id = 'lc_demo';

  -- Deux messages, pour que l'ecran ne s'ouvre pas vide : le professeur
  -- d'abord, pour qu'on voie son nom en ambre et sa puce.
  insert into chat_messages (id, group_id, author_id, body)
  select 'cm_demo_1', seance, t.user_id,
         'Bonsoir à tous. Ce soir : les fonctions affines, exercices 1 à 4.'
    from teachers t where t.id = prof
  on conflict (id) do nothing;

  if famille is not null then
    insert into chat_messages (id, group_id, author_id, body)
    select 'cm_demo_2', seance, pa.user_id,
           'Bonsoir, j''ai une question sur l''exercice 3.'
      from parents pa where pa.id = famille
    on conflict (id) do nothing;
  end if;

  raise notice 'Cours de demonstration pose : lc_demo, 2 seances, 1 groupe.';
end
$$;
