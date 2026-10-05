-- Enseignants de demonstration.
--
-- A appliquer APRES avoir cree les comptes correspondants via
-- l’inscription par OTP : une fiche enseignant reference un compte
-- `auth.users`, que seule l’authentification peut creer.
--
-- Renseignez ci-dessous l’identifiant du compte, puis executez.

-- Mamadou Diallo — Enseignant en Mathematiques
-- select seed_demo_teacher('<uuid du compte>', 'tch_mamadou');
-- Ibrahima Bah — Enseignant en Mathematiques et Physique
-- select seed_demo_teacher('<uuid du compte>', 'tch_ibrahima');
-- Fatoumata Camara — Enseignante de Physique-Chimie
-- select seed_demo_teacher('<uuid du compte>', 'tch_fatoumata');
-- Aissatou Barry — Formatrice en Informatique
-- select seed_demo_teacher('<uuid du compte>', 'tch_aissatou');
-- Ousmane Sylla — Professeur de Chimie
-- select seed_demo_teacher('<uuid du compte>', 'tch_ousmane');
-- Mariama Conde — Professeure de Francais
-- select seed_demo_teacher('<uuid du compte>', 'tch_mariama');
-- Sekou Toure — Enseignant de Mathematiques
-- select seed_demo_teacher('<uuid du compte>', 'tch_sekou');
-- Kadiatou Sow — Enseignante d'Anglais
-- select seed_demo_teacher('<uuid du compte>', 'tch_kadiatou');
-- Fatoumata Dioubate — Enseignante en Sciences politiques
-- select seed_demo_teacher('<uuid du compte>', 'tch_fatoumata_dioubate');
-- Sekou Cisse — Enseignant en Télécommunications
-- select seed_demo_teacher('<uuid du compte>', 'tch_sekou_cisse');
-- Kadiatou Bah — Enseignante en Génie électrique
-- select seed_demo_teacher('<uuid du compte>', 'tch_kadiatou_bah');
-- Thierno Keita — Enseignant en Génie civil
-- select seed_demo_teacher('<uuid du compte>', 'tch_thierno_keita');
-- Nene Balde — Enseignante en Marketing
-- select seed_demo_teacher('<uuid du compte>', 'tch_nene_balde');
-- Mamadou Yansane — Enseignant en Gestion
-- select seed_demo_teacher('<uuid du compte>', 'tch_mamadou_yansane');
-- Binta Sow — Enseignante en Pharmacie
-- select seed_demo_teacher('<uuid du compte>', 'tch_binta_sow');
-- Amadou Diallo — Enseignant en Médecine
-- select seed_demo_teacher('<uuid du compte>', 'tch_amadou_diallo');
-- Adama Sow — Enseignante en Éducation physique et sportive
-- select seed_demo_teacher('<uuid du compte>', 'tch_adama_sow');
-- Lansana Sow — Enseignant en Éducation civique et morale
-- select seed_demo_teacher('<uuid du compte>', 'tch_lansana_sow');
-- Fatoumata Bangoura — Enseignante en Philosophie
-- select seed_demo_teacher('<uuid du compte>', 'tch_fatoumata_bangoura');
-- Sekou Kaba — Enseignant en Geologie
-- select seed_demo_teacher('<uuid du compte>', 'tch_sekou_kaba');
-- Saran Soumah — Enseignante en Biologie
-- select seed_demo_teacher('<uuid du compte>', 'tch_saran_soumah');
-- Facinet Sidibe — Enseignant en Geographie
-- select seed_demo_teacher('<uuid du compte>', 'tch_facinet_sidibe');
-- Binta Doumbouya — Enseignante en Histoire
-- select seed_demo_teacher('<uuid du compte>', 'tch_binta_doumbouya');
-- Facinet Soumah — Enseignant en Droit
-- select seed_demo_teacher('<uuid du compte>', 'tch_facinet_soumah');
-- Mariama Traore — Enseignante en Comptabilite
-- select seed_demo_teacher('<uuid du compte>', 'tch_mariama_traore');
-- Lansana Yansane — Enseignant en Economie
-- select seed_demo_teacher('<uuid du compte>', 'tch_lansana_yansane');
-- Oumou Cisse — Enseignante en Informatique
-- select seed_demo_teacher('<uuid du compte>', 'tch_oumou_cisse');
-- Ibrahima Conde — Enseignant en Anglais
-- select seed_demo_teacher('<uuid du compte>', 'tch_ibrahima_conde');
-- Hawa Traore — Enseignante en Francais
-- select seed_demo_teacher('<uuid du compte>', 'tch_hawa_traore');
-- Mamadou Diakite — Enseignant en Chimie
-- select seed_demo_teacher('<uuid du compte>', 'tch_mamadou_diakite');

create or replace function seed_demo_teacher(account uuid, teacher text)
returns void as $$
begin
  -- Laisse au deploiement le soin de rattacher la fiche au compte cree.
  update teachers set user_id = account where id = teacher;
end;
$$ language plpgsql;