-- Combien de fois chaque cours a été acheté (18/10).
--
-- --- Pourquoi une vue ----------------------------------------------------
--
-- L'accueil doit montrer « les cours les plus suivis ». Aucun chiffre ne le
-- disait : ni `video_courses` ni l'API n'exposaient de compteur de ventes.
-- Classer sans ce chiffre aurait voulu dire inventer un ordre et l'appeler
-- « les plus suivis » — un classement faux est pire qu'une liste non
-- classée, parce qu'il est cru.
--
-- Le chiffre existe pourtant : `course_purchases` porte une ligne par achat,
-- et l'unicité `(course_id, parent_id)` garantit qu'un même cours acheté
-- deux fois par la même famille ne compte qu'une fois. Il suffisait de le
-- compter.
--
-- --- Pourquoi pas une lecture directe depuis le client -------------------
--
-- `course_purchases` est fermée par RLS : chacun ne voit que ses propres
-- achats. Un visiteur qui compterait lui-même obtiendrait donc zéro partout,
-- et le classement serait silencieusement vide — la forme de panne que ce
-- projet produit le plus souvent.
--
-- La vue n'active pas `security_invoker` : elle appartient au propriétaire du
-- schéma, et c'est ce qui lui permet de compter des lignes que l'appelant ne
-- peut pas lire. Elle n'expose que deux colonnes, et aucune ne désigne
-- quelqu'un : « ce cours a été acheté 12 fois » n'apprend rien sur qui l'a
-- acheté.

create or replace view video_courses_ventes
  with (security_invoker = false)
as
  select
    course_id,
    count(*)::integer as ventes,
    max(created_at)   as derniere_vente
  from course_purchases
  group by course_id;

comment on view video_courses_ventes is
  'Le nombre d''achats par cours vidéo, et la date du dernier. Deux '
  'colonnes, et aucune ne désigne un acheteur : le classement de l''accueil '
  'a besoin du combien, pas du qui.';

grant select on video_courses_ventes to anon, authenticated;
