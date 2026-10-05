-- L'achat d'un cours devient un acte en deux temps (02/10).
--
-- --- Le defaut -------------------------------------------------------------
--
-- `course_purchases` ne portait aucun etat : une ligne existait, donc le cours
-- etait achete. Or il n'y a pas encore d'encaissement — aucun fournisseur de
-- paiement n'est branche. Inserer la ligne au clic aurait donc donne le cours
-- gratuitement a qui appuie sur « Acheter », et `has_bought_course` aurait
-- ouvert les fichiers video dans la seconde.
--
-- --- Ce que cette migration pose ------------------------------------------
--
-- Un etat, et de quoi rattacher la ligne a une transaction chez l'operateur.
-- L'entitlement suit l'etat `PAID`, jamais la simple existence de la ligne.
--
-- Trois etats, et pas quatre : `PENDING` (la demande est enregistree, l'argent
-- n'est pas arrive), `PAID` (il est arrive), `CANCELLED` (elle n'aboutira pas).
-- Un `FAILED` distinct de `CANCELLED` n'apporterait rien : des deux cotes le
-- cours n'est pas du.

alter table course_purchases
  add column if not exists status text not null default 'PENDING'
    check (status in ('PENDING', 'PAID', 'CANCELLED')),

  -- La reference de la transaction chez l'operateur (Orange Money, MTN MoMo).
  -- Nulle tant qu'aucun fournisseur n'est branche ; c'est elle qui permettra
  -- de rapprocher un paiement recu d'une demande enregistree, et de ne pas
  -- creer deux acces pour un seul reglement.
  add column if not exists provider_ref text,

  -- Quel operateur, quand il y en aura un. Non contraint a une liste : la
  -- contrainte devrait etre modifiee a chaque nouvel operateur guineen.
  add column if not exists provider text,

  add column if not exists paid_at timestamptz;

-- Une reference d'operateur ne vaut que si elle est unique : deux lignes
-- portant la meme transaction signifieraient un reglement compte deux fois.
create unique index if not exists course_purchases_provider_ref_idx
  on course_purchases (provider_ref)
  where provider_ref is not null;

create index if not exists course_purchases_pending_idx
  on course_purchases (status, created_at)
  where status = 'PENDING';

-- --- L'entitlement suit le paiement ---------------------------------------
--
-- Le seul changement qui compte dans cette migration. Sans lui, une demande en
-- attente ouvrirait les videos.

create or replace function has_bought_course(course text)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
as $$
  select exists (
    select 1 from course_purchases p
    where p.course_id = course
      and p.parent_id = my_parent_id()
      and p.status = 'PAID'
  );
$$;

-- --- Qui ecrit quoi -------------------------------------------------------
--
-- La politique d'insertion de 0007 laissait l'acheteur ecrire sa ligne,
-- montant compris. Elle est remplacee : **le client ne fixe plus le prix.**
-- Un montant envoye par le navigateur est un montant choisi par le navigateur,
-- et le prix d'un cours se lit dans `video_courses`, pas dans une requete.
--
-- L'insertion passe donc par le serveur (cle `service_role`), qui relit le
-- prix, calcule la commission et pose l'etat. Le client ne garde que la
-- lecture — savoir ou en est sa demande.

drop policy if exists "achat : c est l acheteur qui achete" on course_purchases;

-- Le passage a `PAID` releve du serveur lui aussi : il arrive apres la
-- confirmation de l'operateur, que le client ne peut pas prouver. Aucune
-- politique `update` n'est posee, donc aucune mise a jour n'est possible
-- depuis le navigateur ou le telephone — l'absence est la regle, pas un oubli.

comment on column course_purchases.status is
  'PENDING a la demande, PAID a la confirmation de l''operateur. '
  'L''acces aux videos suit PAID, via has_bought_course().';
