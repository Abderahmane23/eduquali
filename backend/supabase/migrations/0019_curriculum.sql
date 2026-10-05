-- Le programme scolaire guinéen en base (03/10).
--
-- --- Ce que ces tables apportent -----------------------------------------
--
-- Jusqu'ici, un cours portait une matière et une classe : « Mathématiques,
-- 10ème ». Utile pour filtrer, insuffisant pour décider. Un parent cherche
-- rarement « des maths » — il cherche **le chapitre que son enfant n'a pas
-- compris** : les fonctions affines, le théorème de Thalès, la nutrition des
-- plantes vertes.
--
-- `curriculum_chapters` met le programme à plat : 348 chapitres et
-- 1 228 sous-chapitres pour 14 matières et 7 classes, de la 7ème à la Terminale.
-- Un cours vidéo ou un cours en direct peut alors **se rattacher à un chapitre
-- du programme**, et c'est ce lien qui rend possible :
--
--   * « qui enseigne Thalès en 9ème ? » — la recherche que les familles font
--     réellement ;
--   * « il me manque le chapitre 4 » — un élève qui sait ce qu'il cherche ;
--   * « ce cours couvre 3 des 16 chapitres de 7ème » — un professeur qui voit
--     son programme avancer.
--
-- --- ⚠ Ce que ces données ne sont pas ------------------------------------
--
-- **Pas le programme officiel du ministère.** Les sources consultées ne
-- contiennent aucune publication ministérielle unique couvrant toutes les
-- matières et toutes les classes ; `shared/curriculum/guinea.json` porte un
-- avertissement que les deux clients affichent, et `content_status` le redit
-- ligne par ligne.
--
-- Cette honnêteté n'est pas une formalité : un professeur qui prépare un cours
-- sur un référentiel faux perd sa séance, et une famille qui l'a payée ne
-- revient pas. La colonne `content_status` et la table `curriculum_sources`
-- existent pour qu'on puisse toujours répondre à « d'où vient ce chapitre ? ».

-- --- Le programme ---------------------------------------------------------

create table if not exists curriculum_chapters (
  id            text primary key default gen_random_uuid()::text,

  -- Le référentiel existant, et non des noms libres : `sub_math`, `lvl_10`.
  -- Une matière inventée ici échouerait sur ces clés étrangères, ce qui est
  -- exactement l'intérêt — `shared/onboarding/sync.mjs` vérifie d'ailleurs la
  -- même chose avant le semis, pour que l'erreur se voie plus tôt.
  subject_id    text not null references subjects (id) on delete cascade,
  level_id      text not null references levels (id) on delete cascade,

  -- Rang du chapitre dans la progression de l'année. C'est l'ordre dans lequel
  -- un professeur l'enseigne, donc celui dans lequel un élève le cherche.
  position      integer not null check (position > 0),

  title         text not null check (length(title) between 2 and 200),
  summary       text,

  /*
   * Les sous-chapitres, en tableau plutôt qu'en table fille.
   *
   * 1 228 lignes pour une donnée qu'on lit **toujours** avec son chapitre et
   * jamais seule : aucune requête n'a de raison de chercher un sous-chapitre
   * sans savoir de quel chapitre il relève. Une table fille aurait ajouté une
   * jointure à chaque lecture du programme pour rien.
   *
   * Si un jour un sous-chapitre doit porter sa propre durée ou son propre
   * support, il devient une entité et mérite sa table. Pas avant.
   */
  subchapters   text[] not null default '{}',

  -- Ce que l'élève doit savoir faire. Présent pour 58 chapitres — la chimie du
  -- collège, seule source du corpus à le donner. Nul ailleurs, et c'est une
  -- information en soi.
  outcome       text,

  -- `complet` | `partiel`. Toutes les entrées valent `partiel` aujourd'hui : les
  -- sources le disent elles-mêmes. La colonne existe pour que ça change par
  -- matière, au fur et à mesure des vérifications, sans migration.
  content_status text not null default 'partiel'
                   check (content_status in ('complet', 'partiel')),

  -- Le fichier d'où vient ce chapitre (`chimie.txt`,
  -- `programme_guineen_college_lycee.json`…). Conservé parce que la question
  -- « d'où vient cette ligne ? » se pose dès qu'un professeur la contredit.
  source_ref    text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Un seul chapitre par rang, matière et classe. C'est ce qui rend le semis
  -- rejouable : il tourne à chaque déploiement sans créer de doublons.
  unique (subject_id, level_id, position)
);

create index if not exists curriculum_chapters_lookup_idx
  on curriculum_chapters (subject_id, level_id, position);

/*
 * La recherche plein texte sur les titres et les sous-chapitres.
 *
 * C'est la requête du produit : « qui enseigne Thalès ? ». Un parent tape le
 * chapitre, pas la matière.
 *
 * --- Pourquoi une colonne et un déclencheur, et non un index d'expression ---
 *
 * La forme évidente ne compile pas : un index GIN pose directement sur
 * `to_tsvector('french', title || ' ' || array_to_string(subchapters, ' '))`
 * échoue sur « functions in index expression must be marked IMMUTABLE ».
 *
 * (L'exemple est écrit en prose et non en SQL à dessein : `check-schema-file.mjs`
 * compte les instructions en cherchant leurs mots-clés dans le texte brut, et un
 * exemple commenté gonflait ce compte d'une unité — sa garde d'auto-aveuglement
 * signalait alors un nettoyage défectueux qui n'avait pas eu lieu.)
 *
 * `to_tsvector(regconfig, text)` est bien immuable — c'est pour cela qu'on passe
 * `'french'` explicitement plutôt que de laisser la configuration par défaut,
 * qui dépend d'un réglage de session. Le coupable est `array_to_string`, qui est
 * **STABLE** : sa signature générique passe par la fonction de sortie du type
 * d'élément, et pour certains types celle-ci dépend de réglages comme
 * `DateStyle`. Pour du `text[]` le résultat serait constant, mais Postgres juge
 * sur la signature, pas sur le cas d'usage.
 *
 * On pourrait emballer l'expression dans une fonction déclarée IMMUTABLE. Ce
 * serait mentir au planificateur, et un index construit sur un mensonge rend des
 * résultats faux sans jamais lever d'erreur — le pire des deux mondes.
 *
 * D'où la colonne maintenue par un déclencheur : c'est le motif documenté de
 * Postgres pour ce cas, et il reste juste quel que soit l'écrivain.
 *
 * `french` et non `simple` : la configuration française ramène « fonctions » et
 * « fonction » au même radical, ce qu'un parent qui tape de mémoire attend.
 */
