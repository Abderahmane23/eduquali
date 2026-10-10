-- Les promotions sont enfin montrees, et comptees pour de vrai (10/10).
--
-- --- Ce qui n'allait pas --------------------------------------------------
--
-- Un etablissement remplit « Faire ma promotion », depose une image, et la
-- promotion part en base avec `status = 'ACTIVE'`. Son espace lui affiche un
-- compteur « Affichages ».
--
-- Ce compteur restait a zero pour toujours, et pour deux raisons :
--
--   1. **aucun ecran ne lisait les promotions actives.** Le fournisseur
--      `activePromotionsProvider` existait sans un seul consommateur, et le
--      seul `PromoCard` affiche etait un bouton fixe « Creer un cours » pour
--      les professeurs. Une promotion n'etait vue par personne ;
--   2. **personne ne pouvait l'incrementer.** La politique
--      « son etablissement la gere » reserve l'ecriture au proprietaire — ce
--      qui est juste : sinon n'importe qui gonflerait le compteur d'un autre.
--      Mais le spectateur, lui, n'est pas l'etablissement.
--
-- Un etablissement payait donc pour un chiffre qui ne bougeait jamais.
--
-- --- Pourquoi une table de vues, et pas un simple +1 --------------------
--
-- « Affichages » est ce que l'etablissement achete : le chiffre doit vouloir
-- dire quelque chose. Incrementer a chaque fois qu'un ecran se redessine
-- compterait les allers-retours entre deux onglets, et le tableau de bord se
-- redessine souvent.
--
-- Une vue par personne et par jour, donc, tenue par une cle unique. Le chiffre
-- devient « combien de personnes l'ont vue », ce qui est la question qu'on se
-- pose en l'achetant.

create table if not exists promotion_views (
  id            text primary key default gen_random_uuid()::text,
  promotion_id  text not null references promotions (id) on delete cascade,

  -- Le compte qui a vu. Pas d'anonyme : une promotion ne s'affiche qu'une
  -- fois connecte, puisqu'elle est posee dans un tableau de bord.
  viewer_id     uuid not null references profiles (id) on delete cascade,

  -- Le jour calendaire, et non un horodatage : c'est lui qui porte l'unicite.
  -- « Une fois par 24 h glissantes » demanderait de comparer a la derniere
  -- vue, donc de la lire avant d'ecrire — deux requetes, et une course entre
  -- deux onglets ouverts.
  day           date not null default current_date,

  created_at    timestamptz not null default now(),

  unique (promotion_id, viewer_id, day)
);

create index if not exists promotion_views_promo_idx
  on promotion_views (promotion_id, day);

/*
 * Enregistre un affichage, et rend vrai si c'en etait un nouveau.
 *
 * `security definer` : le spectateur n'est pas l'etablissement, donc il n'a le
 * droit ni d'ecrire dans `promotion_views` ni de toucher au compteur. La
 * fonction le fait pour lui, et ne lui laisse rien d'autre — elle ne prend
 * aucun identifiant de compte en argument, elle lit `auth.uid()`.
 *
 * Le compteur n'est incremente que si l'insertion a vraiment eu lieu : rejouee
 * dans la journee, la fonction rend faux et ne compte rien.
 */
create or replace function enregistrer_affichage(promo text)
  returns boolean
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  moi     uuid := auth.uid();
  nouveau integer;
begin
  if moi is null then
    return false;
  end if;

  -- Une promotion qui n'est plus active ne se compte plus : sinon un ecran
  -- garde en memoire continuerait d'alimenter un chiffre deja facture.
  if not exists (
    select 1 from promotions p
     where p.id = promo and p.status = 'ACTIVE'
  ) then
    return false;
  end if;

  insert into promotion_views (promotion_id, viewer_id)
       values (promo, moi)
  on conflict (promotion_id, viewer_id, day) do nothing;

  get diagnostics nouveau = row_count;
  if nouveau = 0 then
    return false;
  end if;

  -- Atomique : `views = views + 1` et non une lecture suivie d'une ecriture.
  -- Deux telephones qui ouvrent l'application en meme temps compteraient
  -- sinon pour un seul.
  update promotions
     set views = views + 1, updated_at = now()
   where id = promo;

  return true;
end;
$$;

comment on function enregistrer_affichage(text) is
  'Compte une vue par personne et par jour. Le compteur « Affichages » est ce '
  'que l''etablissement achete : il doit dire combien de personnes ont vu, pas '
  'combien de fois un ecran s''est redessine.';

alter table promotion_views enable row level security;

-- L'etablissement voit le detail des vues de ses propres promotions : c'est la
-- justification du chiffre qu'il paie.
create policy "vues : celles de ses promotions" on promotion_views
  for select using (
    exists (
      select 1 from promotions p
       where p.id = promotion_views.promotion_id
         and p.institution_id = my_institution_id()
    )
  );

-- Aucune politique d'ecriture : tout passe par `enregistrer_affichage`. Un
-- client qui pourrait inserer ici gonflerait le compteur d'un concurrent, ou
-- le sien.
