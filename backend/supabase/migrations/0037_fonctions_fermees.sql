-- Les fonctions qui passent outre RLS se ferment au navigateur (18/10).
--
-- --- Ce qui a déclenché cette migration ----------------------------------
--
-- La migration 0034 crée `usage_compte(qui, quoi, depuis)` et l'accorde à
-- `service_role` :
--
--     grant execute on function usage_compte to service_role;
--
-- Un `grant` n'enlève rien. En Postgres, une fonction nouvellement créée est
-- exécutable par `PUBLIC` : accorder à `service_role` ajoute un droit, il ne
-- retire pas celui que tout le monde avait déjà.
--
-- Vérifié sur la base en ligne, avec la seule clé publique — celle que tout
-- visiteur reçoit dans le bundle du site :
--
--     POST /rest/v1/rpc/usage_compte        →  200, "0"
--     POST /rest/v1/rpc/ai_messages_du_jour →  200, "0"
--
-- Les deux sont `security definer` : elles lisent en passant outre RLS. Or
-- toutes deux prennent le compte en **argument**. N'importe qui pouvait donc
-- demander « combien de directs a suivis le compte X » ou « combien de
-- questions a posées le compte Y aujourd'hui », pour n'importe quel
-- identifiant.
--
-- Ce ne sont pas les fuites les plus graves : il faut déjà tenir un UUID, et
-- la réponse est un nombre. Mais ce sont des habitudes de consommation, elles
-- concernent des enfants, et rien n'obligeait à les ouvrir.
--
-- --- Pourquoi les cinq autres suivent ------------------------------------
--
-- Un inventaire des fonctions `security definer` du dépôt en a montré sept
-- dans ce cas. Pour chacune, une seule question : **qui l'appelle ?**
--
--     crediter_points      aucun appelant (déclenchée par trigger)
--     offrir_points        aucun appelant
--     purge_audit_events   aucun appelant
--     draw_raffle          aucun appelant
--     redeem_shop_item     le Worker, et lui seul
--     ai_messages_du_jour  le Worker, et lui seul
--     usage_compte         le Worker, et lui seul
--
-- Aucune n'est appelée depuis un navigateur ni depuis l'APK. Les laisser
-- ouvertes n'ouvre donc rien d'utile, et ferme mal deux choses sérieuses :
-- `crediter_points(beneficiaire, montant, …)` **crédite des points à un
-- compte arbitraire** — de quoi s'en accorder puis les dépenser à la
-- boutique — et `purge_audit_events(retention_months)` **supprime des lignes
-- d'audit**, c'est-à-dire la trace de ce qui s'est passé.
--
-- Je n'ai pas sondé ces deux-là sur la base en ligne : une sonde qui crédite
-- des points ou détruit une preuve n'est pas une sonde. Elles sont fermées
-- par précaution, ce qui ne coûte rien puisque personne ne les appelle.
--
-- --- Ce qui n'est PAS touché ---------------------------------------------
--
-- Les aides de RLS — `my_teacher_id`, `my_parent_id`, `my_institution_id`,
-- `current_role_is`, `has_bought_course`, `course_of_item`,
-- `est_membre_groupe`, `compte_actif` — restent ouvertes, et **doivent** le
-- rester : elles sont évaluées à l'intérieur des politiques, par le rôle qui
-- interroge. Les révoquer fermerait la base à tout le monde.
--
-- Elles sont d'ailleurs sans danger : elles dérivent de `auth.uid()` et ne
-- prennent aucun identifiant en argument. On ne peut pas leur demander le
-- compte de quelqu'un d'autre.
--
-- --- La règle, pour la prochaine fois ------------------------------------
--
-- **Une fonction `security definer` se révoque d'abord, et s'accorde
-- ensuite.** `remplacer_competences` (migration 0029) le faisait déjà ; j'ai
-- écrit 0034 sans suivre ce précédent.

-- Les deux dont l'ouverture est constatée.
revoke all on function usage_compte(uuid, text, timestamptz) from public;
revoke all on function usage_compte(uuid, text, timestamptz) from anon;
revoke all on function usage_compte(uuid, text, timestamptz) from authenticated;
grant execute on function usage_compte(uuid, text, timestamptz) to service_role;

revoke all on function ai_messages_du_jour(uuid) from public;
revoke all on function ai_messages_du_jour(uuid) from anon;
revoke all on function ai_messages_du_jour(uuid) from authenticated;
grant execute on function ai_messages_du_jour(uuid) to service_role;

-- Les cinq fermées par précaution : aucune n'est appelée depuis un client.
revoke all on function crediter_points(uuid, integer, text, text) from public;
revoke all on function crediter_points(uuid, integer, text, text) from anon;
revoke all on function crediter_points(uuid, integer, text, text)
  from authenticated;
grant execute on function crediter_points(uuid, integer, text, text)
  to service_role;

revoke all on function offrir_points(uuid, integer) from public;
revoke all on function offrir_points(uuid, integer) from anon;
revoke all on function offrir_points(uuid, integer) from authenticated;
grant execute on function offrir_points(uuid, integer) to service_role;

revoke all on function purge_audit_events(integer) from public;
revoke all on function purge_audit_events(integer) from anon;
revoke all on function purge_audit_events(integer) from authenticated;
grant execute on function purge_audit_events(integer) to service_role;

revoke all on function draw_raffle(text) from public;
revoke all on function draw_raffle(text) from anon;
revoke all on function draw_raffle(text) from authenticated;
grant execute on function draw_raffle(text) to service_role;

revoke all on function redeem_shop_item(text) from public;
revoke all on function redeem_shop_item(text) from anon;
revoke all on function redeem_shop_item(text) from authenticated;
grant execute on function redeem_shop_item(text) to service_role;

comment on function usage_compte is
  'Le nombre de gestes consommés depuis une date. Réservée à la clé de '
  'service : `qui` est un simple argument, et la fonction passe outre RLS.';
