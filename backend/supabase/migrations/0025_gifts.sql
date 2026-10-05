-- Offrir des points a quelqu'un (04/10) — phase D3, plafonnee a 2 par jour.
--
-- --- Le plafond -----------------------------------------------------------
--
-- Le plan prevoyait **10 points par jour**. C'est deux, decide le 04/10, et la
-- raison est arithmetique : une seance suivie en rapporte 18. A dix par jour, un
-- groupe de quatre comptes complices transfere tout son solde vers un seul en
-- quelques jours, et la boutique se vide au profit de qui a le plus d'amis
-- plutot que de qui a le plus suivi.
--
-- A deux, le geste garde son sens — remercier, encourager — sans devenir un
-- moyen de concentrer la monnaie.
--
-- --- Pourquoi une fonction et non deux ecritures depuis le serveur -------
--
-- Un transfert, ce sont **deux lignes qui doivent exister ensemble** : le debit
-- de l'un et le credit de l'autre. Faites separement, une panne entre les deux
-- fait disparaitre des points ou en invente. Ici les deux vivent dans la meme
-- instruction, et c'est Postgres qui garantit le tout ou rien.
--
-- Le plafond se verifie dans la meme instruction, sous le meme verrou : le lire
-- puis ecrire laisserait deux requetes simultanees passer toutes deux.

/** Ce qu'un compte peut offrir par jour. */
create or replace function plafond_don_quotidien() returns integer
  language sql immutable
as $$
  select 2;
$$;

/*
 * Offrir des points.
 *
 * Rend (false, motif) plutot que de lever : un plafond atteint est une reponse
 * normale, et l'ecran doit pouvoir dire « vous avez deja offert vos deux points
 * aujourd'hui » plutot qu'afficher une erreur.
 */
create or replace function offrir_points(
  destinataire uuid,
  montant integer
) returns table (ok boolean, reason text)
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  moi     uuid := auth.uid();
  solde   integer;
  deja    integer;
  qui     text;
  plafond integer := plafond_don_quotidien();
begin
  if moi is null then
    return query select false, 'NOT_SIGNED_IN';
    return;
  end if;

  if montant is null or montant <= 0 then
    return query select false, 'INVALID_AMOUNT';
    return;
  end if;

  -- S'offrir a soi-meme ne serait pas une fraude, juste une ecriture inutile
  -- qui salirait les deux journaux.
  if destinataire = moi then
    return query select false, 'SELF_GIFT';
    return;
  end if;

  select p.first_name into qui from profiles p where p.id = destinataire;
  if qui is null then
    return query select false, 'UNKNOWN_RECIPIENT';
    return;
  end if;

  -- Verrou sur le compte donneur : deux dons simultanes se mettent en file au
  -- lieu de passer tous les deux sous le plafond.
  perform 1 from profiles where id = moi for update;

  select coalesce(-sum(delta), 0)::integer into deja
    from point_ledger
   where owner_id = moi
     and delta < 0
     and reference like 'gift:%'
     -- Jour calendaire, et non « 24 heures glissantes » : « vous pourrez
     -- reoffrir demain » se comprend, « dans 7 h 12 » se subit.
     and created_at >= date_trunc('day', now());

  if deja + montant > plafond then
    return query select false, 'DAILY_LIMIT';
    return;
  end if;

  select coalesce(sum(delta), 0)::integer into solde
    from point_ledger where owner_id = moi;

  if solde < montant then
    return query select false, 'NOT_ENOUGH_POINTS';
    return;
  end if;

  -- Les deux ecritures, liees par la meme reference : on peut toujours
  -- rapprocher un debit de son credit, ce qu'une correction manuelle exigera
  -- le jour ou elle arrivera.
  declare
    lien text := 'gift:' || gen_random_uuid()::text;
    monNom text;
  begin
    select coalesce(p.first_name, 'Quelqu''un') into monNom
      from profiles p where p.id = moi;

    insert into point_ledger (owner_id, delta, reason, reference)
         values (moi, -montant, 'Offert à ' || qui, lien);

    insert into point_ledger (owner_id, delta, reason, reference)
         values (destinataire, montant, 'Offert par ' || monNom, lien);
  end;

  return query select true, null::text;
end;
$$;

comment on function offrir_points(uuid, integer) is
  'Transfert plafonne a 2 points par jour et par compte. Les deux ecritures '
  'dans la meme instruction : une panne entre les deux ferait disparaitre des '
  'points ou en inventerait.';
comment on function plafond_don_quotidien() is
  'Deux. A dix, quatre comptes complices concentraient leur monnaie en '
  'quelques jours.';
