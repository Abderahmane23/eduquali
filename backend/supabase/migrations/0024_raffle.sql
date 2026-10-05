-- Le tirage au sort (04/10) — la sortie pour les lots de valeur.
--
-- --- Le probleme, en une ligne --------------------------------------------
--
-- Un telephone a 8 000 000 GNF ne s'achete pas avec la fidelite d'UN eleve. A
-- 26 points par semaine, l'iPhone 17 demandait 1 850 seances : on promettait
-- quelque chose que personne n'obtiendrait, ce qui demotive plus surement
-- qu'une boutique vide.
--
-- Baisser le prix ne reglait rien. L'arithmetique ne depend pas du bareme, elle
-- depend du fait qu'un eleve ne rapporte pas huit millions.
--
-- --- Ce que le tirage change ---------------------------------------------
--
-- Les points n'achetent plus l'objet, ils achetent une **chance**. La promesse
-- passe de « travaillez 1 850 seances » a « l'un de vous le gagnera », qui est
-- vraie, finançable, et motivante pour tout le monde en meme temps.
--
-- Cent eleves qui misent quelques entrees par mois rendent un Galaxy A5
-- mensuel soutenable, la ou le vendre a un seul ne l'etait jamais.
--
-- --- ⚠ Une question qui n'est pas technique ------------------------------
--
-- Un tirage au sort peut relever d'une reglementation locale. Ici les points se
-- **gagnent** et ne s'achetent pas — ce n'est donc pas une loterie payante,
-- plutot un jeu de fidelite —, mais la frontiere se verifie aupres de quelqu'un
-- qui connait le droit guineen, pas dans un fichier SQL.

-- Acheter l'objet, ou acheter une chance de l'avoir.
alter table shop_items
  add column if not exists kind text not null default 'DIRECT'
    check (kind in ('DIRECT', 'RAFFLE'));

-- La date du tirage, pour les lots qui s'en remettent au sort. Affichee :
-- « tirage le 30 novembre » transforme une attente en rendez-vous.
alter table shop_items add column if not exists draws_at timestamptz;

-- Le prix gele porte deja sur la demande ; son **genre** aussi, pour la meme
-- raison. Un lot qui passerait de DIRECT a RAFFLE ne doit pas reecrire ce que
-- les gens ont deja obtenu.
alter table redemptions
  add column if not exists kind text not null default 'DIRECT'
    check (kind in ('DIRECT', 'RAFFLE'));

-- Les entrees d'un tirage encore ouvert : la requete de l'ecran, et celle du
-- tirage lui-meme.
create index if not exists redemptions_raffle_idx
  on redemptions (item_id, status)
  where kind = 'RAFFLE';

/*
 * Echanger — ou tenter sa chance.
 *
 * La fonction de 0021 est remplacee plutot que doublee : deux fonctions qui
 * debitent des points finiraient par diverger sur la verification du solde, et
 * c'est exactement l'endroit ou une divergence coute de l'argent.
 *
 * Les deux branches partagent donc tout ce qui compte — verrou sur la ligne,
 * solde lu depuis le journal, debit nomme — et ne different que sur deux
 * points :
 *
 *   * **le stock** ne bouge pas pour un tirage. Il compte les objets a gagner,
 *     pas les entrees vendues ; le decrementer a chaque mise epuiserait le lot
 *     avant le tirage ;
 *   * **la repetition** est permise. Miser trois fois triple ses chances, et
 *     c'est tout l'interet. Un achat direct, lui, reste limite par le stock.
 */
create or replace function redeem_shop_item(item text)
  returns table (redemption_id text, reason text)
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  moi      uuid := auth.uid();
  prix     integer;
  restant  integer;
  genre    text;
  nom      text;
  solde    integer;
  nouvelle text;
