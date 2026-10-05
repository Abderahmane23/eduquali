-- Fiche detaillee d'un etablissement (§19).
--
-- Chaine : 0001 schema -> 0002 rls -> 0003 audit -> 0004 inscriptions
--          -> 0005 fiche etablissement.
--
-- Ce qu'un candidat ou un parent regarde avant de s'engager : depuis quand
-- l'etablissement existe, qui le tient, ce qu'on y etudie et ce qu'on y
-- trouve. Colonnes additives : sans risque sur une base en service.
--
-- Les listes restent des chaines separees par des virgules plutot que des
-- tables. C'est une donnee d'affichage : on ne cherche jamais « tous les
-- etablissements qui enseignent le droit » depuis cet ecran, et une table de
-- liaison par filiere couterait une jointure pour rien. A revoir le jour ou
-- la recherche par filiere existe.

alter table institutions
  -- Les etablissements publient souvent deux numeros.
  add column if not exists phone           text,
  add column if not exists phone_alt       text,
  add column if not exists email           text,
  add column if not exists website         text,
  add column if not exists founded_year    integer
    check (founded_year is null or founded_year between 1800 and 2200),
  -- PUBLIC ou PRIVATE.
  add column if not exists ownership       text
    check (ownership is null or ownership in ('PUBLIC', 'PRIVATE')),
  -- « LMD » pour le superieur, « SECONDAIRE », « PROFESSIONNEL »...
  add column if not exists academic_system text,
  -- BTS, LICENCE, MASTER, DOCTORAT, CAP, BAC...
  add column if not exists degrees         text not null default '',
  add column if not exists specialties     text not null default '',
  add column if not exists facilities      text not null default '';

create index if not exists institutions_ownership_idx
  on institutions (ownership, city);
