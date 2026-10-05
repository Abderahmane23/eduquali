-- Programme scolaire guineen — GENERE, ne pas modifier a la main.
--
-- Source : shared/curriculum/guinea.json, lui-meme construit par
-- shared/curriculum/build.mjs depuis ressource_matières/.
--
-- ⚠ CE N EST PAS UNE PUBLICATION OFFICIELLE DU MINISTERE. Les sources
-- consultees ne contiennent pas de programme ministeriel unique couvrant
-- toutes les matieres et toutes les classes. Chaque ligne porte son
-- content_status et sa source.
--
-- Rejouable : les `on conflict` mettent a jour au lieu d echouer, donc ce
-- fichier se repasse sur une base en service quand le programme change.

begin;

-- Provenance des donnees
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_structure', 'web', 'Arrêté portant règlements généraux des examens scolaires en République de Guinée', 'https://mepua.gov.gn/file/2023/02/Arrete-portant-reglements-generaux-des-examens-scoalires-en-Rep-1.pdf', 'structure des examens et séries du baccalauréat')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_fr_college', 'web', 'Programmes de Français au Collège en Guinée', 'https://fr.scribd.com/document/655654503/PROGRAMMES-FRANCAIS-COLLEGE', 'français collège')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_fr_lycee', 'web', 'Programmes de Français au Lycée en Guinée', 'https://fr.scribd.com/document/919828247/Programme-de-Francais-Au-Lycee', 'français lycée')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_histoire_college', 'web', 'Programmes d''Histoire au Collège en Guinée — INRAP, octobre 2009', 'https://fr.scribd.com/document/725568560/Histoire-College-prog-finalise', 'histoire collège')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_geo_college', 'web', 'Programmes de Géographie au Collège en Guinée — INRAP, octobre 2009', 'https://fr.scribd.com/document/836267738/Ge-ogr-Colle-ge', 'géographie collège')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_phys_college', 'web', 'Programmes de Physique au Collège en Guinée — INRAP, octobre 2009', 'https://fr.scribd.com/document/931751268/Phys-coll', 'physique/chimie collège')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_anglais', 'web', 'Programme d''Anglais au Collège en Guinée', 'https://fr.scribd.com/document/792022854/proganglaiscollege', 'progression MOBEL 1 à MOBEL 7')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_math_7', 'web', 'Plan de progression annuelle des mathématiques — 7ème année, 2025-2026', 'https://fr.scribd.com/document/940211161/Plan-de-progression-7-eme-A-Maths-2025-2026-1', 'mathématiques 7ème')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_math_12', 'web', 'Répartition annuelle mathématiques — 12ème SM, 2025-2026', 'https://fr.scribd.com/document/930868507/12e-SM-PLANIFICATION-2025-2026', 'mathématiques 12ème SM')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_math_term', 'web', 'Répartition annuelle mathématiques — Terminale SM, 2025-2026', 'https://de.scribd.com/document/931745428/Tsm-Planification-2025-2026', 'mathématiques Terminale SM')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_phys_11', 'web', 'Programme de physique 11ème année SE/SM', 'https://fr.scribd.com/document/935394760/PHYS-11-Enregistre-Auto', 'physique 11ème SM/SE')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_chim_11', 'web', 'Programme de chimie 11ème SE/SM', 'https://fr.scribd.com/document/691135693/Chimie-Lycee-2009', 'chimie 11ème')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_bio_lycee', 'web', 'Programmes de Biologie au Lycée en Guinée', 'https://fr.scribd.com/document/953817096/Programme-Bio-Lycee', 'biologie 11ème/12ème/Terminale')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_hist_lycee', 'web', 'Programmes d''Histoire au Lycée en Guinée', 'https://fr.scribd.com/document/885446375/CONTENUS-PROGRAMMES-D-HISTOIRE-LYCEE2', 'histoire lycée')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_philo', 'web', 'Éléments de contenus devant alimenter les programmes de philosophie au lycée', 'https://fr.scribd.com/document/925181449/CONTENUS-PROGRAMMES-DE-PHILOSOPHIE-LYCEE2', 'philosophie 11ème et lycée')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;
insert into curriculum_sources (id, kind, title, url, used_for) values ('src_exam_2026', 'web', 'Baccalauréat unique 2026 — lancement officiel', 'https://primature.gov.gn/baccalaureat-unique-2026-le-premier-ministre-lance-officiellement-les-premieres-epreuves-a-maferinyah/', 'session 2026')
  on conflict (id) do update set title = excluded.title, url = excluded.url, used_for = excluded.used_for;

