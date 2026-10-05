-- La boutique et les lots (04/10) — phase D2.
--
-- --- Pourquoi une boutique, et pourquoi maintenant ------------------------
--
-- `point_ledger` existe depuis le 03/10 et les points s'accumulaient vers rien.
-- Une monnaie de fidelite qui n'achete rien est un nombre qui monte, et un
-- enfant s'en rend compte vite. C'est la contrepartie qui donne sa valeur a la
-- monnaie, pas l'inverse.
--
-- --- Le prix est en points, la valeur est en francs ----------------------
--
-- Les deux colonnes coexistent a dessein. « 30 000 points » ne veut rien dire
-- seul ; « 30 000 points — environ 5 000 000 GNF » rend le bareme lisible et
-- permet a une famille de juger si l'effort en vaut la peine. Le plan le
-- demandait explicitement.
--
-- `value_gnf` n'est PAS un prix de vente : rien ne s'achete ici avec de
-- l'argent. C'est un ordre de grandeur affiche, et le jour ou quelqu'un voudra
-- en faire un tarif, cette ligne dira que ce n'etait pas l'objet.

create table if not exists shop_items (
  id            text primary key,
  name          text not null check (char_length(btrim(name)) >= 2),
  summary       text,

  -- Le nom de base de l'illustration, sans extension ni densite :
  -- « lot-iphone-15 ». Le client ajoute « @2x » et « .webp » selon son ecran,
  -- comme pour les illustrations des parcours.
  image         text not null,

  points_price  integer not null check (points_price > 0),

  -- L'equivalent annonce, en francs guineens. Zero permis : un lot offert par
  -- un partenaire n'a pas toujours de valeur a afficher.
  value_gnf     bigint not null default 0 check (value_gnf >= 0),

  -- Combien il en reste. A zero, le lot reste visible mais ne s'echange plus :
  -- le retirer de l'affichage ferait croire qu'il n'a jamais existe, et c'est
  -- lui qui donne envie de continuer.
  stock         integer not null default 0 check (stock >= 0),

  active        boolean not null default true,
  position      integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists shop_items_ordre_idx
  on shop_items (position, points_price)
  where active;

/*
 * Une demande d'echange.
 *
 * `PENDING` tant qu'un humain n'a pas remis l'objet. Un telephone ne se livre
 * pas par une requete HTTP : quelqu'un le sort d'un carton et le donne en main
 * propre. La table enregistre donc une **demande**, pas une livraison, et c'est
 * la validation manuelle qui la clot.
 */
create table if not exists redemptions (
  id            text primary key default gen_random_uuid()::text,
  user_id       uuid not null references auth.users (id) on delete cascade,
  item_id       text not null references shop_items (id),

  -- Le prix au moment de l'echange, fige. Le bareme peut changer ensuite ;
  -- ce qui a ete preleve ne doit pas se mettre a jour tout seul.
  points_spent  integer not null check (points_spent > 0),

  status        text not null default 'PENDING'
                check (status in ('PENDING', 'DELIVERED', 'REFUSED')),

  requested_at  timestamptz not null default now(),
  decided_at    timestamptz,

  -- Pourquoi, quand c'est refuse. Un refus sans motif se vit comme un vol de
  -- points.
  note          text
);

create index if not exists redemptions_user_idx
  on redemptions (user_id, requested_at desc);
create index if not exists redemptions_pending_idx
  on redemptions (requested_at)
  where status = 'PENDING';

/*
 * Echanger, de maniere atomique.
 *
 * --- Pourquoi une fonction et non trois requetes ------------------------
 *
 * L'echange fait trois choses qui doivent tenir ensemble : verifier le solde,
 * debiter le journal, decrementer le stock. Faites separement depuis le
 * serveur, deux demandes simultanees passent toutes deux la verification de
 * solde et debitent deux fois — ou pire, prennent le dernier exemplaire deux
 * fois. Les telephones reessaient quand le reseau coupe, donc ce n'est pas un
 * cas theorique.
 *
 * Meme raison que `claim_session_seat` (0015) : la condition et l'ecriture dans
 * la meme instruction, et c'est Postgres qui arbitre.
 *
 * --- Ce qu'elle rend -----------------------------------------------------
 *
 * L'identifiant de la demande, ou `null` avec un motif. Pas d'exception : un
 * solde insuffisant est une reponse normale, pas une panne, et l'ecran doit
 * pouvoir dire « il vous manque 1 200 points » plutot qu'une erreur.
 */
create or replace function redeem_shop_item(item text)
  returns table (redemption_id text, reason text)
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  moi           uuid := auth.uid();
  prix          integer;
  solde         integer;
  restant       integer;
  nouvelle      text;
begin
  if moi is null then
    return query select null::text, 'NOT_SIGNED_IN';
    return;
  end if;

  -- Verrou sur la ligne du lot : deux demandes simultanees sur le dernier
  -- exemplaire se mettent en file au lieu de passer toutes les deux.
  select s.points_price, s.stock into prix, restant
    from shop_items s
   where s.id = item and s.active
     for update;

  if prix is null then
    return query select null::text, 'UNKNOWN_ITEM';
    return;
  end if;

  if restant <= 0 then
    return query select null::text, 'OUT_OF_STOCK';
    return;
  end if;

  -- Le solde est la somme du journal, jamais une colonne : il ne peut pas etre
  -- perime au moment ou on le lit.
  select coalesce(sum(delta), 0)::integer into solde
    from point_ledger where owner_id = moi;

  if solde < prix then
    return query select null::text, 'NOT_ENOUGH_POINTS';
    return;
  end if;

  update shop_items set stock = stock - 1, updated_at = now()
   where id = item;

  insert into redemptions (user_id, item_id, points_spent)
       values (moi, item, prix)
    returning id into nouvelle;

  -- Le debit porte le nom du lot : « un solde qui baisse sans raison lisible »
  -- est encore pire qu'un solde qui monte sans raison.
  insert into point_ledger (owner_id, delta, reason, reference)
       select moi, -prix, 'Echange — ' || s.name, 'redemption:' || nouvelle
         from shop_items s where s.id = item;

  return query select nouvelle, null::text;
end;
$$;

comment on function redeem_shop_item(text) is
  'Echange atomique : solde, stock et journal dans une seule instruction. '
  'Rend (null, motif) quand c''est refuse — un solde insuffisant est une '
  'reponse, pas une panne.';

alter table shop_items enable row level security;
alter table redemptions enable row level security;

-- Le catalogue s'annonce : on doit voir ce que les points permettent avant
-- d'en avoir.
create policy "boutique : visible de tous" on shop_items
  for select using (true);

create policy "echange : le sien" on redemptions
  for select using (user_id = auth.uid());

-- **Aucune politique d'ecriture sur les deux tables.** Un echange passe par
-- `redeem_shop_item`, qui est `security definer` : c'est le seul chemin, et il
-- est atomique. Une politique d'insertion sur `redemptions` permettrait de
-- demander un lot sans jamais debiter les points.

comment on table shop_items is
  'Les lots. `value_gnf` est un ordre de grandeur affiche, jamais un prix de '
  'vente : rien ne s''achete ici avec de l''argent.';
comment on table redemptions is
  'Une DEMANDE d''echange. Un telephone se remet en main propre ; la validation '
  'est humaine.';
