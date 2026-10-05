-- Lecture publique de la fiche enseignant (25/09).
--
-- Le client web parle desormais directement a PostgREST avec la cle
-- anonyme : il n'y a plus de serveur intermediaire pour decider qui voit
-- quoi. RLS est donc la seule barriere, et trois regles de 0002 ferment des
-- portes que le produit ouvre.
--
-- 1. `teachers` n'est lisible que par un compte INSTITUTION. Or la recherche
--    de professeurs est publique des l'ecran d'accueil, et une famille n'est
--    pas un etablissement : sur les deux clients, on cherche avant d'ouvrir
--    un compte.
-- 2. `profiles` n'est lisible que par soi-meme. La vue
--    `teacher_public_profiles` la joint en `security_invoker`, donc elle ne
--    rend rien — y compris a un etablissement, pour qui elle a ete ecrite.
-- 3. Les matieres, niveaux et certifications d'un enseignant suivent la meme
--    regle que `teachers` : sans eux, une fiche s'affiche sans ce qui la
--    rend utile.
--
-- Ce que cette migration n'ouvre PAS, et ne doit jamais ouvrir : le
-- telephone, le courriel, les diplomes et les documents. Ils restent fermes
-- par 0002, et la vue ci-dessous ne les expose pas. Les coordonnees ne
-- circulent qu'apres mise en relation (§30).

-- --- La fiche elle-meme ---------------------------------------------------

-- Un enseignant non suspendu est consultable par tout le monde, connecte ou
-- non. C'est ce que montre deja l'application mobile sans compte.
create policy "enseignant : fiche publique" on teachers
  for select using (
    exists (
      select 1 from profiles p
      where p.id = teachers.user_id and not p.suspended
    )
  );

-- --- L'identite professionnelle qui l'accompagne --------------------------
--
-- Le prenom, le nom et la photo d'un enseignant sont ce qu'il publie de
-- lui-meme : sans eux la recherche rend des fiches anonymes. Le telephone et
-- le courriel restent couverts par « profil : lecture de soi ».
--
-- Postgres n'a pas de politique par colonne : la restriction passe donc par
-- une vue, et l'acces direct a `profiles` n'est pas elargi.
create view public_teacher_identities as
  select
    p.id,
    p.first_name,
    p.last_name,
    p.photo_path,
    p.city
  from profiles p
  where p.role = 'TEACHER' and not p.suspended;

-- `security_definer` ici, a l'inverse de la vue de 0002 : c'est la vue qui
-- garantit les colonnes rendues, et elle ne rend que celles-ci. En
-- `invoker`, elle se heurterait a « lecture de soi » et rendrait zero ligne
-- — precisement le defaut qu'on corrige.
alter view public_teacher_identities set (security_invoker = false);

grant select on public_teacher_identities to anon, authenticated;

-- --- Ce qui qualifie la fiche ---------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'teacher_subjects', 'teacher_levels', 'teacher_certifications'
  ] loop
    execute format($f$
      create policy "%1$s : lecture publique" on %1$I
        for select using (true);
    $f$, t);
  end loop;
end $$;

-- Les experiences restent fermees au public : elles nomment des
-- etablissements et des dates, ce qui compose un parcours professionnel
-- identifiant. Un etablissement les voit deja (politique de 0002), et c'est
-- lui qui recrute.

-- --- Favoris (lacune signalee par check-schema.mjs) -----------------------
--
-- La table existe cote application depuis la v19 et n'avait aucun equivalent
-- serveur : une mise en favori partait dans la file d'envoi et etait rejetee
-- en silence.

create table if not exists favourites (
  id          text primary key default gen_random_uuid()::text,
  owner_id    uuid not null references profiles (id) on delete cascade,
  teacher_id  text not null references teachers (id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (owner_id, teacher_id)
);

create index if not exists favourites_teacher_idx on favourites (teacher_id);

alter table favourites enable row level security;

-- Chacun gere les siens. Le compte du professeur, lui, a besoin du nombre
-- de mises en favori sans connaitre qui : ce comptage passera par une
-- fonction dediee, pas par une lecture de la table.
create policy "favoris : les siens" on favourites
  for all using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