begin
  if moi is null then
    return query select null::text, 'NOT_SIGNED_IN';
    return;
  end if;

  select s.points_price, s.stock, s.kind, s.name
    into prix, restant, genre, nom
    from shop_items s
   where s.id = item and s.active
     for update;

  if prix is null then
    return query select null::text, 'UNKNOWN_ITEM';
    return;
  end if;

  -- Un tirage sans objet a gagner n'accepte plus de mise : prendre des points
  -- pour une chance de gagner rien serait un vol.
  if restant <= 0 then
    return query select null::text, 'OUT_OF_STOCK';
    return;
  end if;

  -- Et un tirage deja passe non plus.
  if genre = 'RAFFLE' and exists (
    select 1 from shop_items s
     where s.id = item and s.draws_at is not null and s.draws_at < now()
  ) then
    return query select null::text, 'DRAW_CLOSED';
    return;
  end if;

  select coalesce(sum(delta), 0)::integer into solde
    from point_ledger where owner_id = moi;

  if solde < prix then
    return query select null::text, 'NOT_ENOUGH_POINTS';
    return;
  end if;

  if genre = 'DIRECT' then
    update shop_items set stock = stock - 1, updated_at = now()
     where id = item;
  end if;

  insert into redemptions (user_id, item_id, points_spent, kind)
       values (moi, item, prix, genre)
    returning id into nouvelle;

  insert into point_ledger (owner_id, delta, reason, reference)
       values (
         moi,
         -prix,
         case
           when genre = 'RAFFLE' then 'Participation au tirage — ' || nom
           else 'Echange — ' || nom
         end,
         'redemption:' || nouvelle
       );

  return query select nouvelle, null::text;
end;
$$;

/*
 * Tirer au sort.
 *
 * Reserve au serveur : la fonction decide qui gagne, et personne d'autre ne
 * doit pouvoir la declencher.
 *
 * Toutes les entrees sont traitees d'un coup — la gagnante passe `DELIVERED`,
 * les autres `REFUSED` avec un motif lisible. Laisser les perdantes en
 * `PENDING` donnerait des demandes eternellement en attente, et personne ne
 * saurait jamais que le tirage a eu lieu.
 *
 * **Les points ne sont pas rendus.** Une mise perdue reste depensee, c'est la
 * nature d'un tirage, et la phrase du refus le dit en clair plutot que de
 * laisser deviner.
 */
create or replace function draw_raffle(item text)
  returns table (winner uuid, entries integer)
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  gagnante text;
  total    integer;
  nom      text;
begin
  select s.name into nom from shop_items s where s.id = item for update;
  if nom is null then
    return;
  end if;

  select count(*) into total
    from redemptions r
   where r.item_id = item and r.kind = 'RAFFLE' and r.status = 'PENDING';

  if total = 0 then
    return query select null::uuid, 0;
    return;
  end if;

  -- Une entree au hasard parmi celles en attente : miser trois fois donne donc
  -- bien trois fois plus de chances, puisque chaque mise est une ligne.
  select r.id into gagnante
    from redemptions r
   where r.item_id = item and r.kind = 'RAFFLE' and r.status = 'PENDING'
   order by random()
   limit 1;

  update redemptions
     set status = 'DELIVERED',
         decided_at = now(),
         note = 'Tirage gagnant — un responsable vous contacte pour la remise.'
   where id = gagnante;

  update redemptions
     set status = 'REFUSED',
         decided_at = now(),
         note = 'Tirage du ' || to_char(now(), 'DD/MM/YYYY') ||
                ' : ce n''est pas passé cette fois. Les points misés restent ' ||
                'dépensés, comme annoncé.'
   where item_id = item and kind = 'RAFFLE' and status = 'PENDING';

  update shop_items
     set stock = greatest(stock - 1, 0), updated_at = now()
   where id = item;

  return query
    select r.user_id, total from redemptions r where r.id = gagnante;
end;
$$;

comment on function draw_raffle(text) is
  'Tire un gagnant parmi les entrees en attente et tranche toutes les autres. '
  'Les points mises ne sont pas rendus : c''est la nature d''un tirage.';
comment on column shop_items.kind is
  'DIRECT : les points achetent l''objet. RAFFLE : ils achetent une chance, '
  'parce qu''un telephone a 8 000 000 GNF ne s''achete pas avec la fidelite '
  'd''un seul eleve.';
