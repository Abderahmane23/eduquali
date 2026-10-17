-- Les noms d'ecoles deja saisis (17/10).
--
-- --- Le constat qui a declenche ce fichier --------------------------------
--
-- Le parcours d'inscription d'un parent demande le nom de l'ecole de son
-- enfant. Le champ est declare `combo` avec `allowCustom: true` dans la
-- specification partagee : on doit pouvoir **taper** un nom absent de la
-- liste. Deux choses l'empechaient.
--
-- D'abord le site rendait ce champ comme un menu deroulant : aucune saisie
-- libre possible. Une famille dont l'ecole manquait n'avait pas de recours.
--
-- Ensuite, la liste proposee ne venait pas des ecoles. Elle etait construite
-- a partir des **anciens employeurs declares par les professeurs**
-- (`teacher_experiences.institution_name`) — ce qui donne des noms d'ecoles,
-- certes, mais seulement celles ou un professeur inscrit a deja travaille.
--
-- --- Ce que cette vue rassemble ------------------------------------------
--
-- Les trois endroits ou un nom d'ecole existe deja dans la base :
--
--   * `institutions.name`                   les ecoles qui ont un compte ;
--   * `children.school_name`                celles que les familles ont tapees ;
--   * `teacher_experiences.institution_name` celles ou un professeur a enseigne.
--
-- Une famille qui tape un nom nouveau le fait donc apparaitre pour la
-- suivante, sans qu'aucun compte d'etablissement ait a exister : c'est ce
-- qui etait demande, et c'est la seule facon d'obtenir une liste utile dans
-- un pays ou la plupart des ecoles ne sont pas encore inscrites.
--
-- --- Ce que la vue n'expose pas ------------------------------------------
--
-- **Le nom, et rien d'autre.** Pas l'enfant, pas le parent, pas le
-- professeur, pas la ville. `children` est fermee par RLS a tout autre
-- compte que le parent ; cette vue ne l'ouvre pas — elle en tire une colonne
-- qui, seule, ne designe personne. « L'ecole Sainte-Marie existe » n'apprend
-- rien sur qui y est inscrit.
--
-- La vue appartient au proprietaire du schema et n'active pas
-- `security_invoker` : c'est deliberé, et c'est ce qui permet a un visiteur
-- de voir les noms tapes par d'autres familles sans voir leurs lignes. La
-- selection est reduite a `distinct nom` pour que rien d'autre ne puisse
-- filtrer.

create or replace view ecoles_connues
  with (security_invoker = false)
as
  select distinct btrim(nom) as nom
    from (
      select name            as nom from institutions
      union all
      select school_name     as nom from children
      union all
      select institution_name as nom from teacher_experiences
    ) as tout
   where nom is not null
     and btrim(nom) <> ''
     -- Deux caracteres : une saisie d'un seul signe est une faute de frappe,
     -- et la proposer a la famille suivante propagerait l'erreur.
     and char_length(btrim(nom)) >= 2;

comment on view ecoles_connues is
  'Les noms d''ecoles deja saisis, d''ou qu''ils viennent. Le nom seul : '
  'ni enfant, ni parent, ni professeur. Alimente l''autocompletion du '
  'parcours d''inscription.';

grant select on ecoles_connues to anon, authenticated;
