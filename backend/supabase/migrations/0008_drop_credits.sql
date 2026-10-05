-- Fin du systeme de credits (25/09).
--
-- L'assistant IA, la mise en avant d'un etablissement et la messagerie sont
-- ouverts par l'abonnement (Basic, Pro, Master) : il n'y a plus rien a
-- decompter, donc plus rien a tenir en grand livre. Le client mobile a fait
-- le meme retrait dans sa migration locale v20.
--
-- Ce fichier s'ecrit en 0008 plutot qu'en corrigeant 0006 : une migration
-- deja appliquee ne se reecrit pas, et on ne sait pas depuis l'ici et
-- maintenant si 0006 a tourne sur l'instance. `if exists` rend le passage
-- sur une base ou rien n'a encore ete cree aussi sur que sur une base a
-- jour.

-- --- Le grand livre ------------------------------------------------------
--
-- La politique RLS part avec la table : supprimer une table emporte ses
-- politiques, mais l'ecrire ici rend l'intention lisible dans l'historique.
drop policy if exists "credits : lecture de son grand livre" on credit_ledger;
drop index if exists credit_ledger_owner_idx;
drop table if exists credit_ledger;

-- --- Le cout fige sur une promotion --------------------------------------
--
-- Il valait 50 credits a la mise en ligne. Une promotion ne se paie plus a
-- l'acte : la colonne ne porterait plus qu'un zero sur chaque ligne, et un
-- zero affiche se lit comme une information.
alter table promotions drop column if exists credit_cost;
