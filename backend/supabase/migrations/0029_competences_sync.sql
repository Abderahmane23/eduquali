-- Les competences d'un professeur remontent enfin (06/10).
--
-- --- Le defaut -------------------------------------------------------------
--
-- `teacher_subjects` et `teacher_levels` sont des **ensembles**. Le geste du
-- professeur est « voila mes matieres » : cela veut dire en ajouter, et aussi
-- retirer celles qu'il a decochees.
--
-- La synchronisation generique (`planWrite`) ecrit **une ligne** a partir
-- d'une charge utile dont les cles sont des noms de colonnes. Le client, lui,
-- poussait `{subjectIds: [...]}` sous l'entite `teacher_subjects`, dont les
-- colonnes autorisees sont `teacher_id` et `subject_id`. Aucune cle ne
-- correspondait : la charge etait videe, puis refusee avec « Aucune colonne
-- reconnue ». Et son `entityId` etait l'identifiant du **professeur**, pas
-- celui d'une ligne — l'upsert aurait de toute facon ecrit n'importe quoi.
--
-- Les matieres d'un professeur restaient donc sur son telephone. Comme
-- `offersInSubjects` rend une liste vide sans matiere declaree, son onglet
-- d'offres etait vide cote serveur, avec un message lui demandant de saisir ce
-- qu'il avait deja saisi.
--
-- --- Pourquoi une fonction, et non deux instructions ----------------------
--
-- Remplacer, c'est supprimer puis reinserer. Fait en deux appels, il existe un
-- instant ou le professeur n'a **aucune** matiere : visible par les autres, et
-- introuvable dans toute recherche. Si le reseau tombe entre les deux, cet
-- instant devient definitif.
--
-- Les deux vivent donc dans une seule instruction, et c'est Postgres qui
-- garantit le tout ou rien.

/*
 * Remplace les matieres et niveaux declares d'un professeur.
 *
 * `declaration` est un tableau JSON :
 *
 *   [{"subject_id": "sub_math", "level_ids": ["lvl_12", "lvl_t"]}, ...]
 *
 * Cette forme-la et pas une liste plate de matieres : `teacher_levels` est
 * clee par (professeur, matiere, niveau), donc les niveaux se declarent **par
 * matiere**. Un professeur enseigne les maths en Terminale et l'anglais en
 * 6eme ; une liste plate ne sait pas le dire.
 *
 * `security definer` : la fonction ecrit dans deux tables dont les politiques
 * n'autorisent pas un client a supprimer les lignes d'un autre. Elle verifie
 * donc elle-meme que le professeur est bien celui du jeton — c'est l'appelant
 * (`/teacher/competences`) qui le resout, et il n'accepte que `auth.uid()`.
 */
create or replace function remplacer_competences(
  prof text,
  declaration jsonb
) returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  matieres text[];
begin
  if prof is null then
    raise exception 'professeur absent';
  end if;

  select coalesce(array_agg(d->>'subject_id'), '{}')
    into matieres
    from jsonb_array_elements(coalesce(declaration, '[]'::jsonb)) as d;

  -- Les niveaux d'abord : ils referencent la matiere, et une matiere retiree
  -- doit emporter ses niveaux.
  delete from teacher_levels where teacher_id = prof;
  delete from teacher_subjects
   where teacher_id = prof
     and subject_id <> all (matieres);

  insert into teacher_subjects (teacher_id, subject_id)
  select prof, d->>'subject_id'
    from jsonb_array_elements(coalesce(declaration, '[]'::jsonb)) as d
  on conflict (teacher_id, subject_id) do nothing;

  insert into teacher_levels (teacher_id, subject_id, level_id)
  select prof, d->>'subject_id', n
    from jsonb_array_elements(coalesce(declaration, '[]'::jsonb)) as d,
         jsonb_array_elements_text(coalesce(d->'level_ids', '[]'::jsonb)) as n
  on conflict (teacher_id, subject_id, level_id) do nothing;
end;
$$;

comment on function remplacer_competences(text, jsonb) is
  'Remplace l''ensemble des matieres et niveaux d''un professeur en une '
  'instruction. En deux appels, il existerait un instant sans aucune matiere '
  '— et une coupure reseau le rendrait definitif.';

-- La cle publique n'appelle pas cette fonction : elle passe par
-- `/teacher/competences`, qui resout le professeur depuis le jeton. Lui ouvrir
-- l'execution laisserait un client remplacer les competences d'un autre, le
-- `prof` etant un simple argument.
revoke all on function remplacer_competences(text, jsonb) from public;
revoke all on function remplacer_competences(text, jsonb) from anon;
revoke all on function remplacer_competences(text, jsonb) from authenticated;
