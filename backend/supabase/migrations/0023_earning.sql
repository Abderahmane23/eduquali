-- Gagner des points en apprenant (04/10) — la source qui manquait.
--
-- --- Le defaut que ceci corrige ------------------------------------------
--
-- Depuis le 03/10, la seule facon de gagner un point etait de remporter un
-- concours hebdomadaire. Un eleve qui n'en fait pas n'en aurait jamais tenu un
-- seul, et la boutique lui montrait des lots sans aucun chemin pour les
-- atteindre. Une monnaie sans source est un decor.
--
-- --- Pourquoi des declencheurs et non du code serveur --------------------
--
-- Les evenements qui meritent des points sont ecrits par **deux chemins
-- differents** : la presence vient des webhooks LiveKit, donc du serveur ; la
-- reponse a un point de controle est ecrite par le telephone lui-meme, sous
-- RLS. Mettre la regle dans le Worker ne crediterait que la moitie des cas.
--
-- Un declencheur couvre les deux, et c'est le meme raisonnement que pour
-- `point_ledger_no_rewrite` : ce qui doit valoir pour tout le monde se met dans
-- la base, pas dans un appelant.
--
-- --- Pourquoi on ne peut pas tricher -------------------------------------
--
-- Aucun de ces evenements n'est declare par le client :
--
--   * les minutes de presence sont comptees par le serveur de visioconference ;
--   * la reponse a un point de controle exige une place payee et un vote encore
--     ouvert, verifies par la politique d'insertion de 0018.
--
-- On ne peut donc pas moissonner des points en cliquant. C'est la difference
-- avec les plateformes ou l'XP recompense le fait d'avoir appuye sur
-- « continuer ».

-- Un point tous les cinq minutes de presence : une seance de 90 minutes en
-- rapporte 18. Assez pour voir le compteur bouger, trop peu pour que rester
-- connecte sans rien faire devienne une strategie.
create or replace function points_pour_minutes(minutes integer)
  returns integer
  language sql
  immutable
as $$
  select greatest(0, coalesce(minutes, 0) / 5);
$$;

/*
 * Crediter sans jamais crediter deux fois.
 *
 * Chaque gain porte une `reference` qui decrit l'evenement exact — la ligne de
 * presence, le vote. La fonction regarde si cette reference a deja paye avant
 * d'ecrire : un webhook rejoue par LiveKit, ou une mise a jour de presence qui
 * repasse, ne doit pas doubler les points.
 *
 * `security definer` : `point_ledger` n'a aucune politique d'ecriture, et c'est
 * voulu. Le declencheur ecrit donc avec les droits du proprietaire, ce qui
 * laisse la table fermee aux clients tout en permettant a la base de crediter.
 */
create or replace function crediter_points(
  beneficiaire uuid,
  montant integer,
  motif text,
  cle text
) returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
begin
  if beneficiaire is null or montant is null or montant <= 0 then
    return;
  end if;

  -- `delta <> 0` est une contrainte de la table : un gain nul ferait echouer
  -- l'operation qui l'a provoque — une sortie de salle, un vote — et c'est elle
  -- qui compte le plus.
  if exists (select 1 from point_ledger where reference = cle) then
    return;
  end if;

  insert into point_ledger (owner_id, delta, reason, reference)
       values (beneficiaire, montant, motif, cle);
end;
$$;

-- --- 1. Les cent points de bienvenue ---------------------------------------
--
-- Offerts a la creation du profil, quel que soit le chemin : inscription depuis
-- le telephone, depuis le site, ou creation a la main dans l'editeur SQL. Un
-- declencheur les couvre tous.
--
-- **Ils ne suffisent a rien acheter**, et c'est deliberé : le plus petit lot en
-- coute 250. Sinon creer des comptes deviendrait une facon de recolter des
-- forfaits internet, et le premier a le comprendre ne serait pas un eleve.
-- Leur role est de montrer un compteur qui n'est pas a zero le premier jour.
create or replace function accorder_points_bienvenue() returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
begin
  perform crediter_points(
    new.id, 100, 'Bienvenue sur Eduquali', 'welcome:' || new.id
  );
  return new;
end;
$$;

drop trigger if exists profiles_bienvenue on profiles;
create trigger profiles_bienvenue
  after insert on profiles
  for each row execute function accorder_points_bienvenue();

-- --- 2. La presence en seance ----------------------------------------------
--
-- Au moment ou la presence se ferme, et pas a l'entree : sinon rejoindre puis
-- partir aussitot paierait autant qu'assister.
create or replace function accorder_points_presence() returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  gagnes integer := points_pour_minutes(new.minutes);
begin
  perform crediter_points(
    new.user_id,
    gagnes,
    'Séance suivie — ' || coalesce(new.minutes, 0) || ' minutes',
    'attendance:' || new.id
  );
  return new;
end;
$$;

drop trigger if exists attendance_points on session_attendance;
create trigger attendance_points
  after update on session_attendance
  for each row
  -- Uniquement au passage de « en cours » a « terminee ». Sans cette garde, une
  -- correction ulterieure des minutes rejouerait le credit.
  when (old.left_at is null and new.left_at is not null)
  execute function accorder_points_presence();

-- --- 3. Repondre a un point de controle ------------------------------------
--
-- Deux points par vote, quatre votes par seance : huit points, soit a peu pres
-- la moitie de ce que rapporte la presence. Repondre compte, mais rester et
-- suivre compte davantage.
--
-- Le gain ne depend pas de la reponse donnee. Payer « oui » plus que « non »
-- apprendrait a dire qu'on a compris, et le professeur lirait un tableau faux —
-- ce que le resume de 0018 est justement cense eviter.
create or replace function accorder_points_checkpoint() returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  beneficiaire uuid;
begin
  -- La place payee porte le parent ; le parent porte le compte.
  select p.user_id into beneficiaire
    from session_enrolments e
    join parents p on p.id = e.parent_id
   where e.id = new.enrolment_id;

  perform crediter_points(
    beneficiaire,
    2,
    'Participation en séance',
    'checkpoint:' || new.checkpoint_id || ':' || new.enrolment_id
  );
  return new;
end;
$$;

drop trigger if exists checkpoint_points on checkpoint_answers;
create trigger checkpoint_points
  after insert on checkpoint_answers
  for each row execute function accorder_points_checkpoint();

comment on function crediter_points(uuid, integer, text, text) is
  'Credite une fois et une seule : la reference decrit l''evenement, et un '
  'webhook rejoue ne doit pas doubler les points.';
comment on function points_pour_minutes(integer) is
  'Un point par tranche de cinq minutes. Une seance de 90 minutes en vaut 18.';
