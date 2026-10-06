-- La fiche publique d'un professeur etait invisible a tout le monde (06/10).
--
-- --- Le symptome ----------------------------------------------------------
--
-- Le site deploye affichait « aucun professeur » partout. Mesure sur la base
-- en service :
--
--   teachers                    cle de service : 30   cle publique : 0
--   profiles                    cle de service : 30   cle publique : 0
--   public_teacher_identities   cle de service : 30   cle publique : 30
--   profils suspendus : 0
--
-- Trente professeurs, aucun suspendu, et la vue des identites les rend tous
-- les trente. Seule la table `teachers` etait vide pour le navigateur.
--
-- --- La cause -------------------------------------------------------------
--
-- La politique posee en 0009 verifiait le compte en ligne :
--
--   create policy "enseignant : fiche publique" on teachers
--     for select using (
--       exists (select 1 from profiles p
--                where p.id = teachers.user_id and not p.suspended)
--     );
--
-- Une sous-requete dans une politique subit **les politiques de la table
-- qu'elle lit**. `profiles` est ferme a la cle publique — a dessein, il porte
-- les numeros de telephone — donc ce `exists` ne trouvait jamais rien et
-- rendait faux pour chaque ligne. La politique se fermait sur elle-meme.
--
-- Rien ne l'avait signale : `check:supabase` verifie qu'une table existe et
-- qu'une ecriture est refusee, pas qu'une lecture autorisee aboutit. Une
-- politique trop stricte ne leve rien — elle rend zero ligne, ce qui se lit
-- comme une base vide.
--
-- --- La correction --------------------------------------------------------
--
-- Le depot avait deja la bonne forme a cote : `current_role_is` (0002) est une
-- fonction `security definer`, justement pour lire `profiles` sans heriter de
-- ses politiques. La politique de 0009 avait inline la sous-requete au lieu de
-- passer par une fonction. On ajoute donc l'equivalent.

/*
 * Ce compte existe-t-il et n'est-il pas suspendu ?
 *
 * `security definer` : la fonction lit `profiles` avec les droits de son
 * proprietaire, donc sans etre filtree par les politiques de `profiles`. Elle
 * ne rend qu'un booleen — rien de ce qu'elle a lu ne sort.
 *
 * `stable` plutot que `volatile` : Postgres peut alors l'evaluer une fois par
 * ligne au lieu d'une fois par reference, ce qui compte sur une liste de
 * trente fiches.
 */
create or replace function compte_actif(qui uuid) returns boolean
  language sql
  stable
  security definer
  set search_path = public, pg_temp
as $$
  select exists (
    select 1 from profiles p where p.id = qui and not p.suspended
  );
$$;

comment on function compte_actif(uuid) is
  'Lit profiles sans heriter de ses politiques. Une politique qui fait '
  '« exists (select ... from profiles) » en ligne se ferme sur elle-meme : '
  'profiles est clos a la cle publique, donc le test ne trouve jamais rien.';

-- La politique, reecrite sur la fonction. Le comportement voulu est inchange :
-- un professeur dont le compte est suspendu reste invisible.
drop policy if exists "enseignant : fiche publique" on teachers;

create policy "enseignant : fiche publique" on teachers
  for select using (compte_actif(user_id));
