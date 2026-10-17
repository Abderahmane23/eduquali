-- L'espace d'exploitation (17/10).
--
-- --- Le constat qui a declenche ce fichier --------------------------------
--
-- Deux operations du produit n'avaient aucun moyen d'etre faites : approuver
-- un retrait, et remettre un lot de la boutique. Les deux tables existaient,
-- les deux files se remplissaient, et aucune route ne permettait d'y
-- repondre. On y repondait donc dans l'editeur SQL de Supabase — c'est-a-dire
-- a la main, sans trace, et avec la cle de service ouverte dans un onglet.
--
-- Ce sont pourtant les deux operations qui font tourner l'entreprise : payer
-- les professeurs, c'est l'offre entiere ; livrer les lots, c'est la boucle
-- de retour entiere.
--
-- --- Ce que ce fichier ajoute, et ce qu'il n'ajoute pas -------------------
--
-- Il ajoute **une** fonction : celle qui refuse un lot. Un refus touche trois
-- choses a la fois — le statut, les points de l'eleve, le stock du lot — et
-- trois ecritures separees laissent une fenetre ou l'eleve a perdu ses points
-- sans que le lot soit revenu en stock.
--
-- Il n'ajoute aucune table et aucun role. L'operateur est un compte dont
-- `profiles.role` vaut `ADMIN`, et cette valeur est deja hors de portee d'un
-- client : le schema d'inscription n'accepte que
-- `TEACHER | INSTITUTION | PARENT | STUDENT`, et la route de provisionnement
-- refuse de changer le role d'un compte deja cree. Ajouter une seconde table
-- d'autorite donnerait deux sources de verite sur « qui est de la maison »,
-- et c'est exactement ce que ce projet evite partout ailleurs.
--
-- Le reglement d'un retrait, lui, n'a pas besoin de fonction : c'est une
-- seule ligne, et la mise a jour conditionnelle suffit a la rendre
-- idempotente (voir la route `/operations/payouts/:id/decision`).

-- ===========================================================================
-- 1. Refuser un lot deja echange
-- ===========================================================================
--
-- --- Pourquoi un refus doit rendre les points ----------------------------
--
-- `redeem_shop_item` fait trois choses : il decremente le stock, il cree la
-- demande, et il **debite les points immediatement**. C'est le bon choix — un
-- solde qui ne baisse qu'a la livraison laisserait depenser deux fois le meme
-- point pendant que la premiere demande attend.
--
-- Mais il impose son symetrique : un lot refuse doit rendre les points, sans
-- quoi l'eleve a paye pour rien. Un refus qui coute des points se vit comme
-- un vol, et c'est la boutique entiere qui cesse d'etre credible.
--
-- --- Pourquoi c'est idempotent -------------------------------------------
--
-- La reference `refus:<id>` est unique dans le journal. Un operateur qui
-- clique deux fois — ou deux operateurs sur la meme demande — ne rendent les
-- points qu'une fois. C'est la meme garde que `accorder_points`, et pour la
-- meme raison : le code d'appel a deja laisse passer un double clic.

create or replace function refuser_lot(demande text, motif text)
  returns table (rendu integer, raison text)
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  ligne     redemptions%rowtype;
  cle       text := 'refus:' || demande;
  nom_lot   text;
begin
  if motif is null or btrim(motif) = '' then
    return query select 0, 'MOTIF_MANQUANT';
    return;
  end if;

  -- Verrou sur la demande : deux refus simultanes se mettent en file.
  select * into ligne from redemptions where id = demande for update;

  if ligne.id is null then
    return query select 0, 'INCONNUE';
    return;
  end if;

  if ligne.status <> 'PENDING' then
    -- Deja tranchee : ce n'est pas une erreur, c'est l'etat attendu quand on
    -- revient sur l'ecran. Rendre un echec ferait croire a une panne.
    return query select 0, 'DEJA_TRANCHEE';
    return;
  end if;

  update redemptions
     set status = 'REFUSED', decided_at = now(), note = motif
   where id = demande;

  -- Le stock revient : le lot n'est pas parti.
  update shop_items set stock = stock + 1, updated_at = now()
   where id = ligne.item_id;

  select s.name into nom_lot from shop_items s where s.id = ligne.item_id;

  -- Les points reviennent, et le journal dit pourquoi. « Un solde qui monte
  -- sans raison lisible » est aussi genant qu'un solde qui baisse sans.
  if not exists (select 1 from point_ledger where reference = cle) then
    insert into point_ledger (owner_id, delta, reason, reference)
         values (ligne.user_id, ligne.points_spent,
                 'Remboursement — ' || coalesce(nom_lot, 'lot retire'), cle);
  end if;

  return query select ligne.points_spent, null::text;
end;
$$;

comment on function refuser_lot(text, text) is
  'Refus atomique : statut, stock et points rendus en une seule instruction. '
  'Rend (0, motif) quand c''est impossible — une demande deja tranchee est '
  'un etat attendu, pas une panne.';

revoke all on function refuser_lot(text, text) from public, anon;

-- ===========================================================================
-- 2. Les deux files, lues dans l'ordre d'arrivee
-- ===========================================================================
--
-- Un operateur traite par anciennete : la demande qui attend depuis trois
-- jours passe avant celle de ce matin. Sans index, chaque ouverture de
-- l'ecran trie la table entiere.

create index if not exists payout_requests_file_idx
  on payout_requests (requested_at)
  where status in ('REQUESTED', 'APPROVED');

create index if not exists redemptions_file_idx
  on redemptions (requested_at)
  where status = 'PENDING';
