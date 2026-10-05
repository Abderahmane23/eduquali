-- Controle d'acces par role (§51).
--
-- Le controle vit dans la base, pas dans l'API : une requete directe depuis un
-- client, une cle publique fuitee ou un bug de routage ne doivent jamais
-- exposer les donnees d'autrui.
--
-- Regle structurante (§23, §30) : les coordonnees d'un enseignant restent
-- masquees tant que le recrutement n'est pas conclu. Le profil public est donc
-- une vue distincte, sans telephone ni email.

alter table profiles                enable row level security;
alter table teachers                enable row level security;
alter table teacher_subjects        enable row level security;
alter table teacher_levels          enable row level security;
alter table teacher_experiences     enable row level security;
alter table teacher_diplomas        enable row level security;
alter table teacher_documents       enable row level security;
alter table teacher_certifications  enable row level security;
alter table test_sessions           enable row level security;
alter table test_answers            enable row level security;
alter table institutions            enable row level security;
alter table jobs                    enable row level security;
alter table applications            enable row level security;
alter table parents                 enable row level security;
alter table children                enable row level security;
alter table tutoring_services       enable row level security;
alter table tutoring_requests       enable row level security;
alter table sync_events             enable row level security;

-- Le referentiel est public en lecture ; il n'est modifiable qu'en
-- back-office, via la cle de service qui contourne RLS.
alter table subjects       enable row level security;
alter table levels         enable row level security;
alter table tests          enable row level security;
alter table test_questions enable row level security;

create policy "referentiel lisible" on subjects for select using (true);
create policy "niveaux lisibles"    on levels   for select using (true);
create policy "tests lisibles"      on tests    for select using (true);

-- Les questions ne sont jamais lues directement par un client : l'API les
-- sert via la vue publique, sans la bonne reponse.
create policy "questions fermees" on test_questions for select using (false);

-- --- Helpers ---------------------------------------------------------------

create or replace function current_role_is(target text) returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role = target and not suspended
  );
$$ language sql stable security definer;

create or replace function my_teacher_id() returns text as $$
  select id from teachers where user_id = auth.uid();
$$ language sql stable security definer;

create or replace function my_institution_id() returns text as $$
  select id from institutions where owner_id = auth.uid();
$$ language sql stable security definer;

create or replace function my_parent_id() returns text as $$
  select id from parents where user_id = auth.uid();
$$ language sql stable security definer;

-- --- Profil ----------------------------------------------------------------

create policy "profil : lecture de soi" on profiles
  for select using (id = auth.uid());

create policy "profil : mise a jour de soi" on profiles
  for update using (id = auth.uid());

create policy "profil : creation de soi" on profiles
  for insert with check (id = auth.uid());

-- --- Enseignant ------------------------------------------------------------

-- Un enseignant gere sa fiche ; un etablissement consulte les fiches, mais
-- ne voit jamais la table `profiles` qui porte les coordonnees.
create policy "enseignant : gestion de sa fiche" on teachers
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "enseignant : consultable par un etablissement" on teachers
  for select using (current_role_is('INSTITUTION'));

do $$
declare t text;
begin
  foreach t in array array[
    'teacher_subjects', 'teacher_levels', 'teacher_experiences',
    'teacher_certifications'
  ] loop
    execute format($f$
      create policy "%1$s : gestion par l'enseignant" on %1$I
        for all using (teacher_id = my_teacher_id())
        with check (teacher_id = my_teacher_id());
      create policy "%1$s : lecture par un etablissement" on %1$I
        for select using (current_role_is('INSTITUTION'));
    $f$, t);
  end loop;
end $$;

-- Diplomes et documents : jamais visibles par un etablissement. Seul le
-- statut de verification transite, porte par la fiche enseignant (§14).
create policy "diplomes : prives" on teacher_diplomas
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "documents : prives" on teacher_documents
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

-- --- Sessions de test ------------------------------------------------------

create policy "sessions : les siennes" on test_sessions
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "reponses : les siennes" on test_answers
  for all using (
    session_id in (select id from test_sessions where teacher_id = my_teacher_id())
  ) with check (
    session_id in (select id from test_sessions where teacher_id = my_teacher_id())
  );

-- --- Etablissement ---------------------------------------------------------

create policy "etablissement : lecture publique" on institutions
  for select using (true);

create policy "etablissement : gestion par son responsable" on institutions
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Une offre publiee est visible de tous ; une offre privee (§29) ou un
-- brouillon ne l'est que de l'etablissement qui l'a creee.
create policy "offres : publiees visibles" on jobs
  for select using (
    (status = 'PUBLISHED' and visibility = 'PUBLIC')
    or institution_id = my_institution_id()
  );

create policy "offres : gestion par l'etablissement" on jobs
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

-- --- Candidatures ----------------------------------------------------------

create policy "candidatures : les siennes" on applications
  for select using (
    teacher_id = my_teacher_id()
    or job_id in (select id from jobs where institution_id = my_institution_id())
  );

create policy "candidatures : depot par l'enseignant" on applications
  for insert with check (teacher_id = my_teacher_id());

-- L'etablissement fait avancer le statut ; l'enseignant ne le modifie pas.
create policy "candidatures : suivi par l'etablissement" on applications
  for update using (
    job_id in (select id from jobs where institution_id = my_institution_id())
  );

-- --- Module parent ---------------------------------------------------------

create policy "parent : gestion de sa fiche" on parents
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "enfants : geres par le parent" on children
  for all using (parent_id = my_parent_id())
  with check (parent_id = my_parent_id());

-- Une offre de cours active est publique : c'est ce qu'un parent vient
-- chercher. L'enseignant reste seul a pouvoir la modifier.
create policy "cours : offres actives visibles" on tutoring_services
  for select using (active or teacher_id = my_teacher_id());

create policy "cours : gestion par l'enseignant" on tutoring_services
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "demandes : parent et enseignant concernes" on tutoring_requests
  for select using (
    parent_id = my_parent_id()
    or service_id in (select id from tutoring_services where teacher_id = my_teacher_id())
  );

create policy "demandes : envoi par le parent" on tutoring_requests
  for insert with check (parent_id = my_parent_id());

create policy "demandes : reponse de l'enseignant" on tutoring_requests
  for update using (
    service_id in (select id from tutoring_services where teacher_id = my_teacher_id())
  );

-- --- Synchronisation -------------------------------------------------------

create policy "sync : ses propres evenements" on sync_events
  for select using (owner_id is null or owner_id = auth.uid());

-- --- Profil public d'un enseignant (§15, §23) ------------------------------

-- Vue servie aux etablissements : identite professionnelle et preuves
-- verifiees, sans aucune coordonnee personnelle. Le telephone n'apparait
-- qu'apres signature du contrat, et il transite alors par l'API.
create view teacher_public_profiles as
  select
    t.id,
    p.first_name,
    p.last_name,
    p.photo_path,
    t.headline,
    t.bio,
    t.city,
    t.years_experience,
    t.availability,
    t.identity_status,
    t.diploma_status,
    t.boosted_until
  from teachers t
  join profiles p on p.id = t.user_id
  where not p.suspended;

-- La vue s'execute avec les droits de l'appelant : les politiques de
-- `teachers` et `profiles` continuent donc de s'appliquer.
alter view teacher_public_profiles set (security_invoker = true);