alter table curriculum_chapters
  add column if not exists search tsvector;

create or replace function curriculum_chapters_search() returns trigger
  language plpgsql
  set search_path = public, pg_catalog
as $$
begin
  new.search := to_tsvector(
    'french',
    coalesce(new.title, '')
      || ' '
      || coalesce(array_to_string(new.subchapters, ' '), '')
      || ' '
      || coalesce(new.summary, '')
  );
  return new;
end;
$$;

drop trigger if exists curriculum_chapters_search_tg on curriculum_chapters;
create trigger curriculum_chapters_search_tg
  before insert or update of title, subchapters, summary
  on curriculum_chapters
  for each row execute function curriculum_chapters_search();

create index if not exists curriculum_chapters_search_idx
  on curriculum_chapters using gin (search);

-- --- Les manuels ----------------------------------------------------------

create table if not exists curriculum_textbooks (
  id            text primary key default gen_random_uuid()::text,

  -- Nul quand le libellé de la source ne correspond à aucune matière du
  -- référentiel (« Sciences physiques et biologie » en couvre deux). On garde
  -- alors `subject_label`, parce qu'un manuel sans matière reste utile à lire.
  subject_id    text references subjects (id) on delete set null,
  subject_label text not null,

  title         text not null,

  -- « 7e à 10e année », tel qu'écrit par la source. Texte et non `level_ids` :
  -- les sources donnent des plages approximatives (« Surtout 9e année »), et les
  -- convertir en identifiants inventerait une précision qu'elles n'ont pas.
  levels_label  text,

  -- « Manuel de référence couramment utilisé », « Manuel complémentaire ».
  -- Conservé parce que c'est cette nuance qui évite d'acheter le mauvais livre.
  status_note   text,

  created_at    timestamptz not null default now(),

  unique (subject_label, title)
);

-- --- La provenance --------------------------------------------------------

create table if not exists curriculum_sources (
  id          text primary key,
  kind        text not null default 'web',
  title       text not null,
  url         text,
  -- À quoi cette source a servi : « français collège », « histoire collège ».
  used_for    text,
  created_at  timestamptz not null default now()
);

-- --- Rattacher un cours à un chapitre du programme -----------------------
--
-- C'est le lien qui fait servir tout ce qui précède. Nul par défaut : un cours
-- n'a pas à se rattacher au programme — du soutien en méthodologie, un cours de
-- préparation au BEPC tous chapitres confondus. Rendre la colonne obligatoire
-- aurait forcé un rattachement faux.

alter table video_courses
  add column if not exists curriculum_chapter_id text
    references curriculum_chapters (id) on delete set null;

alter table live_courses
  add column if not exists curriculum_chapter_id text
    references curriculum_chapters (id) on delete set null;

create index if not exists video_courses_chapter_idx
  on video_courses (curriculum_chapter_id)
  where curriculum_chapter_id is not null;

create index if not exists live_courses_chapter_idx
  on live_courses (curriculum_chapter_id)
  where curriculum_chapter_id is not null;

-- --- Qui voit quoi --------------------------------------------------------

alter table curriculum_chapters  enable row level security;
alter table curriculum_textbooks enable row level security;
alter table curriculum_sources   enable row level security;

/*
 * Le programme est **public**, comme `subjects` et `levels` (0002).
 *
 * C'est un référentiel, pas une donnée de quelqu'un : un parent doit pouvoir
 * chercher « Thalès 9ème » avant d'ouvrir un compte, exactement comme il
 * consulte la grille des cours en direct. Le fermer obligerait à s'inscrire pour
 * savoir s'il y a une raison de s'inscrire.
 *
 * **Aucune politique d'écriture.** Le programme est posé par le semis, sous la
 * clé de service. Laisser un client l'écrire permettrait d'inventer un chapitre
 * officiel — et un faux chapitre dans un référentiel public est une erreur que
 * personne ne saurait attribuer.
 */
create policy "programme : lisible par tous" on curriculum_chapters
  for select using (true);
create policy "manuels : lisibles par tous" on curriculum_textbooks
  for select using (true);
create policy "sources du programme : lisibles par tous" on curriculum_sources
  for select using (true);

comment on table curriculum_chapters is
  'Programme guineen compile (PAS une publication officielle) : voir '
  'content_status et curriculum_sources. Genere depuis '
  'shared/curriculum/guinea.json.';
comment on column curriculum_chapters.subchapters is
  'Tableau et non table fille : toujours lu avec son chapitre, jamais seul.';
comment on table curriculum_textbooks is
  'Manuels de reference. `status_note` distingue reference et complement : la '
  'confusion fait acheter le mauvais livre.';
