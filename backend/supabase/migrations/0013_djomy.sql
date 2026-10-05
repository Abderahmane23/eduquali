-- Encaissement par Djomy (02/10).
--
-- La migration 0012 a pose un etat sur l'achat sans savoir qui encaisserait.
-- Djomy est retenu : agregateur guineen couvrant Orange Money, MTN MoMo, Kulu
-- et les cartes. Cette migration aligne le schema sur ce que sa plateforme
-- envoie reellement.
--
-- --- Les etats ------------------------------------------------------------
--
-- Djomy rend CREATED, PENDING, SUCCESS, CANCELLED et FAILED, et ses webhooks
-- ajoutent `payment.timeout` et `payment.refunded`. Nos trois etats n'y
-- suffisaient pas : un echec technique etait indistinguable d'une annulation
-- par le client, ce qui rend le support aveugle — « j'ai paye et ca n'a pas
-- marche » ne se traite pas comme « j'ai renonce ».

alter table course_purchases drop constraint if exists course_purchases_status_check;
alter table course_purchases
  add constraint course_purchases_status_check
  check (status in ('PENDING', 'PAID', 'FAILED', 'CANCELLED', 'REFUNDED'));

-- --- Ce que l'operateur retient -------------------------------------------
--
-- L'exemple de webhook donne `paidAmount: 10000`, `receivedAmount: 9000`,
-- `fees: 1000`. Autrement dit **la commission de Djomy sort du montant
-- encaisse**, elle ne s'ajoute pas. Le professeur touche 80 % de quoi ? Si
-- c'est 80 % du prix affiche, la plateforme paie les frais de son propre
-- revenu ; si c'est 80 % du recu, le professeur les paie. La question n'est pas
-- tranchee, et le code ne la tranche pas a la place de qui doit le faire : on
-- enregistre les deux montants, et le calcul du reversement les lira.

alter table course_purchases
  add column if not exists provider_fees integer
    check (provider_fees is null or provider_fees >= 0),
  add column if not exists provider_received integer
    check (provider_received is null or provider_received >= 0),
  -- OM, MOMO, CARD… tel que l'operateur le nomme. Non contraint a une liste :
  -- Djomy en ajoute (SOUTRA_MONEY, PAYCARD, YMO sont annonces), et une
  -- contrainte a mettre a jour a chaque ajout ne protege de rien.
  add column if not exists provider_method text,
  -- Le numero qui a paye. Il n'est pas toujours celui du compte : on paie avec
  -- le portefeuille d'un parent, d'un oncle, d'un voisin. Le garder est la
  -- seule facon de rapprocher un reglement d'une reclamation.
  add column if not exists payer_identifier text;

-- --- Le journal des evenements, et pourquoi il est indispensable ----------
--
-- Djomy reessaie un webhook qui n'a pas repondu 200. Sans table de
-- deduplication, un seul reessai sur `payment.success` rejouerait le traitement
-- : deux incrementations de `purchase_count`, et le jour ou un reversement
-- automatique existera, deux paiements au professeur pour une vente.
--
-- La cle est `event_id`, fourni par Djomy et unique par evenement. L'insertion
-- se fait **avant** de toucher l'achat : si elle echoue sur la contrainte,
-- l'evenement est deja traite et il n'y a rien a faire.

create table if not exists payment_events (
  -- L'identifiant de Djomy, pas le notre : c'est lui qui porte l'unicite.
  event_id      text primary key,
  event_type    text not null,
  transaction_id text,
  -- La reference que nous avions envoyee : l'identifiant de l'achat. Elle
  -- permet de retrouver la ligne meme si `provider_ref` n'a pas pu etre
  -- enregistre a l'initiation.
  merchant_ref  text,
  status        text,
  paid_amount   integer,
  -- Le corps brut, tel que recu et signe. C'est la preuve : en cas de litige
  -- sur un montant, c'est ce texte qui tranche, pas nos colonnes derivees.
  payload       jsonb not null,
  received_at   timestamptz not null default now()
);

create index if not exists payment_events_transaction_idx
  on payment_events (transaction_id);
create index if not exists payment_events_merchant_ref_idx
  on payment_events (merchant_ref);

alter table payment_events enable row level security;

-- Aucune politique : la table n'est lisible et ecrivable que par la cle de
-- service. Un acheteur n'a rien a y faire, et un evenement de paiement nomme
-- des montants et des numeros de telephone. **L'absence de politique est la
-- regle**, pas un oubli : RLS activee sans politique ferme la table a tous les
-- roles clients.

comment on table payment_events is
  'Journal des webhooks de paiement. event_id porte la deduplication : un '
  'reessai de Djomy ne doit pas rejouer un encaissement.';