-- Chapitres du programme
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 1, 'Thèmes de lecture et d''élocution', null, array['L''école', 'La rentrée scolaire, mon école, la vie à l''école', 'Les jeux et sports', 'Jeux d''enfants, sports individuels/collectifs, compétitions', 'La famille', 'Vie en famille, parents, famille nucléaire/élargie, joies et peines', 'Le travail des jeunes', 'Satisfaction du travail bien fait, apprentissage d''un métier', 'Les fêtes', 'Religieuses, familiales, scolaires, nationales, internationales', 'Les paysages naturels', 'Savane, forêt, montagne, cours d''eau, mer', 'Les animaux', 'Domestiques, sauvages, espèces protégées', 'Les loisirs', 'Pêche, chasse, lecture', 'Le courrier', 'Poste, lettre, télégramme, courriels, SMS', 'Les voyages', 'Moyens de locomotion, départs, arrivées, paysages', 'Protection de l''environnement', 'Lutte contre feux de brousse, pollution', 'Œuvres de référence : Contes d''Amadou Koumba (Birago DIOP), L''enfant noir (CAMARA Laye), L''indigo, Le manguier']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 2, 'Grammaire', null, array['Chapitre 1 : Généralités', 'Situation de communication (langage oral, écrit, sonore, gestuel, visuel)', 'La ponctuation', 'Phonétique', 'Chapitre 2 : La phrase simple - Types et formes', 'Formes affirmatives et négatives', 'Types de phrases : déclarative, interrogative, impérative, exclamative', 'Chapitre 3 : Les constituants de la phrase simple - Le Groupe Nominal (GN)', 'Décomposition du GN, pivot', 'Déterminants (définis, indéfinis)', 'Le nom : classification, forme, genre, nombre', 'L''adjectif qualificatif : place et forme', 'Complément déterminatif, apposition', 'Chapitre 4 : Le Groupe Verbal (GV)', 'Définition et rôle', 'Variation en fonction du sujet et des temps', 'Verbes d''état et verbes d''action', 'Compléments essentiels (COD, COI)', 'Compléments non essentiels (COS, CC)', 'L''attribut', 'L''adverbe', 'Chapitre 5 : De la phrase simple à la phrase complexe', 'Coordination, juxtaposition, subordination', 'La proposition subordonnée relative']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 3, 'Conjugaison', null, array['Objectifs', 'Distinguer radical et désinence', 'Identifier et conjuguer tous les verbes aux divers temps de l''indicatif', 'Employer le temps qui convient (imparfait/passé simple dans un récit, présent de narration)', 'Utiliser correctement les auxiliaires', 'Contenu', 'Morphologie du verbe', 'Les temps et les modes', 'L''indicatif et les auxiliaires (être, avoir)', 'Valeurs des temps de l''indicatif']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 4, 'Vocabulaire', null, array['Objectifs', 'Identifier radical, préfixe, suffixe', 'Donner les mots de la même famille', 'Repérer le champ lexical dominant', 'Établir le champ sémantique d''un mot courant', 'Employer les principaux connecteurs temporels', 'Contenu', 'Les mots radicaux et la dérivation', 'Les familles de mots (du radical aux dérivés)', 'Formation des verbes, adjectifs, noms, adverbes', 'Sens propre et sens figuré', 'Expressions et locutions figées, proverbes', 'Utilisation du dictionnaire', 'Notions de stylistique : personnification, comparaison']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 5, 'Orthographe', null, array['Accords dans le groupe nominal', 'Accord sujet-verbe', 'Homophones grammaticaux (son/sont, ces/ses, mais/mes...)', 'Pluriels des noms (-aux, -eux, -oux)', 'Ponctuation']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 6, 'Expression écrite', null, array['Types de textes', 'Le texte narratif (le récit)', 'La description et le portrait', 'La lettre simple', 'Le compte rendu', 'Techniques', 'Organisation des idées', 'Paragraphes', 'Utilisation des connecteurs temporels et logiques']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_7', 7, 'Lecture', null, array['Perception globale du texte', 'Analyse détaillée', 'Synthèse', 'Lecture suivie : découverte d''une œuvre complète ou d''extraits significatifs', 'Lecture silencieuse : compréhension générale et approfondie (QCM, textes lacunaires, puzzles...)']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_8', 1, 'Thèmes de lecture et d''élocution', null, array['Les besoins fondamentaux', 'Alimentation, logement, habillement, instruction', 'Le temps', 'Saisons (sèche, hivernage), effets du climat', 'Le jour et la nuit', 'Aube, jour, coucher du soleil, nuit, lune, obscurité', 'Les jeux et sports', 'Collectifs, individuels, activités ludiques, jeux traditionnels', 'Le travail des enfants', 'Activités à la maison, à l''école, pendant les vacances', 'Les communications', 'Téléphone, fax, internet, TIC', 'Les voyages', 'Départ, voyage, arrivée, accueil, découverte', 'À la découverte d''autres horizons', 'Autre monde, autres hommes, autres cultures', 'Les âges de la vie', 'Marques de la jeunesse, marques de la vieillesse', 'Œuvres de référence : Climbié (Bernard DADIE), Lieutenant de Kouta (Mansa Makan DIABATE), L''indigo, Le manguier']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_8', 2, 'Grammaire', null, array['Chapitre 1 : Étude du verbe et de la subordination', 'Phonétique, prononciation, orthographe', 'Constituants de la phrase simple', 'Fonctions du nom et de l''adjectif qualificatif', 'Chapitre 2 : Le Groupe Nominal', 'Déterminants définis et indéfinis', 'Degrés de signification de l''adjectif (comparatif, superlatif)', 'Substituts du nom : pronoms personnels (sujet, complément), autres pronoms', 'Chapitre 3 : Le Verbe', 'Verbes transitifs et intransitifs', 'Verbes pronominaux', 'Voix passive et voix active', 'Verbes impersonnels', 'Modes du verbe : indicatif, subjonctif, conditionnel, impératif, participe, infinitif', 'Chapitre 4 : La Subordination', 'De la phrase simple à la phrase complexe', 'Proposition subordonnée relative (pronoms relatifs : forme et fonction)', 'Proposition subordonnée complétive introduite par « que »', 'Proposition subordonnée interrogative', 'Proposition subordonnée infinitive', 'Proposition subordonnée participiale', 'Mots variables et invariables']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_8', 3, 'Conjugaison', null, array['Objectifs', 'Conjuguer à l''impératif présent, subjonctif présent, conditionnel présent', 'Identifier mode et temps des formes verbales rencontrées', 'Lier chronologiquement des actions (antériorité, postériorité)', 'Conjuguer aux temps composés', 'Contenu', 'Subjonctif et conditionnel', 'Mode impératif', 'Auxiliaires et semi-auxiliaires', 'Temps composés (passé composé, plus-que-parfait, passé antérieur, futur antérieur)']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_8', 4, 'Vocabulaire', null, array['Objectifs', 'Utiliser différents dictionnaires', 'Identifier le vocabulaire de la vie affective, des arts et des techniques', 'Reconnaître les figures de style : métaphore, comparaison, personnification', 'Contenu', 'Étude des champs lexicaux', 'Familles de mots', 'Suffixes (verbal, nominal, adverbial)', 'Préfixes (formes courantes)', 'Synonymes et antonymes', 'Niveaux de langue : choix du lexique', 'Stylistique : personnification, comparaison, métaphore']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_9', 1, 'Thèmes de lecture et d''élocution', null, array['La vie en société', 'Conditions de vie, compréhension mutuelle, solidarité, travail collectif, tolérance, respect d''autrui', 'Les métiers', 'Travail manuel/intellectuel, complémentarité, choix d''un métier, conscience professionnelle, discipline', 'Les loisirs', 'Individuels ou collectifs, théâtre, musique, danses traditionnelles, cinéma', 'Les moyens d''information', 'Lettre, journal, radio, télévision, vidéo, cinéma, internet, téléphone', 'Les mouvements de population', 'Migrations, immigration, exode rural, tourisme, commerce', 'La sécheresse', 'Désertification, reboisement (fête de l''arbre)', 'Œuvres de référence : À l''écoute du monde (4ème année), Indigo – Français 4ème, Le manguier 4ème']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_9', 2, 'Grammaire', null, array['Chapitre 1 : Révisions générales', 'Le groupe nominal : pronom, pronominalisation, déterminants', 'Les groupes fonctionnels', 'Chapitre 2 : Le Verbe', 'Auxiliaires et périphrases verbales', 'Opposition temps/aspects', 'Valeurs temps/aspects : l''indicatif', 'Temps simples et composés (présent, passé composé/surcomposé)', 'Temps simples et composés (passé simple, imparfait, plus-que-parfait, passé antérieur)', 'Le subjonctif : formes et emplois', 'Le participe, l''infinitif', 'Chapitre 3 : La Phrase simple', 'Différents types de phrases', 'Différentes formes : phrase sans verbe, phrase négative', 'Mise en relief, phrase emphatique', 'Chapitre 4 : La Phrase complexe', 'Coordination : mots coordonnés (conjonctions, adverbes)', 'Subordination : mots subordonnants', 'Proposition subordonnée de temps', 'Proposition subordonnée de cause', 'Proposition subordonnée de conséquence', 'Proposition subordonnée de but', 'Proposition subordonnée de condition', 'Proposition subordonnée de comparaison', 'Subordonnées participiales et infinitives', 'Discours direct, indirect, indirect libre']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_9', 3, 'Conjugaison', null, array['Objectifs', 'Conjuguer tous les verbes à tous les temps et tous les modes', 'Utiliser à bon escient indicatif ou subjonctif dans des phrases complexes', 'Déterminer la valeur modale des modes', 'Traduire la chronologie des faits (concordance des temps)', 'Contenu', 'Révision des prérequis', 'Concordance des temps', 'Valeur et emplois des temps', 'Verbes irréguliers', 'Formes rares', 'Infinitif et participe']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_9', 4, 'Vocabulaire', null, array['Objectifs', 'Chercher l''acception d''un mot dans son contexte (polysémie)', 'Donner des homonymes et les employer correctement', 'Employer conjonctions de coordination et de subordination', 'Exploiter les champs lexicaux de la vie affective et intellectuelle', 'Contenu', 'Utilisation des différents dictionnaires', 'Initiation au vocabulaire journalistique (titres, types de phrase, types de journaux)', 'Initiation au vocabulaire spécialisé (judiciaire, militaire, paramilitaire)', 'Stylistique : la métaphore', 'Supports : langage publicitaire, journaux, publicités, textes littéraires']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_10', 1, 'Thèmes de lecture et d''élocution', null, array['Les âges de la vie', 'Enfance, adolescence, âge adulte, vieillesse, conflits de génération', 'La famille', 'Cérémonies familiales, mariage, naissance, baptême, décès, héritage', 'L''éducation', 'Éducation traditionnelle, éducation moderne', 'Le folklore', 'Instruments de musique, chants et danses', 'Les traditions orales', 'Proverbes, devinettes, fables, contes, légendes, mythes', 'Tradition et modernisme', 'Pratiques traditionnelles (habillement, alimentation), pratiques modernes, mirages de la ville', 'Œuvres de référence : Le Manguier 10ème, Indigo français 3ème, L''enfant noir (CAMARA Laye), Triballiques (Henri LOPES), Le vieux nègre et la médaille (Ferdinand OYONO)']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_10', 2, 'Grammaire', null, array['La phrase complexe (tous types de subordonnées)', 'La concordance des temps (indicatif, subjonctif)', 'Les transformations grammaticales (voix passive/active, discours rapporté)', 'Les classes grammaticales et leurs fonctions', 'L''analyse logique et grammaticale complète']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_10', 3, 'Conjugaison', null, array['Objectifs', 'Conjuguer à tous les temps et modes les verbes irréguliers (par paires : craindre/peindre, répondre/perdre, fuir/croire, ouvrir/cueillir, mentir/sentir, coudre/résoudre, rire/conclure...)', 'Justifier l''emploi des modes utilisés dans un texte', 'Employer à bon escient le mode requis par le sens ou les contraintes syntaxiques', 'Conjuguer aux temps composés', 'Contenu', 'Concordance des temps (révision approfondie)', 'Valeur et emplois des temps', 'Verbes irréguliers (liste complète)', 'Formes rares', 'Infinitif et participe (emplois variés)']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_10', 4, 'Vocabulaire', null, array['Objectifs', 'Découvrir et employer les premiers éléments du lexique littéraire (métaphore, métonymie...)', 'Élaborer le champ sémantique d''un mot', 'Exploiter les champs lexicaux de la vie sociale, des relations logiques', 'Grouper des mots par familles étymologiques ou analogiques', 'Rapprocher et opposer des mots (homonymes, paronymes, synonymes, antonymes)', 'Reconnaître les aspects appréciatifs et dépréciatifs (ton)', 'Percevoir connotation, dénotation, polysémie', 'Contenu', 'Révision générale des notions de 7ème à 9ème', 'Utilisation des différents dictionnaires', 'Vocabulaire journalistique et spécialisé', 'Stylistique littéraire']::text[], null, 'partiel', 'Français - lycée.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_11', 1, 'Introduction à l''étude de la littérature', 'Entrée dans l''étude littéraire et distinction des principales formes.', array['Littérature orale', 'Littérature écrite', 'Notions de genres littéraires']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_11', 2, 'Techniques d''expression', 'Développement des capacités de synthèse, d''analyse et d''expression organisée.', array['Résumé de texte', 'Explication de texte', 'Commentaire composé', 'Dissertation / devoir d''idées', 'Exposé, rapport, compte-rendu, procès-verbal']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_11', 3, 'Langue', 'Réinvestissement de la grammaire, orthographe, conjugaison et vocabulaire selon les besoins des élèves.', array['Constituants de la phrase simple', 'Fonctions grammaticales', 'Accord des participes passés', 'Synonymes, paronymes, antonymes', 'Familles étymologiques', 'Nuances du lexique', 'Expressions idiomatiques et proverbiales']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_11', 4, 'Courants et culture littéraires', 'Première approche des grands courants et des littératures étudiées.', array['Humanisme', 'Classicisme', 'Romantisme', 'Littérature africaine', 'Littérature française']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_12', 1, 'Littérature et civilisation', 'Approfondissement de la culture littéraire et de son contexte historique et civilisationnel.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_12', 2, 'Techniques d''expression', 'Maîtrise progressive du résumé, de l''explication, du commentaire et de la dissertation.', array['Résumé', 'Explication de texte', 'Commentaire composé', 'Dissertation']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_12', 3, 'Étude de la langue', 'Consolidation ciblée des compétences linguistiques.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_terminale', 1, 'Littérature', 'Étude d''œuvres et de courants littéraires, avec une place importante donnée aux littératures africaines et étrangères selon le profil.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_fran', 'lvl_terminale', 2, 'Techniques d''expression et préparation à l''examen', 'Mobilisation des méthodes de résumé, commentaire, explication et dissertation.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 1, 'Arithmétique', null, array['Nombres entiers naturels', 'multiples et diviseurs', 'critères de divisibilité par 2, 3, 5, 9, 10, 100 et 1 000']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 2, 'Fractions', null, array['Écritures fractionnaires', 'simplification', 'écriture fractionnaire d’un nombre décimal', 'addition et soustraction de fractions de même dénominateur', 'produit d’un entier naturel par une fraction']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 3, 'Nombres décimaux', null, array['Addition, soustraction, multiplication, division', 'comparaison', 'ordre de grandeur', 'valeur approchée']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 4, 'Nombres relatifs', null, array['Introduction des décimaux relatifs', 'ensembles D et Z', 'opposé d’un nombre', 'somme d’entiers relatifs']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 5, 'Calcul littéral', null, array['Priorités opératoires', 'parenthèses', 'propriétés de l’addition et de la multiplication', 'premières expressions littérales liées aux périmètres, aires et volumes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 6, 'Équations et inéquations', null, array['Équations simples de type a+x=b ou ax=b', 'recherche de nombres vérifiant des inégalités simples']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 7, 'Proportionnalité', null, array['Tableaux de proportionnalité', 'coefficient de proportionnalité', 'pourcentage', 'échelle']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 8, 'Statistiques', null, array['Lecture et interprétation de graphiques simples']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 9, 'Droites et segments', null, array['Droite, demi-droite, alignement', 'droites sécantes, perpendiculaires et parallèles', 'segment', 'longueur', 'milieu', 'médiatrice']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 10, 'Angles', null, array['Vocabulaire', 'mesure en degrés', 'angles adjacents, complémentaires et supplémentaires', 'bissectrice']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 11, 'Triangles', null, array['Vocabulaire', 'triangles particuliers', 'hauteur, médiatrice, bissectrice', 'périmètre et aire']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 12, 'Cercles', null, array['Centre, rayon, diamètre, corde', 'périmètre du cercle', 'aire du disque']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 13, 'Quadrilatères', null, array['Parallélogramme', 'propriétés des côtés et diagonales', 'losange, rectangle et carré', 'périmètres et aires']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 14, 'Solides', null, array['Cube, pavé droit et cylindre', 'vocabulaire', 'patrons', 'aires latérales et totales', 'volumes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 15, 'Symétries', null, array['Symétrie axiale', 'symétrie centrale', 'construction de symétriques de points, segments, droites et angles', 'axe et centre de symétrie']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_7', 16, 'Repérage', null, array['Demi-droite graduée', 'droite graduée', 'origine, unité et abscisse', 'placement et lecture de points']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 1, 'Arithmétique', null, array['Division euclidienne', 'nombres premiers', 'décomposition en facteurs premiers', 'recherche de multiples et de diviseurs', 'PPCM et PGCD']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 2, 'Fractions', null, array['Fractions irréductibles', 'simplification', 'comparaison à l’unité', 'encadrement entre deux décimaux', 'somme et différence de fractions de dénominateurs différents', 'produit de fractions']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 3, 'Nombres relatifs', null, array['Addition, soustraction, multiplication et comparaison de nombres décimaux relatifs']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 4, 'Calcul littéral', null, array['Valeur numérique d’une expression', 'développement de \(a(x+y)\)', 'réduction de termes semblables', 'factorisation de ax+bx']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 5, 'Équations et inéquations', null, array['Équations de type ax+b=0 dans Q', 'inéquations simples de premier degré à une inconnue']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 6, 'Proportionnalité', null, array['Coefficients de proportionnalité', 'vitesse', 'masse volumique', 'débit', 'représentation graphique d’un tableau de proportionnalité']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 7, 'Pourcentages et échelles', null, array['Calcul de pourcentages', 'agrandissement et réduction à l’échelle']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 8, 'Statistiques', null, array['Collecte et organisation des données', 'effectifs', 'fréquences', 'moyenne', 'diagrammes à bandes et diagrammes circulaires']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 9, 'Distance', null, array['Distance de deux points', 'inégalité triangulaire', 'médiatrice', 'caractérisation d’un segment', 'régionnement du plan']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 10, 'Angles', null, array['Angles opposés par le sommet', 'angles formés par deux parallèles coupées par une sécante', 'angles alternes-internes et correspondants']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 11, 'Triangles', null, array['Somme des angles', 'triangles isocèles et équilatéraux', 'médiatrices', 'cercle circonscrit', 'triangles superposables']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 12, 'Cercles', null, array['Cercle circonscrit à un triangle rectangle', 'intérieur, extérieur et frontière d’un cercle']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 13, 'Quadrilatères et polygones', null, array['Caractérisation du parallélogramme, du losange, du rectangle et du carré', 'trapèze', 'polygones réguliers', 'triangle équilatéral, hexagone, carré et octogone']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 14, 'Solides', null, array['Prisme droit', 'vocabulaire', 'patron', 'construction', 'aire latérale, aire totale et volume']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 15, 'Symétries', null, array['Symétriques de points, droites, segments, triangles et cercles par rapport à un axe ou un centre', 'propriétés de conservation']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_8', 16, 'Repérage', null, array['Quadrillage', 'nœuds et mailles', 'couples de coordonnées', 'coordonnées d’un point dans le plan']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 1, 'Arithmétique', null, array['Utilisation du PPCM et du PGCD dans la résolution de problèmes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 2, 'Nombres décimaux', null, array['Écriture scientifique a \times 10^n, avec a\in Z et n\in Z', 'multiplication de nombres écrits sous cette forme']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 3, 'Nombres rationnels', null, array['Ensemble Q', 'fraction irréductible', 'comparaison', 'somme, différence, produit et inverse d’un rationnel non nul']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 4, 'Puissances', null, array['Puissances à exposant entier naturel d’un nombre rationnel non nul', 'propriétés', 'calculs simples', 'encadrements et approximations décimales']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 5, 'Calcul algébrique', null, array['Développement', 'réduction', 'factorisation', 'produits remarquables : \((a+b)^2\), \((a-b)^2\), \((a+b)(a-b)\)']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 6, 'Équations', null, array['Équations du premier degré à une inconnue dans R']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 7, 'Inéquations', null, array['Inéquations du premier degré à une inconnue', 'représentation des solutions']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 8, 'Systèmes', null, array['Équations et systèmes de deux équations du premier degré dans R \times R', 'inéquations et systèmes d’inéquations']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 9, 'Proportionnalité', null, array['Coefficients de proportionnalité', 'propriété \frac{a}{b}=\frac{c}{d}\iff ad=bc lorsque les dénominateurs sont non nuls', 'représentation graphique']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 10, 'Statistiques', null, array['Données qualitatives et quantitatives', 'effectifs', 'fréquences', 'moyenne', 'diagrammes à bandes et circulaires', 'regroupement en classes', 'histogrammes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 11, 'Géométrie plane', null, array['Distance d’un point à une droite', 'distance entre deux droites', 'bissectrice', 'triangle et droite des milieux', 'propriétés directe et réciproque']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 12, 'Pythagore', null, array['Théorème direct', 'réciproque', 'calcul de longueurs dans le triangle rectangle']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 13, 'Cercle', null, array['Positions relatives d’une droite et d’un cercle', 'tangente', 'tangentes issues d’un point']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 14, 'Vecteurs', null, array['Définition par la translation', 'égalité de vecteurs', 'représentant d’origine donnée', 'somme', 'relation de Chasles', 'vecteur nul', 'vecteur opposé', 'milieu']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 15, 'Repérage', null, array['Repère orthogonal et orthonormal', 'coordonnées d’un point', 'distance entre deux points', 'norme d’un vecteur', 'condition d’orthogonalité']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_9', 16, 'Espace', null, array['Plans et droites de l’espace', 'positions relatives', 'perspective cavalière', 'représentation de solides']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 1, 'Nombres réels', null, array['Introduction de R', 'comparaison', 'intervalles', 'encadrement de somme, différence, produit et quotient']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 2, 'Radicaux', null, array['Définition de la racine carrée', 'propriétés', 'comparaison', 'opérations sur les radicaux']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 3, 'Puissances', null, array['Puissances à exposant entier relatif d’un nombre réel', 'propriétés']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 4, 'Calcul numérique', null, array['Approximations décimales', 'usage raisonné des tables numériques et de la calculatrice']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 5, 'Monômes', null, array['Degré', 'coefficient', 'opérations sur les monômes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 6, 'Polynômes', null, array['Notion de polynôme', 'degré', 'addition et multiplication de polynômes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 7, 'Équations', null, array['Équations du premier degré dans R', 'systèmes de deux équations du premier degré dans R \times R']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 8, 'Inéquations', null, array['Inéquations et systèmes d’inéquations du premier degré dans R \times R', 'interprétation graphique']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 9, 'Applications linéaires', null, array['Définition', 'propriétés de linéarité', 'bijection', 'sens de variation', 'représentation graphique']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 10, 'Applications affines', null, array['Définition', 'sens de variation', 'représentation graphique', 'applications concrètes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 11, 'Statistiques', null, array['Regroupement en classes d’amplitudes égales', 'histogramme', 'étendue']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 12, 'Angles inscrits', null, array['Angle inscrit', 'angle au centre', 'arcs interceptés', 'propriétés et relations entre angles']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 13, 'Trigonométrie', null, array['Sinus, cosinus et tangente d’un angle aigu', 'calcul dans le triangle rectangle', 'utilisation de tables et de calculatrice', 'angles remarquables de 30°, 45° et 60°']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 14, 'Polygones réguliers', null, array['Triangle équilatéral, carré, pentagone, hexagone et octogone', 'lien avec la rotation']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 15, 'Solides', null, array['Pyramide et cône de révolution', 'vocabulaire', 'patron', 'aires et volumes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 16, 'Sections de solides', null, array['Section d’une pyramide ou d’un cône par un plan parallèle à la base', 'tronc de pyramide et tronc de cône', 'réduction et agrandissement']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 17, 'Coordonnées de vecteurs', null, array['Coordonnées d’une somme', 'coordonnées d’un produit par un réel', 'colinéarité', 'orthogonalité', 'norme']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 18, 'Droites', null, array['Vecteur directeur', 'équation de droite', 'coefficient directeur', 'parallélisme et orthogonalité de deux droites']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_10', 19, 'Transformations', null, array['Symétrie orthogonale', 'translation', 'composée de translations', 'rotation abordée expérimentalement', 'homothétie possible en complément facultatif']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_11', 1, 'Mathématiques de seconde', 'Socle commun de lycée avant la spécialisation des profils.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_12', 1, 'Équations, inéquations, systèmes linéaires', 'Résolution d''équations et d''inéquations, notamment du second degré.', array['Équations du second degré', 'Racines d''un polynôme du second degré', 'Résolution d''une équation du second degré', 'Somme et produit des solutions', 'Inéquations du second degré', 'Signe d''un polynôme du second degré', 'Interprétation graphique', 'Équations et inéquations se ramenant au second degré']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_12', 2, 'Autres domaines du programme de 12ème SM', 'La source de planification confirme une progression détaillée ; la transcription complète des chapitres suivants doit être vérifiée dans le document intégral.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_terminale', 1, 'Nombres complexes', 'Étude du corps des nombres complexes et de ses applications géométriques.', array['Module et argument', 'Représentation géométrique', 'Exponentielle complexe e^(iθ)', 'Applications trigonométriques', 'Racines n-ièmes', 'Similitudes', 'Équation du second degré']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_terminale', 2, 'Arithmétique', 'Structure des entiers et outils de divisibilité.', array['Numération décimale et binaire', 'Anneau Z', 'Sous-groupes de Z', 'Division euclidienne dans N et Z', 'Congruences', 'Anneau Z/nZ', 'Nombres premiers', 'Corps Z/pZ', 'Décomposition en facteurs premiers', 'PGCD et PPCM']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_terminale', 3, 'Analyse', 'Étude approfondie des fonctions et calcul différentiel et intégral.', array['Limites', 'Continuité', 'Dérivation', 'Intégration']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_math', 'lvl_terminale', 4, 'Autres thèmes de Terminale SM', 'La planification 2025-2026 confirme d''autres chapitres ; leur transcription exhaustive nécessite le document source complet.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 1, 'Propriétés physiques de la matière', null, array['États de la matière', 'solides, liquides et gaz', 'critères de reconnaissance', 'surface libre des liquides', 'existence, compressibilité et expansibilité de l’air']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 2, 'Mesure de la masse', null, array['Masse d’un corps', 'balances', 'balance Roberval', 'pesée de solides et liquides', 'unités et sous-unités de masse', 'conversions']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 3, 'Mesure du poids', null, array['Caractéristiques du poids : direction et sens', 'verticalité', 'peson et dynamomètre', 'différence masse/poids', 'relation P=m\times g, avec g=10\ \text{N/kg}']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 4, 'Mesure du volume', null, array['Volume des solides, liquides et gaz', 'volume d’un solide régulier', 'éprouvette graduée', 'seringue', 'déplacement de liquide', 'lecture du ménisque', 'unités et conversions']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 5, 'Température et chaleur', null, array['Thermomètres', 'température', 'échelle Celsius', 'thermomètre médical', 'distinction entre température et chaleur']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 6, 'Changements d’état', null, array['Fusion', 'solidification', 'vaporisation', 'ébullition', 'évaporation', 'condensation', 'conservation de la masse', 'non-conservation possible du volume', 'cycle de l’eau']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 7, 'Circuit électrique simple', null, array['Pile, lampe, fils conducteurs, interrupteur', 'circuit ouvert et fermé', 'lampe torche', 'tension nominale d’une lampe et d’un générateur']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 8, 'Conducteurs et isolants', null, array['Métaux, plastiques, bois, caoutchouc, eau pure, eau salée', 'rôle de la gaine électrique', 'conducteurs et isolants de l’environnement']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 9, 'Schématisation des circuits', null, array['Symboles normalisés', 'différence entre dessin et schéma', 'schéma d’une pile, d’une lampe, d’un interrupteur, d’un commutateur et d’une prise secteur']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 10, 'Associations de piles', null, array['Bornes positive et négative', 'montage en série', 'montage en opposition', 'tension d’une association', 'adaptation d’une lampe à un générateur']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 11, 'Associations de lampes', null, array['Montage en série', 'montage en dérivation', 'conséquences d’une lampe grillée', 'court-circuit', 'exemples domestiques et guirlandes']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 12, 'Sécurité électrique', null, array['Test lampe-pile', 'recherche de panne', 'dangers d’électrocution', 'dangers d’incendie', 'fusibles', 'disjoncteurs', 'remplacement d’un fusible identique']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_7', 13, 'Aimants', null, array['Corps ferreux et nickel', 'pôles Nord et Sud', 'attraction et répulsion', 'boussole', 'orientation Nord-Sud', 'aimantation temporaire du fer et permanente de l’acier']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 1, 'État gazeux', null, array['Compressibilité et expansibilité des gaz', 'pression atmosphérique', 'mesure et comparaison de pressions', 'masse de l’air et de gaz usuels', 'pas de calcul formel reliant pression, force et surface']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 2, 'Masse volumique', null, array['Masse volumique des solides, liquides et gaz', 'unités', 'détermination expérimentale avec balance et récipient gradué', 'calcul de masse, volume ou masse volumique']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 3, 'Calorimétrie', null, array['Échanges de chaleur entre masses d’eau à températures différentes', 'température d’équilibre', 'invariance de la température lors de la fusion et de l’ébullition d’un corps pur', 'principe de la bouteille thermos']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 4, 'Dilatation', null, array['Dilatation des solides, liquides et gaz', 'étude qualitative', 'joints de dilatation des rails et ponts', 'thermomètre à liquide', 'bilame', 'vase d’expansion']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 5, 'Transmission de chaleur', null, array['Conduction dans les solides', 'convection dans les liquides et les gaz', 'rayonnement', 'isolation thermique', 'applications : casseroles, maisons, glacières, thermos et foyers améliorés']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 6, 'Électricité', null, array['Mesure de l’intensité et de la tension', 'circuits en série et en dérivation', 'unicité de l’intensité dans un circuit sans dérivation', 'additivité des tensions', 'unicité de la tension et additivité des intensités dans les circuits avec dérivation']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_8', 7, 'Électromagnétisme', null, array['Étude signalée dans les plans de progression récents : effets magnétiques du courant et applications usuelles', 'la liste exhaustive des sous-leçons nécessite toutefois une vérification directe du fascicule complet']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_9', 1, 'Acoustique', null, array['Production et propagation du son', 'sources sonores', 'phénomènes acoustiques', 'durée indiquée dans le programme : 2 heures pour l’introduction à l’acoustique']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_9', 2, 'Optique', null, array['Étude de la lumière', 'propagation rectiligne', 'ombre et pénombre', 'réflexion et réfraction', 'miroirs et lentilles selon le niveau de développement du chapitre']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_9', 3, 'Mécanique', null, array['Forces et effets des forces', 'poids', 'équilibre', 'mouvement', 'relation entre masse et poids reprise dans une approche plus expérimentale']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_9', 4, 'Énergie mécanique', null, array['Travail, puissance et énergie mécanique', 'applications aux machines et activités de la vie courante']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_9', 5, 'Technologie', null, array['Approche des dispositifs mécaniques et techniques à partir d’objets de l’environnement']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_10', 1, 'Optique', null, array['Réflexion et réfraction de la lumière sur des surfaces planes', 'durée repérée : 3 heures pour cette leçon', 'applications pratiques de la propagation et du changement de direction de la lumière']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_10', 2, 'Optique géométrique', null, array['Miroirs, lentilles, formation d’images et instruments simples : à vérifier dans le fascicule original complet avant transcription exhaustive']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_10', 3, 'Mécanique', null, array['Travail, puissance et énergie mécaniques', 'durée repérée : 9 heures', 'calculs et interprétation de situations mécaniques']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_10', 4, 'Mécanique et technologie', null, array['Ensemble « mécanique et technologie » identifié à 27 heures dans le programme', 'étude fonctionnelle de systèmes ou mécanismes techniques usuels']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_10', 5, 'Démarche expérimentale', null, array['Mesures, exploitation des résultats, schémas, identification de grandeurs physiques, unités et résolution de problèmes contextualisés']::text[], null, 'partiel', 'math_physique.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_11', 1, 'Grandeurs mesurables', 'Définition des grandeurs physiques et analyse dimensionnelle.', array['Notion de grandeurs physiques', 'Équations aux dimensions']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_11', 2, 'Mécanique', 'Étude du mouvement et des interactions mécaniques.', array['Le mouvement', 'Caractère relatif du mouvement', 'Étude du mouvement d''un point mobile']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_11', 3, 'Calorimétrie / gaz', 'Étude thermique et transformations des gaz.', array['Transformations à température constante', 'Transformations à pression constante', 'Transformations à volume constant']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_11', 4, 'Thermodynamique', 'Relations entre chaleur et travail et fonctionnement des machines thermiques.', array['Équivalence de la chaleur et du travail', 'Premier principe de la thermodynamique', 'Machines thermiques']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_11', 5, 'Électrostatique, électricité et électronique', 'Charges, circuits électriques et composants électroniques.', array['Phénomènes électrostatiques', 'Champ électrostatique', 'Différence de potentiel', 'Courant électrique', 'Intensité d''un courant continu', 'Tension dans un circuit', 'Dipôles passifs', 'Dipôles actifs', 'Diode à semi-conducteur', 'Transistor', 'Applications']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_12', 1, 'Physique du lycée', 'Poursuite et approfondissement de la mécanique, de l''électricité et des autres domaines du programme de lycée.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_phys', 'lvl_terminale', 1, 'Physique Terminale', 'Approfondissement des sciences physiques en vue du baccalauréat ; détail complet à vérifier dans le programme intégral.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 1, 'Introduction à la chimie', null, array['Rôle de la chimie dans la vie courante', 'produits chimiques de l’environnement']::text[], 'Distinguer la place de la chimie dans le savon, les métaux, les plastiques, les engrais, les médicaments et les produits de consommation', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 2, 'Transformations physiques', null, array['États physiques', 'fusion', 'solidification', 'vaporisation', 'liquéfaction ou condensation', 'sublimation']::text[], 'Comprendre qu’une transformation physique change l’état d’un corps sans modifier sa nature chimique', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 3, 'Transformations chimiques', null, array['Différence entre transformation physique et chimique']::text[], 'Reconnaître qu’une combustion fait disparaître certains corps et apparaître de nouvelles substances', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 4, 'Composition de l’air', null, array['Constituants essentiels de l’air', 'dioxygène', 'diazote', 'proportions volumiques principales']::text[], 'Identifier les deux gaz principaux de l’air et leur rôle', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 5, 'Combustions dans l’air', null, array['Flammes', 'types de flammes', 'conditions de combustion', 'rôle du dioxygène']::text[], 'Observer et comparer la combustion d’une bougie, d’une lampe à pétrole, d’un briquet ou d’un réchaud', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 6, 'Butane', null, array['Gaz combustible', 'briquet à gaz', 'bouteille de gaz', 'risques liés aux fuites']::text[], 'Identifier le butane comme combustible et appliquer les règles de sécurité', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 7, 'Combustion du soufre', null, array['Combustion du soufre', 'produits formés', 'caractère chimique de la réaction']::text[], 'Montrer qu’une combustion produit de nouveaux corps', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 8, 'Combustion du fer', null, array['Combustion de la paille de fer ou de la limaille de fer', 'incandescence', 'oxydation']::text[], 'Interpréter la combustion du fer comme une réaction chimique', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 9, 'Appareils utilisant des combustibles', null, array['Réchaud à bois', 'charbon de bois', 'gaz', 'pétrole', 'foyers améliorés']::text[], 'Expliquer le fonctionnement général d’appareils de cuisson ou de chauffage', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 10, 'Aspects pratiques des combustions', null, array['Choix, emploi et rendement pratique des combustibles']::text[], 'Employer un combustible de façon rationnelle', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_7', 11, 'Dangers des combustions usuelles', null, array['Incendie', 'brûlure', 'gaz toxiques', 'intoxication', 'prévention']::text[], 'Adopter des comportements de sécurité dans l’usage du bois, charbon, pétrole, gaz et briquets', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 1, 'Étude de l’eau', null, array['Eaux naturelles', 'eau douce', 'eau salée', 'sources d’eau', 'cycle de l’eau']::text[], 'Identifier les différentes formes et sources d’eau dans la nature', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 2, 'Eau limpide et eau potable', null, array['Eau claire, eau trouble, eau potable, eau polluée']::text[], 'Distinguer une eau limpide d’une eau potable et comprendre les exigences de potabilité', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 3, 'Eau et dissolution', null, array['Solvant', 'soluté', 'solution homogène', 'dissolution d’un solide dans l’eau']::text[], 'Préparer et identifier une solution aqueuse simple', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 4, 'Solubilité', null, array['Solubilité', 'solution saturée', 'influence de la quantité de soluté']::text[], 'Définir la solubilité et reconnaître une solution saturée', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 5, 'Concentration massique', null, array['Masse de soluté', 'volume de solution', 'concentration massique']::text[], 'Calculer une concentration massique simple', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 6, 'Mélanges liquide-liquide', null, array['Eau et alcool', 'eau et huile', 'liquides miscibles et non miscibles']::text[], 'Distinguer miscibilité, non-miscibilité et émulsion', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 7, 'Dissolution des gaz', null, array['Gaz dissous dans l’eau', 'boissons gazeuses', 'dégagement de dioxyde de carbone']::text[], 'Montrer que l’eau peut dissoudre des gaz', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 8, 'Mélanges et corps purs', null, array['Mélanges homogènes et hétérogènes', 'corps pur simple', 'corps pur composé']::text[], 'Distinguer un mélange d’un corps pur et classer les substances', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 9, 'Séparation des constituants', null, array['Décantation', 'filtration', 'évaporation', 'distillation', 'aimantation']::text[], 'Choisir une technique de séparation adaptée', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 10, 'Atomes', null, array['Symbole chimique', 'éléments chimiques', 'tableau périodique simplifié']::text[], 'Représenter les atomes par leurs symboles', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 11, 'Molécules', null, array['Formules moléculaires', 'modèles moléculaires', 'molécules simples']::text[], 'Comprendre qu’une molécule est un assemblage d’atomes', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 12, 'Réactions chimiques', null, array['Réactifs', 'produits', 'équation-bilan en mots']::text[], 'Décrire une réaction chimique par une équation en langage courant', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 13, 'Conservation des atomes', null, array['Conservation des atomes lors d’une réaction']::text[], 'Écrire et équilibrer progressivement des équations chimiques simples', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 14, 'Acide chlorhydrique et calcaire', null, array['Action de l’acide chlorhydrique sur le calcaire', 'dégagement gazeux']::text[], 'Identifier une réaction où l’air n’intervient pas', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 15, 'Cycle des réactions du soufre', null, array['Combustion du soufre', 'transformations successives']::text[], 'Relier des réactions chimiques entre elles', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_8', 16, 'Allumettes', null, array['Composition et fonctionnement simplifié', 'réaction de combustion']::text[], 'Comprendre la réaction chimique mise en jeu lors de l’allumage', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 1, 'Système périodique des éléments', null, array['Numéro atomique', 'périodes', 'groupes', 'familles chimiques', 'métaux et non-métaux']::text[], 'Lire une classification périodique simple et relier la position d’un élément à certaines de ses propriétés', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 2, 'Courant électrique dans les métaux', null, array['Conducteurs et isolants', 'électrons', 'sens conventionnel du courant']::text[], 'Comprendre que les électrons assurent le passage du courant dans les métaux', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 3, 'Ions métalliques', null, array['Ions', 'cations', 'anions', 'métal sous forme atomique ou ionique']::text[], 'Distinguer le métal et l’ion métallique correspondant', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 4, 'Transformation électrochimique du cuivre', null, array['Cuivre métal', 'ion cuivre', 'électrode', 'transformation électrochimique']::text[], 'Mettre en évidence le passage du cuivre métallique à l’ion cuivre, et inversement', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 5, 'Courant électrique dans les électrolytes', null, array['Électrolytes', 'solutions ioniques', 'migration des ions']::text[], 'Comprendre que le courant dans un électrolyte est transporté par les ions', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 6, 'Transformations du cuivre et de l’ion cuivre', null, array['Reconnaissance de l’ion cuivre', 'transformations chimiques du cuivre']::text[], 'Utiliser des réactions simples pour passer du cuivre à l’ion cuivre et inversement', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 7, 'Métaux et alliages', null, array['Propriétés des métaux', 'alliages', 'avantages des alliages']::text[], 'Citer les propriétés et utilisations du fer, cuivre, aluminium, zinc et autres métaux usuels', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 8, 'Corrosion des métaux', null, array['Corrosion', 'rouille', 'humidité', 'salinité', 'corrosion de l’aluminium, cuivre et zinc']::text[], 'Identifier les causes de corrosion et les moyens de protection', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 9, 'Protection des métaux', null, array['Peinture', 'vernis', 'plastique', 'galvanisation', 'alliages']::text[], 'Proposer des moyens de protéger les métaux ferreux', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 10, 'Aluminium', null, array['Bauxite', 'alumine', 'procédé Bayer', 'propriétés', 'usages']::text[], 'Expliquer l’importance de l’aluminium et de la bauxite en Guinée', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 11, 'Corps moléculaires', null, array['Propriétés et structure moléculaire des gaz', 'masse molaire', 'pression atmosphérique']::text[], 'Décrire qualitativement les gaz et leur structure moléculaire', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 12, 'Électrolyse de l’eau', null, array['Décomposition de l’eau par électrolyse']::text[], 'Réaliser ou interpréter l’électrolyse de l’eau', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 13, 'Synthèse de l’eau', null, array['Réaction entre le dihydrogène et le dioxygène']::text[], 'Écrire l’équation-bilan de la synthèse de l’eau', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_9', 14, 'Chimie quantitative', null, array['Mole', 'masse molaire', 'volume molaire', 'densité d’un gaz par rapport à l’air']::text[], 'Résoudre des problèmes chimiques simples à partir d’équations-bilans', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 1, 'Oxydoréduction par transfert d’oxygène', null, array['Oxydation', 'réduction', 'combustion du carbone, soufre et fer', 'oxydes métalliques']::text[], 'Comprendre qu’une oxydation correspond à une fixation d’oxygène et une réduction à une perte d’oxygène', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 2, 'Réduction des oxydes', null, array['Réduction de l’oxyde ferrique par l’aluminium', 'réduction de l’oxyde de cuivre par le carbone']::text[], 'Écrire et équilibrer des équations simples d’oxydoréduction', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 3, 'Importance industrielle de la réduction', null, array['Haut fourneau', 'minerais', 'production de métaux']::text[], 'Comprendre le principe de réduction d’un oxyde métallique pour produire un métal', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 4, 'Oxydoréduction par transfert d’électrons', null, array['Perte et gain d’électrons', 'oxydant', 'réducteur']::text[], 'Comprendre l’interprétation électronique simplifiée des réactions redox', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 5, 'Pile électrochimique', null, array['Générateur électrochimique', 'énergie chimique et énergie électrique', 'usure d’une pile']::text[], 'Expliquer qu’une pile fonctionne grâce à une réaction d’oxydoréduction', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 6, 'Pile cuivre-zinc', null, array['Électrodes', 'circulation des électrons', 'réaction chimique']::text[], 'Étudier un exemple de pile électrochimique', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 7, 'Pile Daniell', null, array['Demi-piles', 'électrolyte', 'transformation chimique spontanée']::text[], 'Identifier les constituants et le fonctionnement simplifié d’une pile Daniell', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 8, 'Pile saline, alcaline et lithium', null, array['Types de piles', 'caractéristiques et usages']::text[], 'Comparer quelques générateurs électrochimiques usuels', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 9, 'Solutions aqueuses', null, array['Solutions acides, basiques et neutres']::text[], 'Classer une solution aqueuse suivant son caractère acide, basique ou neutre', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 10, 'Acidité et basicité', null, array['Indicateurs colorés', 'bleu de bromothymol', 'papier pH', 'échelle de pH']::text[], 'Lire une valeur de pH et identifier le caractère d’une solution', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 11, 'Conductibilité des solutions', null, array['Ions en solution', 'électrolytes']::text[], 'Relier la conduction électrique à la présence d’ions', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 12, 'Ions en solution aqueuse', null, array['Cations et anions', 'électroneutralité', 'dissociation d’un électrolyte']::text[], 'Écrire et interpréter des formules ioniques simples', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 13, 'Caractérisation des ions', null, array['Ions cuivre Cu^{2+}, fer(II) Fe^{2+}, fer(III) Fe^{3+}, zinc Zn^{2+}, chlorure Cl^{-}, sulfate SO_4^{2-}, carbonate CO_3^{2-}']::text[], 'Reconnaître certains ions par des tests chimiques', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 14, 'Chimie organique', null, array['Composés du carbone', 'tétravalence du carbone', 'nomenclature élémentaire']::text[], 'Comprendre que la chimie organique étudie principalement les composés du carbone', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 15, 'Alcanes', null, array['Méthane', 'formule générale', 'chaînes carbonées', 'nomenclature', 'propriétés chimiques']::text[], 'Reconnaître les alcanes et citer leurs usages', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 16, 'Alcènes', null, array['Éthylène', 'double liaison', 'propriétés et réactions']::text[], 'Identifier les alcènes', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_10', 17, 'Alcynes', null, array['Acétylène', 'triple liaison', 'propriétés chimiques']::text[], 'Identifier les alcynes et leurs caractéristiques principales', 'partiel', 'chimie.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_11', 1, 'Mélanges et corps purs', 'États de la matière, changements d''état, séparation des mélanges et critères de pureté.', array['Différents états de la matière', 'Changements d''état', 'Mélanges homogènes et hétérogènes', 'Décantation', 'Filtration', 'Évaporation', 'Distillation', 'Congélation', 'Triage', 'Constantes physiques et critères de pureté', 'Corps purs simples et composés']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_11', 2, 'Atomes, éléments et classification périodique', 'Construction des notions d''élément et d''atome et introduction au tableau périodique.', array['Notion d''élément', 'Élément cuivre', 'Élément carbone', 'Classification périodique']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_11', 3, 'Transformations chimiques', 'Étude des réactions et de leur représentation.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_12', 1, 'Chimie du lycée', 'Approfondissement de la structure et des transformations de la matière.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_terminale', 1, 'Industrie de l''acide sulfurique', 'Étude de la fabrication industrielle de l''acide sulfurique et de ses usages.', array['Fabrication de l''anhydride sulfureux', 'Grillage des sulfures', 'Combustion du soufre', 'Principe du procédé', 'Description et fonctionnement de l''atelier sulfurique', 'Four à soufre', 'Caisses de contact', 'Absorption', 'Propriétés et usages de l''acide sulfurique', 'Raffinage des pétroles', 'Fabrication d''explosifs, films, colorants, fibres, plastiques et engrais']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_chim', 'lvl_terminale', 2, 'Autres thèmes de chimie Terminale', 'La source consultée confirme d''autres contenus de chimie Terminale ; transcription complète à vérifier.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_7', 1, 'Sciences de la vie', 'Découverte du vivant et observation des organismes.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_8', 1, 'Sciences de la vie', 'Approfondissement des fonctions et de la diversité du vivant.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_9', 1, 'Biologie', 'Étude du vivant et de l''environnement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_10', 1, 'Biologie', 'Consolidation des notions et préparation au BEPC.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_11', 1, 'Nutrition des plantes vertes', 'Fonctionnement nutritionnel des plantes et production de matière organique.', array['La plante et l''eau : mécanisme d''absorption', 'Besoins en sels minéraux', 'Mécanisme d''absorption des sels minéraux', 'Transit de la sève brute', 'Transpiration', 'Utilisation des substances absorbées', 'Production de matière organique : photosynthèse']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_11', 2, 'Reproduction chez les spermaphytes', 'Reproduction sexuée des plantes à fleurs, de la fleur à la graine.', array['Organes protecteurs', 'Organes reproducteurs', 'Structure de la fleur', 'Structure de l''anthère', 'Formation des grains de pollen', 'Structure de l''ovaire', 'Formation du sac embryonnaire', 'Pollinisation', 'Germination du grain de pollen', 'Double fécondation', 'Formation de la graine et du fruit', 'Germination de la graine']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_11', 3, 'Diversité du monde vivant', 'Critères et unités de classification du vivant.', array['Critères et unités systématiques']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_11', 4, 'Écologie', 'Fonctionnement des écosystèmes, relations entre êtres vivants et actions humaines.', array['Facteurs biotiques', 'Relations interspécifiques', 'Parasitisme', 'Symbiose', 'Commensalisme', 'Relations intraspécifiques', 'Vie en groupe', 'Vie en société', 'Interdépendance des êtres vivants', 'Relations trophiques', 'Chaînes alimentaires', 'Flux d''énergie', 'Cycle du carbone', 'Cycle de l''azote', 'Fragilité des équilibres naturels', 'Déboisement', 'Feux de brousse', 'Désertification', 'Reboisement', 'Protection de la biosphère']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_12', 1, 'Étude de la cellule', 'Structure comparée de la cellule et constituants physico-chimiques de la matière vivante.', array['Cellule animale', 'Cellule végétale', 'Ultrastructure', 'Eau', 'Sels minéraux', 'Glucides', 'Protides', 'Lipides', 'États physiques']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_12', 2, 'Besoins alimentaires de l''homme', 'Besoins énergétiques et qualitatifs et notion de ration alimentaire.', array['Besoins énergétiques', 'Besoins alimentaires qualitatifs', 'Rations alimentaires']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_12', 3, 'Digestion des aliments', 'Transformation des aliments et devenir des produits de la digestion.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_12', 4, 'Production d''énergie', 'Production d''énergie par respiration et fermentation.', array['Respiration', 'Fermentations']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_12', 5, 'Maladies parasitaires dues aux protozoaires', 'Étude de plusieurs parasitoses humaines.', array['Amibiase et amibe dysentérique', 'Paludisme et Plasmodium', 'Maladie du sommeil et Trypanosome']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_12', 6, 'Maladies parasitaires dues aux vers', 'Étude de plusieurs helminthiases humaines.', array['Téniase et Ténia', 'Ascaridiase et Ascaris', 'Onchocercose et Onchocerque']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_terminale', 1, 'Information génétique et synthèse des protéines', 'Nature et expression de l''information génétique.', array['Nature de l''information génétique', 'Expression de l''information génétique']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_terminale', 2, 'Transmission de l''information génétique', 'Divisions cellulaires et transmission des caractères héréditaires.', array['Divisions cellulaires', 'Monohybridisme', 'Dihybridisme', 'Transmission de deux gènes liés', 'Estimation de la distance entre les gènes', 'Transmission d''un gène lié au sexe']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_terminale', 3, 'Physiologie humaine', 'Étude de grandes fonctions et de la réponse immunitaire.', array['Réponse immunitaire à médiation humorale', 'Réponse immunitaire à médiation cellulaire', 'Coopération cellulaire']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_biol', 'lvl_terminale', 4, 'Dysfonctionnement du système immunitaire', 'Étude du mécanisme d''infection par le VIH et de ses conséquences.', array['Adsorption du VIH au lymphocyte T4', 'Injection de l''ARN viral et de la transcriptase inverse', 'Transformation de l''ARN proviral en ADN proviral', 'Intégration à l''ADN cellulaire', 'Multiplication du VIH', 'Latence et séropositivité', 'Dégradation du système immunitaire et SIDA']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_7', 1, 'Notion d''histoire et sources', 'Comprendre la succession dans le temps et les sources historiques.', array['Succession dans le temps', 'Sources historiques']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_7', 2, 'Préhistoire', 'Découverte des grandes étapes de la préhistoire.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_7', 3, 'Civilisations anciennes d''Afrique', 'Étude de civilisations d''Afrique du Nord-Est et du Nord-Ouest.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_7', 4, 'Civilisations d''Asie occidentale', 'Étude notamment de la Mésopotamie.', array['Mésopotamie']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_7', 5, 'Monde gréco-romain', 'Introduction aux civilisations grecque et romaine.', array['Grèce', 'Rome']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_8', 1, 'Histoire médiévale et africaine', 'Progression historique du niveau 8ème ; détail intégral non retrouvé dans les sources consultées.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_9', 1, 'Histoire moderne', 'Progression historique du niveau 9ème ; détail intégral non retrouvé dans les sources consultées.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_10', 1, 'Histoire contemporaine', 'Révolution, colonisation et histoire de la Guinée figurent dans les ressources de préparation au BEPC consultées.', array['Révolution française', 'Colonisation', 'Histoire de la Guinée']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_11', 1, 'L''objet de l''histoire et la problématique de l''histoire africaine', 'Introduction à la démarche historique et à l''histoire africaine.', array['L''objet de l''histoire', 'Démarche historique', 'Histoire et formation du citoyen']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_11', 2, 'Afrique et monde moderne', 'Les éléments de programme du lycée abordent l''histoire africaine et les transformations du monde moderne.', array['Civilisations africaines', 'Industrialisation en Europe', 'Impérialisme']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_12', 1, 'Guerres mondiales et transformations du monde', 'Approfondissement des grandes ruptures du XXe siècle.', array['Première Guerre mondiale', 'Transformations politiques et sociales', 'Décolonisation']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_hist', 'lvl_terminale', 1, 'Monde contemporain', 'Relations internationales et grands enjeux historiques contemporains.', array['Décolonisation', 'Relations internationales contemporaines', 'Guerre froide et monde contemporain']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_7', 1, 'La Terre et l''espace géographique', 'Caractéristiques générales de la Terre et repérage géographique.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_8', 1, 'Milieux et continents', 'Étude des grands milieux et des réalités humaines et physiques des continents.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_9', 1, 'Populations et activités', 'Étude des populations et des activités économiques.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_10', 1, 'Espaces et développement', 'Étude des grands espaces, des activités et des réalités de développement ; préparation au BEPC.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_11', 1, 'Géographie du lycée', 'Étude des espaces, populations et activités à des échelles nationale, africaine et mondiale.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_12', 1, 'Géographie économique et humaine', 'Approfondissement des dynamiques territoriales et économiques.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geog', 'lvl_terminale', 1, 'Géographie contemporaine', 'Étude des grands espaces et dynamiques contemporaines ; particulièrement importante en SS.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 1, 'Unité 1 — Greetings', null, array['Salutations formelles et informelles', 'moments de la journée', 'titres Mr., Mrs., Miss, Sir', 'questions-réponses avec How are you?', 'présent de be']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 2, 'Unité 2 — Introductions', null, array['Se présenter et présenter une autre personne', 'pronoms personnels', 'adjectifs possessifs my, your, his, her', 'What is your name?']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 3, 'Unité 3 — The alphabet', null, array['Alphabet anglais', 'lettres majuscules/minuscules', 'épellation', 'consignes de classe', 'articles a/an', 'questions what, where, how']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 4, 'Unité 4 — Identifying numbers', null, array['Nombres cardinaux de 1 à 100', 'lecture et écriture des nombres', 'impératifs', 'pronoms compléments me, you, him, her']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 5, 'Unité 5 — The alphabet spelling', null, array['Révision de l’alphabet', 'épeler des noms et mots', 'Can you spell it?', 'noms de pays, villes et écoles']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 6, 'Unité 6 — Consolidation: greetings, alphabet and numbers', null, array['Révision des unités 1 à 5', 'présentations', 'nombres', 'additions et vocabulaire mathématique élémentaire']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 7, 'Unité 7 — Telling time', null, array['Heure : o’clock, half past, quarter past, quarter to', 'emploi de at, before, after', 'routines simples : When do you get up?']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 8, 'Unité 8 — Days of the week', null, array['Jours, mois, années', 'ordinaux', 'date', 'today, yesterday, tomorrow', 'présent et passé de be']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 9, 'Unité 9 — The names of common objects', null, array['Objets usuels', 'this/that', 'articles', 'possession avec have/has', 'identification : What is this?']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 10, 'Unité 10 — Distinguishing objects by size and shape', null, array['Taille et forme', 'adjectifs tels que long, short, tall, small, big', 'article défini the', 'prépositions simples']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 11, 'Unité 11 — Moving things', null, array['Exécution de consignes avec take, put, give', 'positions : in, on, under, behind, between, in front of', 'couleurs']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 12, 'Unité 12 — Identifying shapes', null, array['Figures géométriques : square, rectangle, triangle, circle, line, arrow', 'consignes de dessin', 'another', 'a/an']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 13, 'Unité 13 — Describing objects', null, array['Description courte d’un objet', 'matière, usage, couleur, coût, forme et taille', 'It is made of…, This is used for…']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 14, 'Unité 14 — Written form of words', null, array['Association mot-image', 'copie et reconnaissance de mots', 'production de phrases simples avec This is a…']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 15, 'Unité 15 — Locating people and things in relation to others', null, array['Localisation précise d’objets et de personnes', 'repères gauche/droite', 'next to, behind, in front of, near, between']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 16, 'Unité 16 — Consolidation', null, array['Réinvestissement des prépositions, de la description d’objets et de la localisation', 'présent simple et présent progressif']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 17, 'Unité 17 — Identifying and moving classroom objects', null, array['Objets de classe : desk, duster, ruler, map, cupboard, dictionary', 'consignes d’action', 'localisation dans la salle']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 18, 'Unité 18 — Parts of the body', null, array['Parties du corps', 'actions : touch, raise, lift, close, open', 'impératifs et présent progressif']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 19, 'Unité 19 — Telling about family and things', null, array['Membres de la famille', 'possession', 'adjectifs possessifs', 'have got', 'questions sur les liens familiaux']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 20, 'Unité 20 — People and jobs', null, array['Métiers et activités : agriculteur, médecin, chauffeur, enseignant, pêcheur, commerçant, etc', 'lieu et nature du travail', 'want to be']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 21, 'Unité 21 — Identifying and moving common objects', null, array['Réemploi des objets courants et scolaires', 'consignes complexes avec take, put back, pick up', 'quantificateurs some, any, all, several']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 22, 'Unité 22 — Finding, putting in, taking out', null, array['Actions et consignes : find, put in, take out', 'questions fermées au présent et au passé simple', 'réponse affirmative ou négative']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 23, 'Unité 23 — Positions and giving directions', null, array['Position sur une image ou dans l’espace', 'coins et centre', 'directions', 'top left corner, bottom right corner, in the middle']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 24, 'Unité 24 — Consolidation', null, array['Révision de la localisation, des prépositions, des ordres et de la description spatiale', 'identification de nom, verbe, pronom, adjectif, adverbe et préposition']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 25, 'Unité 25 — Giving and taking using ordinal numbers', null, array['Ordinaux et place dans un groupe', 'donner et recevoir un objet', 'positions : premier, dernier, milieu']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 26, 'Unité 26 — Following written instructions', null, array['Lecture puis réalisation de consignes écrites', 'dessin guidé par des prépositions et adjectifs']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 27, 'Unité 27 — Identifying written descriptions', null, array['Compréhension de descriptions écrites', 'distinction entre what et which', 'choix limité', 'adjectifs comme favourite et best']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 28, 'Unité 28 — Locations: the class seating chart', null, array['Placement des élèves', 'rangées, groupes, bureaux', 'production et compréhension de consignes écrites/orales']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 29, 'Unité 29 — Adjectives describing feelings', null, array['États et sentiments : happy, sad, angry, afraid, tired, hot, cold, hungry, thirsty', 'affirmations, négations et questions']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_7', 30, 'Unité 30 — Personal information', null, array['Âge, taille, adresse, domicile', 'rédaction de courts paragraphes sur soi-même et sur une autre personne']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 1, 'Unité 1 — More personal information', null, array['Informations personnelles approfondies : distance, durée, nombre', 'How far? How long? How many?', 'possessifs et génitif']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 2, 'Unité 2 — My favorite things', null, array['Goûts, préférences et aversions', 'loisirs, sport, nourriture, musique', 'présent simple', 'futur avec going to']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 3, 'Unité 3 — Consolidation: question words', null, array['Révision des mots interrogatifs et de la construction des questions', 'présent et passé dans des échanges personnels']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 4, 'Unité 4 — Describing people: clothing', null, array['Vêtements, accessoires, couleurs', 'description de ce qu’une personne porte', 'présent simple et présent progressif']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 5, 'Unité 5 — Comparing people and things', null, array['Comparatif et superlatif des adjectifs courts', 'comparaison de personnes, animaux et objets']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 6, 'Unité 6 — Consolidation: describing clothing', null, array['Révision de la description vestimentaire', 'opposition entre action en cours et caractéristique stable']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 7, 'Unité 7 — Physical characteristics', null, array['Taille, corpulence, teint, cheveux, yeux et traits physiques', 'be, have et wear']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 8, 'Unité 8 — Question tags', null, array['Questions-tag : You are short, aren’t you?', 'réponses affirmatives et négatives', 'vérification d’information']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 9, 'Unité 9 — Describing people: more physical characteristics', null, array['Description plus précise : barbe, moustache, lunettes, tresses, calvitie, cheveux gris, etc']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 10, 'Unité 10 — Consolidation', null, array['Deviner et identifier une personne à partir d’indices physiques et de préférences']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 11, 'Unité 11 — What do we have in common?', null, array['Ce que des personnes ont en commun', 'emploi de both', 'présent simple et présent progressif affirmatif/négatif']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 12, 'Unité 12 — What is a family?', null, array['Famille nucléaire et élargie', 'liens de parenté', 'composition du foyer', 'adjectifs et possession']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 13, 'Unité 13 — Telling about your family', null, array['Arbre généalogique simple', 'description de sa famille', 'relations, âge, état civil, personnes vivantes ou décédées']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 14, 'Unité 14 — Extended family', null, array['Famille élargie : cousins, neveux, nièces, beaux-frères, belles-sœurs, petits-enfants', 'présent et passé simple']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 15, 'Unité 15 — Consolidation: describing family members', null, array['Révision de la famille et des descriptions physiques', 'rédaction d’un paragraphe descriptif']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 16, 'Unité 16 — Colour, size and shape', null, array['Couleurs, formes, dimensions', 'description d’objets', 'articles et adjectifs']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 17, 'Unité 17 — Measurements', null, array['Longueur, hauteur, largeur, poids et distance', 'unités : mètre, centimètre, kilogramme, kilomètre']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 18, 'Unité 18 — Asking questions about measurements', null, array['Questions sur l’âge, le poids, la hauteur, la distance et la longueur', 'réponses chiffrées']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 19, 'Unité 19 — What things are made of: materials', null, array['Matériaux : bois, métal, plastique, verre, tissu, papier, etc', 'structure be made of']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 20, 'Unité 20 — Food and household items: market vocabulary', null, array['Aliments et produits domestiques', 'noms comptables/non comptables', 'some, any, many, much']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 21, 'Unité 21 — Going shopping', null, array['Prix, monnaie, achats, marchandage', 'How much?', 'lexique du marché', 'produits bon marché ou chers']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 22, 'Unité 22 — Things you would like to do', null, array['Désirs, projets et choix', 'modaux would like to et should', 'achats souhaités et activités envisagées']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_8', 23, 'Unité 23 — Describing your house and compound', null, array['Pièces, mobilier, cour, installations domestiques', 'maison réelle ou idéale', 'vocabulaire de l’habitat']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 1, 'Communication orale', null, array['Exprimer accord, désaccord, opinion, demande d’explication, conseil et projet']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 2, 'Compréhension orale', null, array['Instructions et échanges plus longs', 'informations spécifiques', 'prononciation et intonation']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 3, 'Grammaire', null, array['Consolidation des temps, comparatifs, modaux, questions, pronoms et connecteurs']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 4, 'Lexique', null, array['Santé, alimentation, transport, environnement, loisirs, école, vie sociale']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 5, 'Lecture', null, array['Identification du thème, des personnages, des informations et du type de texte']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 6, 'Expression écrite', null, array['Paragraphe, description, récit bref, dialogue, lettre et formulaire']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_9', 7, 'Méthodes', null, array['Dictionnaire, champs lexicaux, familles de mots, relecture']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 1, 'Communication orale', null, array['Défendre un point de vue, participer à une discussion, rendre compte et présenter un sujet']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 2, 'Compréhension orale', null, array['Messages plus complexes', 'reformulation', 'prise de notes et transfert d’informations']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 3, 'Grammaire', null, array['Concordance des temps, discours direct/indirect, voix active/passive, subordonnées et conditionnel']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 4, 'Lexique', null, array['Développement, citoyenneté, environnement, emploi, orientation, société et communication']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 5, 'Lecture', null, array['Résumé, opinion argumentée, reformulation, analyse d’indices textuels']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 6, 'Expression écrite', null, array['Récit, lettre, compte rendu, description, dialogue, texte informatif et production plus autonome']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_10', 7, 'Méthodes', null, array['Autoévaluation, correction, prise de notes, organisation du travail collectif et individuel']::text[], null, 'partiel', 'anglais.txt')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_11', 1, 'MOBEL 5', 'Niveau associé à MOBEL 5 dans le programme national redistribué.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_12', 1, 'MOBEL 6', 'Niveau associé à MOBEL 6 dans le programme national redistribué.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_angl', 'lvl_terminale', 1, 'MOBEL 7', 'Niveau associé à MOBEL 7 dans le programme national redistribué.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_econ', 'lvl_11', 1, 'Introduction à l''économie', 'Notions économiques fondamentales.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_econ', 'lvl_12', 1, 'Économie', 'Approfondissement des notions économiques.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_econ', 'lvl_terminale', 1, 'Économie', 'Préparation aux notions et exercices du baccalauréat, notamment en SS.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_11', 1, 'Initiation à la philosophie', 'Définition, objet, statut et méthodes de la philosophie.', array['Définition, objet et statut', 'Méthode intuitive', 'Méthode rationnelle', 'Question fondamentale', 'Idéalisme', 'Matérialisme']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_11', 2, 'Branches de la philosophie', 'Présentation des principales branches philosophiques.', array['Métaphysique', 'Logique', 'Éthique ou morale', 'Esthétique', 'Psychologie']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_11', 3, 'Fondements de l''existence sociale', 'Première étude philosophique de la vie sociale.', array['Sphère sociale', 'Famille', 'Clan', 'Tribu', 'Ethnie', 'Caste', 'École', 'Nation', 'État']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_12', 1, 'Philosophie', 'Approfondissement des problèmes philosophiques selon la progression du lycée.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_terminale', 1, 'Science et technique', 'Définition, rapport entre savant et technicien et problèmes de la vérité scientifique.', array['Définition de science et technique', 'Savant et technicien', 'Vérité scientifique']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_terminale', 2, 'Philosophie morale et politique', 'Réflexion sur l''État, le droit, la morale et la vie politique.', array['État', 'Droit', 'Morale', 'Morale utilitaire', 'Morale du sentiment', 'Morale rationnelle', 'Droits de l''homme et des peuples', 'Liberté', 'Démocratie', 'Bonne gouvernance']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_philo', 'lvl_terminale', 3, 'Épistémologie et esthétique', 'Étude de la connaissance, de l''art et de la vérité.', array['Classification des sciences', 'Méthodes des sciences de la nature', 'Vérité scientifique', 'Science : avantages et inconvénients', 'Art', 'Art africain']::text[], null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geol', 'lvl_11', 1, 'Géologie', 'Introduction aux sciences de la Terre selon le référentiel du profil SE.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geol', 'lvl_12', 1, 'Géologie', 'Approfondissement des sciences de la Terre.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_geol', 'lvl_terminale', 1, 'Géologie', 'Géologie évaluée dans le cadre de la Bio-Géologie en SE.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_ecm', 'lvl_7', 1, 'Éducation civique et morale', 'Formation civique et morale.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_ecm', 'lvl_8', 1, 'Éducation civique et morale', 'Formation civique et morale.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_ecm', 'lvl_9', 1, 'Éducation civique et morale', 'Formation civique et morale.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_ecm', 'lvl_10', 1, 'Éducation civique et morale', 'Formation civique et morale et préparation au cycle suivant.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_7', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_7', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_8', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_8', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_9', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_9', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_10', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_10', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_11', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_11', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_12', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_12', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_terminale', 1, 'Éducation physique et sportive', 'Pratiques physiques et sportives selon la programmation de l''établissement et du référentiel national.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_eps', 'lvl_terminale', 2, 'Activités physiques', 'Programmation pratique d''EPS ; détail des séquences variable selon établissement.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_7', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_8', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_9', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_10', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_11', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_12', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();
insert into curriculum_chapters (subject_id, level_id, position, title, summary, subchapters, outcome, content_status, source_ref) values ('sub_arab', 'lvl_terminale', 1, 'Arabe', 'Enseignement de l''arabe selon le plan d''étude consulté ; détail des chapitres non retrouvé.', '{}', null, 'partiel', 'programme_guineen_college_lycee.json')
  on conflict (subject_id, level_id, position) do update set
    title = excluded.title, summary = excluded.summary,
    subchapters = excluded.subchapters, outcome = excluded.outcome,
    content_status = excluded.content_status,
    source_ref = excluded.source_ref, updated_at = now();

-- Manuels de reference
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_fran', 'Français', 'Le Manguier', '7e à 10e année', 'Manuel de référence couramment utilisé')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_fran', 'Français', 'Indigo Français', '7e à 10e année', 'Manuel complémentaire ou de référence selon l’établissement')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_fran', 'Français', 'À l’écoute du monde', 'Surtout 9e année', 'Support de lecture et de langue')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_fran', 'Français', 'Grammaire française – IPAM', 'Collège', 'Ouvrage de grammaire et d’exercices complémentaire')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_math', 'Mathématiques', 'Collection CIAM — Mathématiques 6e, 5e, 4e, 3e', '7e à 10e année', 'Référence traditionnelle correspondant aux quatre années du collège')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_angl', 'Anglais', 'MOBEL Student’s Book 1, 2, 3 et 4', '7e à 10e année', 'Collection directement liée au programme d’anglais du collège')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_angl', 'Anglais', 'MOBEL Teacher’s Guide 1, 2, 3 et 4', 'Enseignants de 7e à 10e', 'Guide pédagogique associé aux MOBEL')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_phys', 'Physique', 'Sciences physiques 7e, 8e, 9e et 10e années', '7e à 10e année', 'Manuels ou fascicules construits à partir des programmes INRAP/CESPCG')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_chim', 'Chimie', 'Chimie 7e, 8e, 9e et 10e années', '7e à 10e année', 'Manuels ou fascicules fondés sur les programmes de chimie du collège')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_biol', 'Biologie', 'Biologie 7e, 8e, 9e et 10e années', '7e à 10e année', 'Manuels de l’élève et guides de l’enseignant par niveau')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values (null, 'Histoire-géographie', 'Manuels d’histoire et de géographie de collège acquis/diffusés dans le cadre des programmes nationaux', '7e à 10e année', 'La référence exacte varie selon l’édition disponible et l’établissement')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values (null, 'ECM', 'Manuels ou fascicules d’Éducation civique et morale', '7e à 10e année', 'Ressources liées aux programmes nationaux, mais catalogue public unifié non retrouvé')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;
insert into curriculum_textbooks (subject_id, subject_label, title, levels_label, status_note) values ('sub_arab', 'Arabe', 'Manuels de langue arabe et de culture islamique', '7e à 10e année', 'Utilisés dans les filières concernées ; titres à vérifier localement')
  on conflict (subject_label, title) do update set
    subject_id = excluded.subject_id,
    levels_label = excluded.levels_label,
    status_note = excluded.status_note;

commit;
