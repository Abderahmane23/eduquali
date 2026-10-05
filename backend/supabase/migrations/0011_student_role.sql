-- Le role ETUDIANT (02/10).
--
-- `intro.json` propose quatre profils depuis le 24/09 et
-- `student_onboarding.json` est copie dans les deux clients. La contrainte de
-- `profiles.role`, elle, n'en acceptait que trois : une inscription
-- « etudiant » partait, Supabase creait le compte d'authentification, puis
-- l'insertion du profil echouait sur
-- `profiles_role_check`. Le compte existait sans identite, et la personne ne
-- pouvait ni entrer ni recommencer — son numero etait deja pris.
--
-- Le defaut etait invisible tant que la base n'etait pas hebergee : le
-- backend simule du site ne verifie aucune contrainte.

alter table profiles drop constraint if exists profiles_role_check;
alter table profiles
  add constraint profiles_role_check
  check (role in ('TEACHER', 'INSTITUTION', 'PARENT', 'STUDENT', 'ADMIN'));

-- --- Ce qu'un etudiant majeur est, pour le reste du schema ---------------
--
-- Il partage l'espace de la famille : meme suivi, memes demandes de cours,
-- memes contrats. Sa fiche est donc une ligne de `parents`, et ce n'est pas un
-- bricolage — c'est le choix fait cote mobile (`UserRole.followsAStudent`),
-- et le dupliquer en une table jumelle aurait double chaque requete du
-- parcours famille.
--
-- Ce qui le distingue tient en une chose : c'est lui qui signe. La regle des
-- 18 ans se rattache au role, pas a la fiche.

-- Les politiques ecrites pour PARENT doivent donc le reconnaitre. Elles
-- passent toutes par `my_parent_id()`, qui lit `parents.user_id = auth.uid()`
-- sans regarder le role : rien a changer. Cette fonction est la raison pour
-- laquelle cette migration ne reecrit aucune politique.

-- --- Garde-fou ------------------------------------------------------------
--
-- `profiles_guard()` (0004) empeche un compte de changer son propre role.
-- Elle reste en place et couvre le nouveau role sans modification : elle
-- compare l'ancien et le nouveau sans enumerer les valeurs permises.

comment on constraint profiles_role_check on profiles is
  'Quatre profils choisissables dans intro.json, plus ADMIN pour le back-office.';
