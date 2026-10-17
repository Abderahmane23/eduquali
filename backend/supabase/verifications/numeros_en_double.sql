-- Les comptes crees sous une autre forme du meme numero (a lancer une fois).
--
-- --- Pourquoi cette verification ------------------------------------------
--
-- Jusqu'au 17/10, l'adresse qui identifie un compte etait « les chiffres du
-- numero, et rien d'autre ». Le meme numero, tape avec son indicatif ou avec
-- un zero de tete, donnait donc des comptes differents :
--
--     620000101      ->  620000101@telephone.eduquali.gn
--     +224620000101  ->  224620000101@telephone.eduquali.gn
--     0620000101     ->  0620000101@telephone.eduquali.gn
--
-- Les deux clients ramenent maintenant tout numero a ses **neuf chiffres**.
-- Consequence a regarder en face : un compte cree avant ce jour sous une
-- forme longue n'est plus atteignable par la connexion, puisque le client
-- demandera desormais la forme courte. Son proprietaire verra un 400 et dira
-- « mon mot de passe ne marche plus » — ce qui sera vrai, et ce ne sera pas
-- sa faute.
--
-- Cette requete dit combien de comptes sont concernes. A lancer dans
-- l'editeur SQL de Supabase, ou elle ne modifie rien : elle lit.
--
-- --- Ce qu'on en fait -----------------------------------------------------
--
--   * aucune ligne          : rien a faire, personne n'est concerne ;
--   * des lignes « seul »   : corriger l'adresse (voir le bloc commente en
--                             bas), le compte redevient atteignable ;
--   * des lignes « double » : deux comptes pour une personne. Celui qui porte
--                             des donnees (enfants, achats, seances) est
--                             celui qu'on garde ; l'autre se supprime. Ne rien
--                             supprimer sans avoir regarde les deux.

with comptes as (
  select
    id,
    email,
    created_at,
    last_sign_in_at,
    split_part(email, '@', 1) as chiffres
  from auth.users
  where email like '%@telephone.eduquali.gn'
),
normalises as (
  select
    *,
    -- La meme regle que les clients, ecrite en SQL : on pele de l'exterieur
    -- vers l'interieur, et jamais au point de descendre sous neuf chiffres.
    case
      when length(chiffres) > 9 and chiffres like '00%'
        then regexp_replace(chiffres, '^00', '')
      else chiffres
    end as sans_sortie
  from comptes
),
sans_indicatif as (
  select
    *,
    case
      when length(sans_sortie) > 9 and sans_sortie like '224%'
        then substr(sans_sortie, 4)
      else sans_sortie
    end as sans_pays
  from normalises
),
final as (
  select
    *,
    case
      when length(sans_pays) > 9 and sans_pays like '0%'
        then substr(sans_pays, 2)
      else sans_pays
    end as national
  from sans_indicatif
)
select
  national                                  as numero_reel,
  count(*)                                  as comptes,
  case when count(*) > 1 then 'double' else 'seul' end as cas,
  array_agg(email order by created_at)      as adresses,
  array_agg(coalesce(last_sign_in_at::text, 'jamais') order by created_at)
                                            as dernieres_connexions
from final
-- On ne garde que ce qui pose probleme : une adresse qui n'est pas deja
-- reduite aux neuf chiffres, ou plusieurs comptes pour un meme numero.
group by national
having count(*) > 1
    or bool_or(chiffres <> national)
order by comptes desc, numero_reel;

-- --- La correction, quand il n'y a qu'un seul compte ----------------------
--
-- A n'executer qu'apres avoir lu le resultat ci-dessus, et seulement sur les
-- lignes « seul ». Decommentez, et remplacez les deux valeurs.
--
-- update auth.users
--    set email = '620000101@telephone.eduquali.gn'
--  where email = '224620000101@telephone.eduquali.gn';
--
-- `profiles.phone` porte le numero affiche et n'a pas a changer : c'est
-- l'adresse derivee, invisible pour la personne, qui etait fausse.
