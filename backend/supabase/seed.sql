-- Genere par supabase/generate-seed.mjs — ne pas modifier a la main.
-- Referentiel et donnees de demonstration, identiques a ceux du mobile.

begin;

-- Matieres (§8)
insert into subjects (id, name, code, sort_order) values ('sub_math', 'Mathematiques', 'MATH', 1)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_phys', 'Physique', 'PHYS', 2)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_chim', 'Chimie', 'CHIM', 3)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_fran', 'Francais', 'FRAN', 4)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_angl', 'Anglais', 'ANGL', 5)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_info', 'Informatique', 'INFO', 6)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_econ', 'Economie', 'ECON', 7)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_comp', 'Comptabilite', 'COMP', 8)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_droi', 'Droit', 'DROI', 9)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_hist', 'Histoire', 'HIST', 10)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_geog', 'Geographie', 'GEOG', 11)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_biol', 'Biologie', 'BIOL', 12)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_geol', 'Geologie', 'GEOL', 13)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_philo', 'Philosophie', 'PHIL', 14)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_ecm', 'Éducation civique et morale', 'ECM', 15)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_eps', 'Éducation physique et sportive', 'EPS', 16)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_medc', 'Médecine', 'MEDC', 17)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_phar', 'Pharmacie', 'PHAR', 18)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_gest', 'Gestion', 'GEST', 19)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_mark', 'Marketing', 'MARK', 20)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_gciv', 'Génie civil', 'GCIV', 21)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_gele', 'Génie électrique', 'GELE', 22)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_tele', 'Télécommunications', 'TELE', 23)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_spol', 'Sciences politiques', 'SPOL', 24)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;
insert into subjects (id, name, code, sort_order) values ('sub_arab', 'Arabe', 'ARAB', 25)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;

-- Niveaux (§9)
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_primaire', 'Primaire', 'PRIMAIRE', 'PRIMARY', 1, 'PRIMAIRE', true)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_college', 'Collège', 'COLLEGE', 'SECONDARY', 2, 'COLLEGE', true)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_7', '7ème année', 'AN7', 'SECONDARY', 3, 'COLLEGE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_8', '8ème année', 'AN8', 'SECONDARY', 4, 'COLLEGE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_9', '9ème année', 'AN9', 'SECONDARY', 5, 'COLLEGE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_10', '10ème année', 'AN10', 'SECONDARY', 6, 'COLLEGE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_lycee', 'Lycée', 'LYCEE', 'SECONDARY', 7, 'LYCEE', true)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_11', '11ème année', 'AN11', 'SECONDARY', 8, 'LYCEE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_12', '12ème année', 'AN12', 'SECONDARY', 9, 'LYCEE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_terminale', 'Terminale', 'TLE', 'SECONDARY', 10, 'LYCEE', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_l1', 'L1', 'L1', 'UNIVERSITY', 11, 'SUPERIEUR', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_l2', 'L2', 'L2', 'UNIVERSITY', 12, 'SUPERIEUR', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_l3', 'L3', 'L3', 'UNIVERSITY', 13, 'SUPERIEUR', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_m1', 'Master 1', 'M1', 'UNIVERSITY', 14, 'SUPERIEUR', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_m2', 'Master 2', 'M2', 'UNIVERSITY', 15, 'SUPERIEUR', false)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;
insert into levels (id, name, code, category, sort_order, cycle, grouping) values ('lvl_diplome', 'Diplômé', 'DIPL', 'GRADUATE', 16, 'DIPLOME', true)
  on conflict (id) do update set name = excluded.name,
    sort_order = excluded.sort_order, category = excluded.category,
    cycle = excluded.cycle, grouping = excluded.grouping;

-- Tests et banques de questions (§10)
insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_math_l2', 'sub_math', 'lvl_l2', 'Mathematiques — L2', 60, 20, 70, 'Test individuel et chronometre. Une seule reponse par question. Les reponses ne sont plus modifiables apres soumission. Le test se poursuit meme sans connexion Internet.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q1', 'test_math_l2', 'Quelle est la dimension de l''espace vectoriel R^3 ?', '[{"key":"A","text":"2"},{"key":"B","text":"3"},{"key":"C","text":"4"},{"key":"D","text":"9"}]'::jsonb, 'B', 'Algebre', 0, 1, 'R^3 admet la base canonique (e1, e2, e3), donc sa dimension vaut 3.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q2', 'test_math_l2', 'Soit f : R^4 -> R^2 une application lineaire surjective. Quelle est la dimension de son noyau ?', '[{"key":"A","text":"0"},{"key":"B","text":"1"},{"key":"C","text":"2"},{"key":"D","text":"4"}]'::jsonb, 'C', 'Algebre', 1, 3, 'Theoreme du rang : dim ker f = dim R^4 - rang f = 4 - 2 = 2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q3', 'test_math_l2', 'Le determinant de la matrice [[3, 1], [2, 4]] vaut :', '[{"key":"A","text":"10"},{"key":"B","text":"14"},{"key":"C","text":"12"},{"key":"D","text":"5"}]'::jsonb, 'A', 'Algebre', 2, 1, 'det = 3 x 4 - 1 x 2 = 12 - 2 = 10.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q4', 'test_math_l2', 'Les valeurs propres de la matrice diagonale diag(2, -1, 5) sont :', '[{"key":"A","text":"2, 1, 5"},{"key":"B","text":"0, 0, 0"},{"key":"C","text":"2, -1, 5"},{"key":"D","text":"-2, 1, -5"}]'::jsonb, 'C', 'Algebre', 3, 2, 'Pour une matrice diagonale, les valeurs propres sont les coefficients diagonaux.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q5', 'test_math_l2', 'Une matrice carree A est inversible si et seulement si :', '[{"key":"A","text":"sa trace est nulle"},{"key":"B","text":"son determinant est non nul"},{"key":"C","text":"elle est symetrique"},{"key":"D","text":"tous ses coefficients sont non nuls"}]'::jsonb, 'B', 'Algebre', 4, 2, 'A est inversible si et seulement si det(A) est different de 0.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q6', 'test_math_l2', 'Le produit d''une matrice 3x4 par une matrice 4x2 donne une matrice de taille :', '[{"key":"A","text":"3x2"},{"key":"B","text":"4x4"},{"key":"C","text":"2x3"},{"key":"D","text":"12x8"}]'::jsonb, 'A', 'Algebre', 5, 1, 'Le produit d''une matrice (m,n) par une matrice (n,p) est de taille (m,p).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q7', 'test_math_l2', 'Les vecteurs (1, 2) et (2, 4) de R^2 sont :', '[{"key":"A","text":"libres"},{"key":"B","text":"lies"},{"key":"C","text":"orthogonaux"},{"key":"D","text":"une base de R^2"}]'::jsonb, 'B', 'Algebre', 6, 2, '(2, 4) = 2 x (1, 2) : les deux vecteurs sont colineaires, donc lies.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q8', 'test_math_l2', 'Combien de vecteurs comporte toute base de R^2 ?', '[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]'::jsonb, 'B', 'Algebre', 7, 1, 'Toutes les bases d''un espace de dimension 2 comportent exactement 2 vecteurs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q9', 'test_math_l2', 'La trace de la matrice [[4, 7], [2, -1]] vaut :', '[{"key":"A","text":"3"},{"key":"B","text":"11"},{"key":"C","text":"-18"},{"key":"D","text":"5"}]'::jsonb, 'A', 'Algebre', 8, 1, 'La trace est la somme des coefficients diagonaux : 4 + (-1) = 3.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q10', 'test_math_l2', 'Pour deux matrices A et B compatibles, (AB) transposee est egale a :', '[{"key":"A","text":"A^T B^T"},{"key":"B","text":"B^T A^T"},{"key":"C","text":"AB"},{"key":"D","text":"(BA)^T"}]'::jsonb, 'B', 'Algebre', 9, 2, 'La transposition inverse l''ordre du produit : (AB)^T = B^T A^T.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q11', 'test_math_l2', 'Le noyau de l''application identite de R^n est :', '[{"key":"A","text":"R^n tout entier"},{"key":"B","text":"le sous-espace reduit au vecteur nul"},{"key":"C","text":"de dimension n"},{"key":"D","text":"l''ensemble vide"}]'::jsonb, 'B', 'Algebre', 10, 2, 'id(x) = 0 implique x = 0, donc le noyau est reduit au vecteur nul.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q12', 'test_math_l2', 'Les valeurs propres d''une matrice triangulaire sont :', '[{"key":"A","text":"ses coefficients diagonaux"},{"key":"B","text":"toujours nulles"},{"key":"C","text":"la somme de ses lignes"},{"key":"D","text":"egales a son determinant"}]'::jsonb, 'A', 'Algebre', 11, 2, 'Le polynome caracteristique d''une matrice triangulaire est le produit des (lambda - a_ii).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q13', 'test_math_l2', 'Pour deux matrices carrees A et B de meme taille, det(AB) est egal a :', '[{"key":"A","text":"det A + det B"},{"key":"B","text":"det A x det B"},{"key":"C","text":"det(A + B)"},{"key":"D","text":"det A - det B"}]'::jsonb, 'B', 'Algebre', 12, 2, 'Le determinant est multiplicatif : det(AB) = det(A) x det(B).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q14', 'test_math_l2', 'Quelle est la dimension de l''espace vectoriel des matrices carrees 2x2 a coefficients reels ?', '[{"key":"A","text":"2"},{"key":"B","text":"3"},{"key":"C","text":"4"},{"key":"D","text":"8"}]'::jsonb, 'C', 'Algebre', 13, 2, 'Une matrice 2x2 possede 4 coefficients libres, donc la dimension vaut 4.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q15', 'test_math_l2', 'Le systeme { x + y = 5 ; x - y = 1 } admet pour unique solution :', '[{"key":"A","text":"(3, 2)"},{"key":"B","text":"(2, 3)"},{"key":"C","text":"(4, 1)"},{"key":"D","text":"(1, 4)"}]'::jsonb, 'A', 'Algebre', 14, 1, 'En additionnant les deux equations : 2x = 6 donc x = 3, puis y = 2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q16', 'test_math_l2', 'Quelle est la derivee de f(x) = x^2 + 3x ?', '[{"key":"A","text":"2x + 3"},{"key":"B","text":"2x"},{"key":"C","text":"x + 3"},{"key":"D","text":"x^2 + 3"}]'::jsonb, 'A', 'Analyse', 15, 1, 'La derivee de x^2 vaut 2x et celle de 3x vaut 3, d''ou 2x + 3.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q17', 'test_math_l2', 'La limite de sin(x)/x lorsque x tend vers 0 vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"1"},{"key":"C","text":"plus l''infini"},{"key":"D","text":"elle n''existe pas"}]'::jsonb, 'B', 'Analyse', 16, 2, 'C''est une limite de reference : sin(x)/x tend vers 1 en 0.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q18', 'test_math_l2', 'Une primitive de f(x) = 1/x sur l''intervalle ]0, +infini[ est :', '[{"key":"A","text":"-1/x^2"},{"key":"B","text":"ln(x)"},{"key":"C","text":"x ln(x)"},{"key":"D","text":"1/(2x^2)"}]'::jsonb, 'B', 'Analyse', 17, 2, 'La derivee de ln(x) vaut 1/x sur ]0, +infini[.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q19', 'test_math_l2', 'La derivee de f(x) = e^x est :', '[{"key":"A","text":"x e^(x-1)"},{"key":"B","text":"e^x"},{"key":"C","text":"1"},{"key":"D","text":"e"}]'::jsonb, 'B', 'Analyse', 18, 1, 'La fonction exponentielle est egale a sa propre derivee.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q20', 'test_math_l2', 'La derivee de f(x) = ln(x) sur ]0, +infini[ est :', '[{"key":"A","text":"1/x"},{"key":"B","text":"ln(x)/x"},{"key":"C","text":"x"},{"key":"D","text":"-1/x^2"}]'::jsonb, 'A', 'Analyse', 19, 1, 'La derivee du logarithme neperien vaut 1/x.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q21', 'test_math_l2', 'L''integrale de 0 a 1 de x dx vaut :', '[{"key":"A","text":"1"},{"key":"B","text":"1/2"},{"key":"C","text":"1/3"},{"key":"D","text":"0"}]'::jsonb, 'B', 'Analyse', 20, 2, 'Une primitive de x est x^2/2, donc l''integrale vaut 1/2 - 0 = 1/2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q22', 'test_math_l2', 'Une fonction derivable en un point est necessairement :', '[{"key":"A","text":"continue en ce point"},{"key":"B","text":"constante"},{"key":"C","text":"croissante"},{"key":"D","text":"bornee"}]'::jsonb, 'A', 'Analyse', 21, 2, 'La derivabilite en un point entraine la continuite en ce point ; la reciproque est fausse.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q23', 'test_math_l2', 'La serie geometrique de raison q converge si et seulement si :', '[{"key":"A","text":"q > 1"},{"key":"B","text":"|q| < 1"},{"key":"C","text":"q = 1"},{"key":"D","text":"q < 0"}]'::jsonb, 'B', 'Analyse', 22, 2, 'La somme des q^n converge exactement lorsque la valeur absolue de q est strictement inferieure a 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q24', 'test_math_l2', 'Le developpement limite de e^x a l''ordre 2 au voisinage de 0 est :', '[{"key":"A","text":"1 + x"},{"key":"B","text":"1 + x + x^2/2"},{"key":"C","text":"x + x^2"},{"key":"D","text":"1 + x^2"}]'::jsonb, 'B', 'Analyse', 23, 3, 'e^x = 1 + x + x^2/2 + o(x^2).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q25', 'test_math_l2', 'Le theoreme des valeurs intermediaires s''applique a une fonction :', '[{"key":"A","text":"continue sur un intervalle"},{"key":"B","text":"derivable partout"},{"key":"C","text":"monotone"},{"key":"D","text":"polynomiale uniquement"}]'::jsonb, 'A', 'Analyse', 24, 2, 'La continuite sur un intervalle suffit a garantir la propriete des valeurs intermediaires.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q26', 'test_math_l2', 'La derivee de f(x) = (3x + 1)^2 est :', '[{"key":"A","text":"6(3x + 1)"},{"key":"B","text":"2(3x + 1)"},{"key":"C","text":"9x^2"},{"key":"D","text":"6x + 1"}]'::jsonb, 'A', 'Analyse', 25, 2, 'Derivee d''une composee : 2(3x + 1) x 3 = 6(3x + 1).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q27', 'test_math_l2', 'La limite de (1 + 1/n)^n lorsque n tend vers l''infini vaut :', '[{"key":"A","text":"1"},{"key":"B","text":"e"},{"key":"C","text":"plus l''infini"},{"key":"D","text":"0"}]'::jsonb, 'B', 'Analyse', 26, 3, 'C''est la definition classique du nombre e.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q28', 'test_math_l2', 'La formule d''integration par parties donne l''integrale de u''v sous la forme :', '[{"key":"A","text":"[uv] moins l''integrale de u v''"},{"key":"B","text":"[uv] plus l''integrale de u v''"},{"key":"C","text":"le produit des integrales de u et v"},{"key":"D","text":"[u''v''] moins l''integrale de uv"}]'::jsonb, 'A', 'Analyse', 27, 3, 'Integrale de u''v = [uv] - integrale de u v''.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q29', 'test_math_l2', 'La serie de terme general 1/n^2, pour n superieur ou egal a 1, est :', '[{"key":"A","text":"divergente"},{"key":"B","text":"convergente"},{"key":"C","text":"alternee"},{"key":"D","text":"geometrique"}]'::jsonb, 'B', 'Analyse', 28, 3, 'Serie de Riemann d''exposant 2 : elle converge car l''exposant est strictement superieur a 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q30', 'test_math_l2', 'Si la derivee seconde de f est strictement positive sur un intervalle, alors f y est :', '[{"key":"A","text":"concave"},{"key":"B","text":"convexe"},{"key":"C","text":"decroissante"},{"key":"D","text":"constante"}]'::jsonb, 'B', 'Analyse', 29, 2, 'Une derivee seconde positive caracterise la convexite.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q31', 'test_math_l2', 'Pour deux evenements A et B, P(A union B) est egal a :', '[{"key":"A","text":"P(A) + P(B)"},{"key":"B","text":"P(A) + P(B) - P(A inter B)"},{"key":"C","text":"P(A) x P(B)"},{"key":"D","text":"P(A) - P(B)"}]'::jsonb, 'B', 'Probabilites', 30, 2, 'Formule d''inclusion-exclusion, valable pour tous evenements.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q32', 'test_math_l2', 'On lance un de equilibre a six faces. Quelle est la probabilite d''obtenir un nombre pair ?', '[{"key":"A","text":"1/6"},{"key":"B","text":"1/3"},{"key":"C","text":"1/2"},{"key":"D","text":"2/3"}]'::jsonb, 'C', 'Probabilites', 31, 1, 'Trois faces paires sur six issues equiprobables : 3/6 = 1/2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q33', 'test_math_l2', 'L''esperance d''une variable aleatoire suivant la loi binomiale B(n, p) vaut :', '[{"key":"A","text":"np(1 - p)"},{"key":"B","text":"p/n"},{"key":"C","text":"np"},{"key":"D","text":"n/p"}]'::jsonb, 'C', 'Probabilites', 32, 2, 'L''esperance d''une binomiale vaut np ; np(1 - p) en est la variance.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q34', 'test_math_l2', 'La variance d''une loi binomiale B(n, p) vaut :', '[{"key":"A","text":"np"},{"key":"B","text":"np(1 - p)"},{"key":"C","text":"n^2 p"},{"key":"D","text":"p(1 - p)"}]'::jsonb, 'B', 'Probabilites', 33, 2, 'Somme de n variables de Bernoulli independantes, de variance p(1 - p) chacune.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q35', 'test_math_l2', 'La probabilite conditionnelle P(A sachant B) est definie par :', '[{"key":"A","text":"P(A) / P(B)"},{"key":"B","text":"P(A inter B) / P(B)"},{"key":"C","text":"P(A inter B) / P(A)"},{"key":"D","text":"P(A) x P(B)"}]'::jsonb, 'B', 'Probabilites', 34, 2, 'Definition, valable lorsque P(B) est non nulle.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q36', 'test_math_l2', 'Deux evenements A et B sont independants si :', '[{"key":"A","text":"P(A inter B) = 0"},{"key":"B","text":"P(A inter B) = P(A) x P(B)"},{"key":"C","text":"P(A union B) = 1"},{"key":"D","text":"P(A) = P(B)"}]'::jsonb, 'B', 'Probabilites', 35, 2, 'L''independance est la factorisation de la probabilite de l''intersection.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q37', 'test_math_l2', 'Pour une loi uniforme sur [0, 1], la probabilite que X soit inferieur a 0,3 vaut :', '[{"key":"A","text":"0,7"},{"key":"B","text":"0,5"},{"key":"C","text":"0,03"},{"key":"D","text":"0,3"}]'::jsonb, 'D', 'Probabilites', 36, 2, 'Pour la loi uniforme sur [0, 1], P(X < t) = t.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q38', 'test_math_l2', 'La formule de Bayes permet de calculer :', '[{"key":"A","text":"l''esperance d''une somme"},{"key":"B","text":"P(A sachant B) a partir de P(B sachant A)"},{"key":"C","text":"la variance d''un produit"},{"key":"D","text":"la densite de la loi normale"}]'::jsonb, 'B', 'Probabilites', 37, 3, 'Bayes permet d''inverser le conditionnement entre deux evenements.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q39', 'test_math_l2', 'Le nombre de combinaisons de 2 elements parmi 5 vaut :', '[{"key":"A","text":"20"},{"key":"B","text":"25"},{"key":"C","text":"10"},{"key":"D","text":"5"}]'::jsonb, 'C', 'Probabilites', 38, 2, 'C(5,2) = 5! / (2! x 3!) = 10.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q40', 'test_math_l2', 'L''esperance et l''ecart-type de la loi normale centree reduite valent respectivement :', '[{"key":"A","text":"1 et 0"},{"key":"B","text":"0 et 1"},{"key":"C","text":"0 et 0"},{"key":"D","text":"1 et 1"}]'::jsonb, 'B', 'Probabilites', 39, 2, 'La loi normale centree reduite est notee N(0, 1) : esperance 0, ecart-type 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q41', 'test_math_l2', 'Une urne contient 3 boules rouges et 2 boules noires. On tire une boule au hasard : la probabilite d''obtenir une boule rouge est :', '[{"key":"A","text":"2/5"},{"key":"B","text":"3/5"},{"key":"C","text":"1/2"},{"key":"D","text":"3/2"}]'::jsonb, 'B', 'Probabilites', 40, 1, '3 cas favorables sur 5 issues equiprobables.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q42', 'test_math_l2', 'L''esperance du resultat d''un de equilibre a six faces vaut :', '[{"key":"A","text":"3"},{"key":"B","text":"3,5"},{"key":"C","text":"4"},{"key":"D","text":"2,5"}]'::jsonb, 'B', 'Probabilites', 41, 2, '(1 + 2 + 3 + 4 + 5 + 6) / 6 = 21/6 = 3,5.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q43', 'test_math_l2', 'L''ecart-type d''une variable aleatoire est egal a :', '[{"key":"A","text":"le carre de la variance"},{"key":"B","text":"l''esperance"},{"key":"C","text":"la racine carree de la variance"},{"key":"D","text":"la variance divisee par n"}]'::jsonb, 'C', 'Probabilites', 42, 1, 'Par definition, l''ecart-type est la racine carree de la variance.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q44', 'test_math_l2', 'La loi de Poisson de parametre lambda a pour esperance :', '[{"key":"A","text":"lambda au carre"},{"key":"B","text":"1/lambda"},{"key":"C","text":"la racine de lambda"},{"key":"D","text":"lambda"}]'::jsonb, 'D', 'Probabilites', 43, 2, 'Pour la loi de Poisson, esperance et variance valent toutes deux lambda.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q45', 'test_math_l2', 'Si P(A) = 0,3, alors la probabilite de l''evenement contraire vaut :', '[{"key":"A","text":"0,3"},{"key":"B","text":"0,7"},{"key":"C","text":"1,3"},{"key":"D","text":"0"}]'::jsonb, 'B', 'Probabilites', 44, 1, 'P(non A) = 1 - P(A) = 1 - 0,3 = 0,7.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q46', 'test_math_l2', 'Le produit scalaire des vecteurs u = (1, 2) et v = (3, -1) vaut :', '[{"key":"A","text":"5"},{"key":"B","text":"1"},{"key":"C","text":"-1"},{"key":"D","text":"7"}]'::jsonb, 'B', 'Geometrie', 45, 1, '1 x 3 + 2 x (-1) = 3 - 2 = 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q47', 'test_math_l2', 'La norme du vecteur u = (3, 4) vaut :', '[{"key":"A","text":"25"},{"key":"B","text":"7"},{"key":"C","text":"5"},{"key":"D","text":"12"}]'::jsonb, 'C', 'Geometrie', 46, 1, 'Racine de (3^2 + 4^2) = racine de 25 = 5.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q48', 'test_math_l2', 'L''equation y = 2x + 1 represente dans le plan :', '[{"key":"A","text":"un cercle"},{"key":"B","text":"une parabole"},{"key":"C","text":"une droite de coefficient directeur 1"},{"key":"D","text":"une droite de coefficient directeur 2"}]'::jsonb, 'D', 'Geometrie', 47, 1, 'Equation affine : droite de pente 2 et d''ordonnee a l''origine 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q49', 'test_math_l2', 'La distance entre les points A(0, 0) et B(3, 4) vaut :', '[{"key":"A","text":"5"},{"key":"B","text":"7"},{"key":"C","text":"3"},{"key":"D","text":"4"}]'::jsonb, 'A', 'Geometrie', 48, 1, 'Racine de (3^2 + 4^2) = 5.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q50', 'test_math_l2', 'Le produit vectoriel de deux vecteurs non colineaires de R^3 est un vecteur :', '[{"key":"A","text":"colineaire au premier"},{"key":"B","text":"orthogonal aux deux vecteurs"},{"key":"C","text":"toujours nul"},{"key":"D","text":"de norme 1"}]'::jsonb, 'B', 'Geometrie', 49, 2, 'Le produit vectoriel est orthogonal au plan engendre par les deux vecteurs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q51', 'test_math_l2', 'L''equation x^2 + y^2 = 9 represente :', '[{"key":"A","text":"une droite"},{"key":"B","text":"une ellipse"},{"key":"C","text":"un cercle de rayon 3"},{"key":"D","text":"un cercle de rayon 9"}]'::jsonb, 'C', 'Geometrie', 50, 2, 'Cercle de centre l''origine et de rayon la racine de 9, soit 3.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q52', 'test_math_l2', 'Deux vecteurs non nuls sont orthogonaux si et seulement si :', '[{"key":"A","text":"leur produit scalaire est nul"},{"key":"B","text":"leur somme est nulle"},{"key":"C","text":"ils ont la meme norme"},{"key":"D","text":"ils sont colineaires"}]'::jsonb, 'A', 'Geometrie', 51, 1, 'L''orthogonalite se caracterise par l''annulation du produit scalaire.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q53', 'test_math_l2', 'Dans l''espace, l''equation 2x + 3y - z = 5 represente :', '[{"key":"A","text":"une droite"},{"key":"B","text":"une sphere"},{"key":"C","text":"un point"},{"key":"D","text":"un plan"}]'::jsonb, 'D', 'Geometrie', 52, 2, 'Une equation lineaire a trois inconnues decrit un plan affine.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q54', 'test_math_l2', 'L''aire d''un triangle de base 6 et de hauteur 4 vaut :', '[{"key":"A","text":"24"},{"key":"B","text":"12"},{"key":"C","text":"10"},{"key":"D","text":"6"}]'::jsonb, 'B', 'Geometrie', 53, 1, 'Aire = (base x hauteur) / 2 = (6 x 4) / 2 = 12.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q55', 'test_math_l2', 'Si le produit scalaire de u et v est nul, avec u et v non nuls, l''angle entre u et v vaut :', '[{"key":"A","text":"0 degre"},{"key":"B","text":"45 degres"},{"key":"C","text":"90 degres"},{"key":"D","text":"180 degres"}]'::jsonb, 'C', 'Geometrie', 54, 2, 'Un produit scalaire nul correspond a un angle droit.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q56', 'test_math_l2', 'Le volume du parallelepipede construit sur trois vecteurs de R^3 est donne par :', '[{"key":"A","text":"la valeur absolue de leur produit mixte"},{"key":"B","text":"la somme de leurs normes"},{"key":"C","text":"leur produit scalaire"},{"key":"D","text":"la norme de leur produit vectoriel"}]'::jsonb, 'A', 'Geometrie', 55, 3, 'Le produit mixte, en valeur absolue, donne le volume du parallelepipede.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q57', 'test_math_l2', 'Les coordonnees du milieu du segment [AB], avec A(2, 4) et B(6, 8), sont :', '[{"key":"A","text":"(8, 12)"},{"key":"B","text":"(4, 6)"},{"key":"C","text":"(2, 2)"},{"key":"D","text":"(3, 4)"}]'::jsonb, 'B', 'Geometrie', 56, 1, 'Milieu = ((2 + 6)/2, (4 + 8)/2) = (4, 6).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q58', 'test_math_l2', 'Deux droites du plan ayant le meme coefficient directeur mais des ordonnees a l''origine differentes sont :', '[{"key":"A","text":"secantes"},{"key":"B","text":"confondues"},{"key":"C","text":"strictement paralleles"},{"key":"D","text":"perpendiculaires"}]'::jsonb, 'C', 'Geometrie', 57, 2, 'Meme pente et ordonnees a l''origine distinctes : paralleles sans point commun.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q59', 'test_math_l2', 'L''equation x^2 + y^2 + z^2 = 16 represente dans l''espace :', '[{"key":"A","text":"une sphere de rayon 16"},{"key":"B","text":"un plan"},{"key":"C","text":"un cercle"},{"key":"D","text":"une sphere de rayon 4"}]'::jsonb, 'D', 'Geometrie', 58, 2, 'Sphere de centre l''origine et de rayon la racine de 16, soit 4.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l2_q60', 'test_math_l2', 'La projection orthogonale d''un vecteur u sur un vecteur unitaire e est donnee par :', '[{"key":"A","text":"le produit vectoriel de u et e"},{"key":"B","text":"u + e"},{"key":"C","text":"le produit scalaire de u et e, multiplie par e"},{"key":"D","text":"la norme de u multipliee par e"}]'::jsonb, 'C', 'Geometrie', 59, 3, 'Pour e unitaire, la projection vaut (u . e) e.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_math_l1', 'sub_math', 'lvl_l1', 'Mathematiques — L1', 41, 20, 70, 'Test individuel et chronometre. Une seule reponse par question. Les reponses ne sont plus modifiables apres soumission.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q1', 'test_math_l1', 'L''ensemble des nombres reels est note :', '[{"key":"A","text":"N"},{"key":"B","text":"Z"},{"key":"C","text":"Q"},{"key":"D","text":"R"}]'::jsonb, 'D', 'Algebre', 0, 1, 'R designe l''ensemble des nombres reels.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q2', 'test_math_l1', 'La factorisation de x^2 - 9 est :', '[{"key":"A","text":"(x - 3)(x + 3)"},{"key":"B","text":"(x - 9)(x + 1)"},{"key":"C","text":"(x - 3)^2"},{"key":"D","text":"x(x - 9)"}]'::jsonb, 'A', 'Algebre', 1, 1, 'Identite remarquable a^2 - b^2 = (a - b)(a + b).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q3', 'test_math_l1', 'Le discriminant de l''equation x^2 - 5x + 6 = 0 vaut :', '[{"key":"A","text":"1"},{"key":"B","text":"-1"},{"key":"C","text":"25"},{"key":"D","text":"49"}]'::jsonb, 'A', 'Algebre', 2, 2, 'delta = 25 - 24 = 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q4', 'test_math_l1', 'Les solutions de x^2 - 5x + 6 = 0 sont :', '[{"key":"A","text":"2 et 3"},{"key":"B","text":"-2 et -3"},{"key":"C","text":"1 et 6"},{"key":"D","text":"5 et 6"}]'::jsonb, 'A', 'Algebre', 3, 2, 'Somme 5 et produit 6 : les racines sont 2 et 3.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q5', 'test_math_l1', 'La valeur de 2^5 est :', '[{"key":"A","text":"10"},{"key":"B","text":"25"},{"key":"C","text":"32"},{"key":"D","text":"16"}]'::jsonb, 'C', 'Algebre', 4, 1, '2^5 = 32.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q6', 'test_math_l1', 'L''expression (a + b)^2 est egale a :', '[{"key":"A","text":"a^2 + b^2"},{"key":"B","text":"a^2 + 2ab + b^2"},{"key":"C","text":"a^2 - 2ab + b^2"},{"key":"D","text":"2a + 2b"}]'::jsonb, 'B', 'Algebre', 5, 1, 'Identite remarquable du carre d''une somme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q7', 'test_math_l1', 'Le determinant de [[1, 2], [3, 4]] vaut :', '[{"key":"A","text":"-2"},{"key":"B","text":"2"},{"key":"C","text":"10"},{"key":"D","text":"-10"}]'::jsonb, 'A', 'Algebre', 6, 2, '1 x 4 - 2 x 3 = 4 - 6 = -2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q8', 'test_math_l1', 'La matrice identite d''ordre 2 est :', '[{"key":"A","text":"[[0,0],[0,0]]"},{"key":"B","text":"[[1,1],[1,1]]"},{"key":"C","text":"[[1,0],[0,1]]"},{"key":"D","text":"[[0,1],[1,0]]"}]'::jsonb, 'C', 'Algebre', 7, 1, 'Des 1 sur la diagonale et des 0 ailleurs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q9', 'test_math_l1', 'Le nombre complexe i verifie :', '[{"key":"A","text":"i^2 = 1"},{"key":"B","text":"i^2 = -1"},{"key":"C","text":"i = 0"},{"key":"D","text":"i^2 = i"}]'::jsonb, 'B', 'Algebre', 8, 2, 'Definition de l''unite imaginaire.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q10', 'test_math_l1', 'Le module du nombre complexe 3 + 4i vaut :', '[{"key":"A","text":"7"},{"key":"B","text":"5"},{"key":"C","text":"25"},{"key":"D","text":"12"}]'::jsonb, 'B', 'Algebre', 9, 2, 'Racine de (9 + 16) = 5.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q11', 'test_math_l1', 'La derivee de f(x) = x^3 est :', '[{"key":"A","text":"3x^2"},{"key":"B","text":"x^2"},{"key":"C","text":"3x"},{"key":"D","text":"x^4/4"}]'::jsonb, 'A', 'Analyse', 10, 1, 'Derivee de x^n : n x^(n-1).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q12', 'test_math_l1', 'La derivee de f(x) = 5 est :', '[{"key":"A","text":"5"},{"key":"B","text":"0"},{"key":"C","text":"x"},{"key":"D","text":"1"}]'::jsonb, 'B', 'Analyse', 11, 1, 'La derivee d''une constante est nulle.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q13', 'test_math_l1', 'Une primitive de f(x) = 2x est :', '[{"key":"A","text":"x^2"},{"key":"B","text":"2"},{"key":"C","text":"x^2/2"},{"key":"D","text":"2x^2"}]'::jsonb, 'A', 'Analyse', 12, 1, 'La derivee de x^2 vaut 2x.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q14', 'test_math_l1', 'La limite de 1/x lorsque x tend vers plus l''infini vaut :', '[{"key":"A","text":"1"},{"key":"B","text":"plus l''infini"},{"key":"C","text":"0"},{"key":"D","text":"-1"}]'::jsonb, 'C', 'Analyse', 13, 1, '1/x tend vers 0 quand x tend vers l''infini.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q15', 'test_math_l1', 'La fonction exponentielle est definie sur :', '[{"key":"A","text":"]0, +infini["},{"key":"B","text":"R tout entier"},{"key":"C","text":"[0, +infini["},{"key":"D","text":"R prive de 0"}]'::jsonb, 'B', 'Analyse', 14, 2, 'L''exponentielle est definie sur R et strictement positive.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q16', 'test_math_l1', 'La fonction logarithme neperien est definie sur :', '[{"key":"A","text":"R"},{"key":"B","text":"]0, +infini["},{"key":"C","text":"[0, +infini["},{"key":"D","text":"R prive de 0"}]'::jsonb, 'B', 'Analyse', 15, 2, 'ln n''est definie que pour les reels strictement positifs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q17', 'test_math_l1', 'ln(ab) est egal a :', '[{"key":"A","text":"ln(a) x ln(b)"},{"key":"B","text":"ln(a) + ln(b)"},{"key":"C","text":"ln(a) - ln(b)"},{"key":"D","text":"ln(a)/ln(b)"}]'::jsonb, 'B', 'Analyse', 16, 2, 'Le logarithme transforme un produit en somme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q18', 'test_math_l1', 'La derivee de f(x) = 1/x sur R prive de 0 est :', '[{"key":"A","text":"ln(x)"},{"key":"B","text":"-1/x^2"},{"key":"C","text":"1/x^2"},{"key":"D","text":"-1/x"}]'::jsonb, 'B', 'Analyse', 17, 2, 'Derivee de x^(-1) : -x^(-2).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q19', 'test_math_l1', 'Une fonction dont la derivee est positive sur un intervalle y est :', '[{"key":"A","text":"croissante"},{"key":"B","text":"decroissante"},{"key":"C","text":"constante"},{"key":"D","text":"nulle"}]'::jsonb, 'A', 'Analyse', 18, 1, 'Le signe de la derivee donne le sens de variation.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q20', 'test_math_l1', 'La suite u_n = 1/n converge vers :', '[{"key":"A","text":"1"},{"key":"B","text":"0"},{"key":"C","text":"plus l''infini"},{"key":"D","text":"elle diverge"}]'::jsonb, 'B', 'Analyse', 19, 2, '1/n tend vers 0 quand n tend vers l''infini.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q21', 'test_math_l1', 'Une suite geometrique de raison 2 et de premier terme 3 a pour terme general :', '[{"key":"A","text":"3 + 2n"},{"key":"B","text":"3 x 2^n"},{"key":"C","text":"2 x 3^n"},{"key":"D","text":"6n"}]'::jsonb, 'B', 'Analyse', 20, 2, 'u_n = u_0 x q^n = 3 x 2^n.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q22', 'test_math_l1', 'La somme des n premiers entiers naturels non nuls vaut :', '[{"key":"A","text":"n(n + 1)/2"},{"key":"B","text":"n^2"},{"key":"C","text":"n(n - 1)/2"},{"key":"D","text":"2n"}]'::jsonb, 'A', 'Analyse', 21, 2, 'Formule de la somme arithmetique.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q23', 'test_math_l1', 'L''integrale de 0 a 2 de la fonction constante 3 vaut :', '[{"key":"A","text":"3"},{"key":"B","text":"6"},{"key":"C","text":"2"},{"key":"D","text":"5"}]'::jsonb, 'B', 'Analyse', 22, 1, '3 x (2 - 0) = 6.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q24', 'test_math_l1', 'Une suite arithmetique de raison r verifie :', '[{"key":"A","text":"u_(n+1) = u_n x r"},{"key":"B","text":"u_(n+1) = u_n + r"},{"key":"C","text":"u_(n+1) = r^n"},{"key":"D","text":"u_(n+1) = u_n / r"}]'::jsonb, 'B', 'Analyse', 23, 1, 'La difference entre deux termes consecutifs est constante.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q25', 'test_math_l1', 'La derivee de f(x) = cos(x) est :', '[{"key":"A","text":"sin(x)"},{"key":"B","text":"-sin(x)"},{"key":"C","text":"cos(x)"},{"key":"D","text":"-cos(x)"}]'::jsonb, 'B', 'Analyse', 24, 2, 'La derivee du cosinus est l''oppose du sinus.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q26', 'test_math_l1', 'Une probabilite est toujours comprise entre :', '[{"key":"A","text":"0 et 1"},{"key":"B","text":"-1 et 1"},{"key":"C","text":"0 et 100"},{"key":"D","text":"1 et 10"}]'::jsonb, 'A', 'Probabilites', 25, 1, 'Par definition, une probabilite appartient a l''intervalle [0, 1].')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q27', 'test_math_l1', 'La probabilite d''obtenir pile avec une piece equilibree est :', '[{"key":"A","text":"1/4"},{"key":"B","text":"1/2"},{"key":"C","text":"1/3"},{"key":"D","text":"1"}]'::jsonb, 'B', 'Probabilites', 26, 1, 'Deux issues equiprobables.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q28', 'test_math_l1', 'Le nombre de facons d''ordonner 4 objets distincts est :', '[{"key":"A","text":"4"},{"key":"B","text":"16"},{"key":"C","text":"24"},{"key":"D","text":"12"}]'::jsonb, 'C', 'Probabilites', 27, 2, '4! = 4 x 3 x 2 x 1 = 24.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q29', 'test_math_l1', 'La probabilite de l''evenement certain vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"0,5"},{"key":"C","text":"1"},{"key":"D","text":"elle depend du cas"}]'::jsonb, 'C', 'Probabilites', 28, 1, 'L''evenement certain a une probabilite egale a 1.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q30', 'test_math_l1', 'On lance deux des equilibres. Le nombre total d''issues possibles est :', '[{"key":"A","text":"12"},{"key":"B","text":"36"},{"key":"C","text":"6"},{"key":"D","text":"21"}]'::jsonb, 'B', 'Probabilites', 29, 2, '6 x 6 = 36 couples possibles.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q31', 'test_math_l1', 'Si A et B sont incompatibles, alors P(A inter B) vaut :', '[{"key":"A","text":"1"},{"key":"B","text":"0"},{"key":"C","text":"P(A) x P(B)"},{"key":"D","text":"P(A) + P(B)"}]'::jsonb, 'B', 'Probabilites', 30, 2, 'Des evenements incompatibles ne peuvent pas se realiser ensemble.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q32', 'test_math_l1', 'La moyenne des valeurs 4, 6, 8 et 10 vaut :', '[{"key":"A","text":"6"},{"key":"B","text":"7"},{"key":"C","text":"8"},{"key":"D","text":"28"}]'::jsonb, 'B', 'Probabilites', 31, 1, '(4 + 6 + 8 + 10) / 4 = 28/4 = 7.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q33', 'test_math_l1', 'La mediane de la serie 2, 5, 7, 9, 12 est :', '[{"key":"A","text":"5"},{"key":"B","text":"7"},{"key":"C","text":"9"},{"key":"D","text":"6"}]'::jsonb, 'B', 'Probabilites', 32, 2, 'La valeur centrale de cette serie ordonnee de 5 termes est 7.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q34', 'test_math_l1', 'La somme des angles d''un triangle vaut :', '[{"key":"A","text":"90 degres"},{"key":"B","text":"180 degres"},{"key":"C","text":"270 degres"},{"key":"D","text":"360 degres"}]'::jsonb, 'B', 'Geometrie', 33, 1, 'Propriete fondamentale du triangle dans le plan euclidien.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q35', 'test_math_l1', 'Le theoreme de Pythagore s''applique dans un triangle :', '[{"key":"A","text":"equilateral"},{"key":"B","text":"rectangle"},{"key":"C","text":"isocele"},{"key":"D","text":"quelconque"}]'::jsonb, 'B', 'Geometrie', 34, 1, 'Il relie les cotes d''un triangle rectangle.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q36', 'test_math_l1', 'L''aire d''un cercle de rayon r vaut :', '[{"key":"A","text":"2 pi r"},{"key":"B","text":"pi r^2"},{"key":"C","text":"pi r"},{"key":"D","text":"4 pi r^2"}]'::jsonb, 'B', 'Geometrie', 35, 1, '2 pi r designe le perimetre, pi r^2 l''aire.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q37', 'test_math_l1', 'Le produit scalaire de (2, 0) et (0, 5) vaut :', '[{"key":"A","text":"10"},{"key":"B","text":"0"},{"key":"C","text":"7"},{"key":"D","text":"-10"}]'::jsonb, 'B', 'Geometrie', 36, 2, '2 x 0 + 0 x 5 = 0 : les vecteurs sont orthogonaux.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q38', 'test_math_l1', 'cos(0) vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"1"},{"key":"C","text":"-1"},{"key":"D","text":"pi"}]'::jsonb, 'B', 'Geometrie', 37, 1, 'Valeur de reference du cosinus en 0.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q39', 'test_math_l1', 'sin^2(x) + cos^2(x) est egal a :', '[{"key":"A","text":"0"},{"key":"B","text":"1"},{"key":"C","text":"2"},{"key":"D","text":"x"}]'::jsonb, 'B', 'Geometrie', 38, 2, 'Identite trigonometrique fondamentale.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q40', 'test_math_l1', 'Le volume d''un cube d''arete 3 vaut :', '[{"key":"A","text":"9"},{"key":"B","text":"18"},{"key":"C","text":"27"},{"key":"D","text":"12"}]'::jsonb, 'C', 'Geometrie', 39, 1, '3^3 = 27.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_l1_q41', 'test_math_l1', 'Deux droites perpendiculaires du plan forment un angle de :', '[{"key":"A","text":"45 degres"},{"key":"B","text":"60 degres"},{"key":"C","text":"90 degres"},{"key":"D","text":"180 degres"}]'::jsonb, 'C', 'Geometrie', 40, 1, 'La perpendicularite correspond a un angle droit.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_math_lycee', 'sub_math', 'lvl_lycee', 'Mathematiques — Lycee', 31, 20, 70, 'Test individuel et chronometre. Une seule reponse par question.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q1', 'test_math_lycee', 'Le developpement de (x + 2)(x - 3) est :', '[{"key":"A","text":"x^2 - x - 6"},{"key":"B","text":"x^2 + x - 6"},{"key":"C","text":"x^2 - 5x - 6"},{"key":"D","text":"x^2 - 6"}]'::jsonb, 'A', 'Algebre', 0, 2, 'x^2 - 3x + 2x - 6 = x^2 - x - 6.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q2', 'test_math_lycee', 'La solution de 3x + 6 = 0 est :', '[{"key":"A","text":"2"},{"key":"B","text":"-2"},{"key":"C","text":"6"},{"key":"D","text":"-6"}]'::jsonb, 'B', 'Algebre', 1, 1, '3x = -6 donc x = -2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q3', 'test_math_lycee', 'L''identite remarquable (a - b)^2 vaut :', '[{"key":"A","text":"a^2 - b^2"},{"key":"B","text":"a^2 - 2ab + b^2"},{"key":"C","text":"a^2 + 2ab + b^2"},{"key":"D","text":"a^2 + b^2"}]'::jsonb, 'B', 'Algebre', 2, 1, 'Carre d''une difference.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q4', 'test_math_lycee', 'Si delta est strictement negatif, l''equation du second degre admet :', '[{"key":"A","text":"deux racines reelles"},{"key":"B","text":"une racine double"},{"key":"C","text":"aucune racine reelle"},{"key":"D","text":"une infinite de racines"}]'::jsonb, 'C', 'Algebre', 3, 2, 'Un discriminant negatif ne donne pas de solution reelle.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q5', 'test_math_lycee', 'La forme factorisee de x^2 + 6x + 9 est :', '[{"key":"A","text":"(x + 3)^2"},{"key":"B","text":"(x - 3)^2"},{"key":"C","text":"(x + 9)(x + 1)"},{"key":"D","text":"(x + 6)(x + 3)"}]'::jsonb, 'A', 'Algebre', 4, 2, 'Carre parfait : (x + 3)^2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q6', 'test_math_lycee', 'La valeur de la racine carree de 144 est :', '[{"key":"A","text":"11"},{"key":"B","text":"12"},{"key":"C","text":"14"},{"key":"D","text":"16"}]'::jsonb, 'B', 'Algebre', 5, 1, '12 x 12 = 144.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q7', 'test_math_lycee', 'L''inequation 2x - 4 > 0 a pour solution :', '[{"key":"A","text":"x < 2"},{"key":"B","text":"x > 2"},{"key":"C","text":"x > -2"},{"key":"D","text":"x < -2"}]'::jsonb, 'B', 'Algebre', 6, 2, '2x > 4 donc x > 2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q8', 'test_math_lycee', 'Le PGCD de 12 et 18 vaut :', '[{"key":"A","text":"2"},{"key":"B","text":"3"},{"key":"C","text":"6"},{"key":"D","text":"36"}]'::jsonb, 'C', 'Algebre', 7, 2, 'Les diviseurs communs sont 1, 2, 3 et 6 : le plus grand est 6.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q9', 'test_math_lycee', 'La derivee de f(x) = x^2 + 3x est :', '[{"key":"A","text":"2x + 3"},{"key":"B","text":"2x"},{"key":"C","text":"x + 3"},{"key":"D","text":"3x"}]'::jsonb, 'A', 'Analyse', 8, 1, 'Derivee terme a terme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q10', 'test_math_lycee', 'La derivee de f(x) = 4x est :', '[{"key":"A","text":"4"},{"key":"B","text":"4x"},{"key":"C","text":"0"},{"key":"D","text":"x"}]'::jsonb, 'A', 'Analyse', 9, 1, 'Derivee d''une fonction lineaire : son coefficient.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q11', 'test_math_lycee', 'La fonction f(x) = x^2 admet un minimum en :', '[{"key":"A","text":"x = 1"},{"key":"B","text":"x = 0"},{"key":"C","text":"x = -1"},{"key":"D","text":"elle n''a pas de minimum"}]'::jsonb, 'B', 'Analyse', 10, 2, 'La parabole a pour sommet l''origine.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q12', 'test_math_lycee', 'Une fonction affine a pour representation graphique :', '[{"key":"A","text":"une parabole"},{"key":"B","text":"une droite"},{"key":"C","text":"une hyperbole"},{"key":"D","text":"un cercle"}]'::jsonb, 'B', 'Analyse', 11, 1, 'f(x) = ax + b se represente par une droite.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q13', 'test_math_lycee', 'Le coefficient directeur de la droite passant par A(0, 1) et B(2, 5) vaut :', '[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]'::jsonb, 'B', 'Analyse', 12, 2, '(5 - 1) / (2 - 0) = 4/2 = 2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q14', 'test_math_lycee', 'La suite definie par u_n = 3n + 1 est :', '[{"key":"A","text":"geometrique"},{"key":"B","text":"arithmetique de raison 3"},{"key":"C","text":"constante"},{"key":"D","text":"decroissante"}]'::jsonb, 'B', 'Analyse', 13, 2, 'u_(n+1) - u_n = 3, constante.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q15', 'test_math_lycee', 'La derivee de f(x) = x^3 - 2x est :', '[{"key":"A","text":"3x^2 - 2"},{"key":"B","text":"3x^2"},{"key":"C","text":"x^2 - 2"},{"key":"D","text":"3x - 2"}]'::jsonb, 'A', 'Analyse', 14, 2, 'Derivee terme a terme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q16', 'test_math_lycee', 'Si f''(x) = 0 et que f'' change de signe en a, alors f admet en a :', '[{"key":"A","text":"une asymptote"},{"key":"B","text":"un extremum local"},{"key":"C","text":"une discontinuite"},{"key":"D","text":"une racine double"}]'::jsonb, 'B', 'Analyse', 15, 3, 'Changement de signe de la derivee : extremum local.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q17', 'test_math_lycee', 'La probabilite de tirer un as dans un jeu de 32 cartes est :', '[{"key":"A","text":"1/8"},{"key":"B","text":"4/32"},{"key":"C","text":"1/32"},{"key":"D","text":"4/52"}]'::jsonb, 'A', 'Probabilites', 16, 2, '4 as sur 32 cartes, soit 1/8.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q18', 'test_math_lycee', 'La somme des probabilites de toutes les issues d''une experience vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"0,5"},{"key":"C","text":"1"},{"key":"D","text":"le nombre d''issues"}]'::jsonb, 'C', 'Probabilites', 17, 1, 'Axiome des probabilites.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q19', 'test_math_lycee', 'On lance une piece trois fois. Le nombre d''issues possibles est :', '[{"key":"A","text":"3"},{"key":"B","text":"6"},{"key":"C","text":"8"},{"key":"D","text":"9"}]'::jsonb, 'C', 'Probabilites', 18, 2, '2^3 = 8.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q20', 'test_math_lycee', 'La moyenne de 10, 20 et 30 vaut :', '[{"key":"A","text":"15"},{"key":"B","text":"20"},{"key":"C","text":"25"},{"key":"D","text":"60"}]'::jsonb, 'B', 'Probabilites', 19, 1, '60 / 3 = 20.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q21', 'test_math_lycee', 'L''etendue de la serie 3, 7, 10, 15 vaut :', '[{"key":"A","text":"12"},{"key":"B","text":"10"},{"key":"C","text":"15"},{"key":"D","text":"7"}]'::jsonb, 'A', 'Probabilites', 20, 2, '15 - 3 = 12.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q22', 'test_math_lycee', 'Dans une classe de 40 eleves, 25 % pratiquent le sport. Cela represente :', '[{"key":"A","text":"4 eleves"},{"key":"B","text":"10 eleves"},{"key":"C","text":"15 eleves"},{"key":"D","text":"25 eleves"}]'::jsonb, 'B', 'Probabilites', 21, 2, '40 x 0,25 = 10.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q23', 'test_math_lycee', 'La probabilite d''un evenement impossible vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"0,5"},{"key":"C","text":"1"},{"key":"D","text":"-1"}]'::jsonb, 'A', 'Probabilites', 22, 1, 'Un evenement impossible ne se realise jamais.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q24', 'test_math_lycee', 'Dans un triangle rectangle d''hypotenuse 10 et de cote 6, l''autre cote vaut :', '[{"key":"A","text":"4"},{"key":"B","text":"8"},{"key":"C","text":"9"},{"key":"D","text":"16"}]'::jsonb, 'B', 'Geometrie', 23, 2, 'Racine de (100 - 36) = racine de 64 = 8.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q25', 'test_math_lycee', 'Le perimetre d''un cercle de rayon 5 vaut :', '[{"key":"A","text":"5 pi"},{"key":"B","text":"10 pi"},{"key":"C","text":"25 pi"},{"key":"D","text":"2,5 pi"}]'::jsonb, 'B', 'Geometrie', 24, 1, 'P = 2 pi r = 10 pi.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q26', 'test_math_lycee', 'sin(90 degres) vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"1"},{"key":"C","text":"-1"},{"key":"D","text":"0,5"}]'::jsonb, 'B', 'Geometrie', 25, 1, 'Valeur de reference du sinus.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q27', 'test_math_lycee', 'Le volume d''un cylindre de rayon r et de hauteur h vaut :', '[{"key":"A","text":"2 pi r h"},{"key":"B","text":"pi r^2 h"},{"key":"C","text":"pi r h^2"},{"key":"D","text":"pi r^2"}]'::jsonb, 'B', 'Geometrie', 26, 2, 'Aire de base multipliee par la hauteur.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q28', 'test_math_lycee', 'Dans un triangle equilateral, chaque angle mesure :', '[{"key":"A","text":"45 degres"},{"key":"B","text":"60 degres"},{"key":"C","text":"90 degres"},{"key":"D","text":"30 degres"}]'::jsonb, 'B', 'Geometrie', 27, 1, '180 / 3 = 60 degres.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q29', 'test_math_lycee', 'Le theoreme de Thales concerne :', '[{"key":"A","text":"les triangles rectangles"},{"key":"B","text":"des droites paralleles coupant deux secantes"},{"key":"C","text":"les cercles"},{"key":"D","text":"les volumes"}]'::jsonb, 'B', 'Geometrie', 28, 2, 'Il etablit une proportionnalite entre longueurs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q30', 'test_math_lycee', 'L''aire d''un rectangle de longueur 8 et de largeur 5 vaut :', '[{"key":"A","text":"13"},{"key":"B","text":"26"},{"key":"C","text":"40"},{"key":"D","text":"45"}]'::jsonb, 'C', 'Geometrie', 29, 1, '8 x 5 = 40.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_math_lycee_q31', 'test_math_lycee', 'tan(x) est egal a :', '[{"key":"A","text":"cos(x) / sin(x)"},{"key":"B","text":"sin(x) / cos(x)"},{"key":"C","text":"sin(x) x cos(x)"},{"key":"D","text":"1 / sin(x)"}]'::jsonb, 'B', 'Geometrie', 30, 2, 'Definition de la tangente.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_phys_l1', 'sub_phys', 'lvl_l1', 'Physique — L1', 30, 15, 70, 'Test individuel et chronometre. Une seule reponse par question.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q1', 'test_phys_l1', 'L''unite de la force dans le systeme international est :', '[{"key":"A","text":"le joule"},{"key":"B","text":"le newton"},{"key":"C","text":"le watt"},{"key":"D","text":"le pascal"}]'::jsonb, 'B', 'Mecanique', 0, 1, 'La force se mesure en newtons (N).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q2', 'test_phys_l1', 'La deuxieme loi de Newton s''ecrit :', '[{"key":"A","text":"F = mv"},{"key":"B","text":"F = ma"},{"key":"C","text":"F = mgh"},{"key":"D","text":"F = m/a"}]'::jsonb, 'B', 'Mecanique', 1, 1, 'La somme des forces est egale au produit de la masse par l''acceleration.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q3', 'test_phys_l1', 'L''energie cinetique d''un corps de masse m et de vitesse v vaut :', '[{"key":"A","text":"mv"},{"key":"B","text":"mv^2"},{"key":"C","text":"mv^2/2"},{"key":"D","text":"mgh"}]'::jsonb, 'C', 'Mecanique', 2, 2, 'Ec = (1/2) m v^2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q4', 'test_phys_l1', 'L''energie potentielle de pesanteur vaut :', '[{"key":"A","text":"mgh"},{"key":"B","text":"mv^2/2"},{"key":"C","text":"mg"},{"key":"D","text":"gh"}]'::jsonb, 'A', 'Mecanique', 3, 2, 'Ep = m g h, avec h la hauteur.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q5', 'test_phys_l1', 'L''acceleration de la pesanteur sur Terre vaut environ :', '[{"key":"A","text":"1,8 m/s^2"},{"key":"B","text":"9,8 m/s^2"},{"key":"C","text":"98 m/s^2"},{"key":"D","text":"0,98 m/s^2"}]'::jsonb, 'B', 'Mecanique', 4, 1, 'g vaut environ 9,8 metres par seconde au carre.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q6', 'test_phys_l1', 'Le principe d''inertie affirme qu''un corps isole :', '[{"key":"A","text":"accelere"},{"key":"B","text":"reste au repos ou en mouvement rectiligne uniforme"},{"key":"C","text":"tombe"},{"key":"D","text":"tourne"}]'::jsonb, 'B', 'Mecanique', 5, 2, 'Premiere loi de Newton.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q7', 'test_phys_l1', 'La quantite de mouvement d''un corps vaut :', '[{"key":"A","text":"mv"},{"key":"B","text":"ma"},{"key":"C","text":"mv^2"},{"key":"D","text":"m/v"}]'::jsonb, 'A', 'Mecanique', 6, 2, 'p = m v, grandeur vectorielle.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q8', 'test_phys_l1', 'L''unite de la puissance est :', '[{"key":"A","text":"le joule"},{"key":"B","text":"le newton"},{"key":"C","text":"le watt"},{"key":"D","text":"le volt"}]'::jsonb, 'C', 'Mecanique', 7, 1, 'La puissance se mesure en watts (W).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q9', 'test_phys_l1', 'Un mouvement rectiligne uniforme se caracterise par :', '[{"key":"A","text":"une vitesse constante"},{"key":"B","text":"une acceleration constante non nulle"},{"key":"C","text":"une force croissante"},{"key":"D","text":"une trajectoire circulaire"}]'::jsonb, 'A', 'Mecanique', 8, 2, 'Vitesse constante en direction et en norme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q10', 'test_phys_l1', 'Le travail d''une force constante F sur un deplacement d colineaire vaut :', '[{"key":"A","text":"F/d"},{"key":"B","text":"F x d"},{"key":"C","text":"F + d"},{"key":"D","text":"F x d^2"}]'::jsonb, 'B', 'Mecanique', 9, 2, 'W = F x d lorsque force et deplacement sont colineaires.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q11', 'test_phys_l1', 'La loi d''Ohm s''ecrit :', '[{"key":"A","text":"U = RI"},{"key":"B","text":"U = R/I"},{"key":"C","text":"I = UR"},{"key":"D","text":"R = UI"}]'::jsonb, 'A', 'Electricite', 10, 1, 'La tension est le produit de la resistance par l''intensite.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q12', 'test_phys_l1', 'L''unite de l''intensite du courant electrique est :', '[{"key":"A","text":"le volt"},{"key":"B","text":"l''ohm"},{"key":"C","text":"l''ampere"},{"key":"D","text":"le coulomb"}]'::jsonb, 'C', 'Electricite', 11, 1, 'L''intensite se mesure en amperes (A).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q13', 'test_phys_l1', 'Deux resistances R1 et R2 en serie ont pour resistance equivalente :', '[{"key":"A","text":"R1 + R2"},{"key":"B","text":"R1 x R2"},{"key":"C","text":"1/(R1 + R2)"},{"key":"D","text":"(R1 x R2)/(R1 + R2)"}]'::jsonb, 'A', 'Electricite', 12, 2, 'En serie, les resistances s''additionnent.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q14', 'test_phys_l1', 'Deux resistances egales R en parallele donnent une resistance equivalente de :', '[{"key":"A","text":"2R"},{"key":"B","text":"R"},{"key":"C","text":"R/2"},{"key":"D","text":"R^2"}]'::jsonb, 'C', 'Electricite', 13, 3, '1/Req = 1/R + 1/R = 2/R, donc Req = R/2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q15', 'test_phys_l1', 'La puissance dissipee par une resistance vaut :', '[{"key":"A","text":"UI"},{"key":"B","text":"U/I"},{"key":"C","text":"U + I"},{"key":"D","text":"U^2 I"}]'::jsonb, 'A', 'Electricite', 14, 2, 'P = U x I, soit aussi R I^2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q16', 'test_phys_l1', 'Dans un circuit en serie, l''intensite du courant est :', '[{"key":"A","text":"differente en chaque point"},{"key":"B","text":"la meme partout"},{"key":"C","text":"nulle"},{"key":"D","text":"proportionnelle a la resistance"}]'::jsonb, 'B', 'Electricite', 15, 2, 'Le courant est conserve dans une branche unique.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q17', 'test_phys_l1', 'L''unite de la tension electrique est :', '[{"key":"A","text":"l''ampere"},{"key":"B","text":"le volt"},{"key":"C","text":"le watt"},{"key":"D","text":"le farad"}]'::jsonb, 'B', 'Electricite', 16, 1, 'La tension se mesure en volts (V).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q18', 'test_phys_l1', 'La charge elementaire d''un electron vaut environ :', '[{"key":"A","text":"1,6 x 10^-19 C"},{"key":"B","text":"9,1 x 10^-31 C"},{"key":"C","text":"3 x 10^8 C"},{"key":"D","text":"6,02 x 10^23 C"}]'::jsonb, 'A', 'Electricite', 17, 3, 'e vaut environ 1,6 x 10^-19 coulomb.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q19', 'test_phys_l1', 'La vitesse de la lumiere dans le vide vaut environ :', '[{"key":"A","text":"3 x 10^5 m/s"},{"key":"B","text":"3 x 10^8 m/s"},{"key":"C","text":"3 x 10^6 m/s"},{"key":"D","text":"3 x 10^10 m/s"}]'::jsonb, 'B', 'Ondes et optique', 18, 2, 'c vaut environ 300 000 km/s, soit 3 x 10^8 m/s.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q20', 'test_phys_l1', 'La relation entre longueur d''onde, vitesse et frequence est :', '[{"key":"A","text":"v = lambda x f"},{"key":"B","text":"v = lambda / f"},{"key":"C","text":"f = lambda x v"},{"key":"D","text":"lambda = v x f"}]'::jsonb, 'A', 'Ondes et optique', 19, 2, 'v = lambda f.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q21', 'test_phys_l1', 'L''unite de la frequence est :', '[{"key":"A","text":"le metre"},{"key":"B","text":"la seconde"},{"key":"C","text":"le hertz"},{"key":"D","text":"le decibel"}]'::jsonb, 'C', 'Ondes et optique', 20, 1, 'La frequence se mesure en hertz (Hz).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q22', 'test_phys_l1', 'La refraction correspond au changement de direction de la lumiere :', '[{"key":"A","text":"lors d''une reflexion"},{"key":"B","text":"au passage entre deux milieux"},{"key":"C","text":"dans le vide"},{"key":"D","text":"en presence d''un champ magnetique"}]'::jsonb, 'B', 'Ondes et optique', 21, 2, 'Loi de Snell-Descartes.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q23', 'test_phys_l1', 'Une lentille convergente fait converger les rayons vers :', '[{"key":"A","text":"son centre optique"},{"key":"B","text":"son foyer image"},{"key":"C","text":"l''infini"},{"key":"D","text":"son axe secondaire"}]'::jsonb, 'B', 'Ondes et optique', 22, 2, 'Les rayons paralleles convergent au foyer image.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q24', 'test_phys_l1', 'La periode d''une onde est l''inverse de :', '[{"key":"A","text":"sa longueur d''onde"},{"key":"B","text":"sa frequence"},{"key":"C","text":"son amplitude"},{"key":"D","text":"sa vitesse"}]'::jsonb, 'B', 'Ondes et optique', 23, 2, 'T = 1/f.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q25', 'test_phys_l1', 'L''unite de la temperature dans le systeme international est :', '[{"key":"A","text":"le degre Celsius"},{"key":"B","text":"le kelvin"},{"key":"C","text":"le degre Fahrenheit"},{"key":"D","text":"le joule"}]'::jsonb, 'B', 'Thermodynamique', 24, 1, 'Le kelvin (K) est l''unite SI de temperature.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q26', 'test_phys_l1', 'Zero degre Celsius correspond a :', '[{"key":"A","text":"0 K"},{"key":"B","text":"100 K"},{"key":"C","text":"273,15 K"},{"key":"D","text":"373,15 K"}]'::jsonb, 'C', 'Thermodynamique', 25, 2, 'T(K) = T(degre C) + 273,15.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q27', 'test_phys_l1', 'Le premier principe de la thermodynamique exprime :', '[{"key":"A","text":"la conservation de l''energie"},{"key":"B","text":"l''augmentation de l''entropie"},{"key":"C","text":"la conservation de la masse"},{"key":"D","text":"la loi des gaz parfaits"}]'::jsonb, 'A', 'Thermodynamique', 26, 2, 'La variation d''energie interne egale la somme du travail et de la chaleur.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q28', 'test_phys_l1', 'La loi des gaz parfaits s''ecrit :', '[{"key":"A","text":"PV = nRT"},{"key":"B","text":"PV = RT/n"},{"key":"C","text":"P/V = nRT"},{"key":"D","text":"PVT = nR"}]'::jsonb, 'A', 'Thermodynamique', 27, 2, 'Equation d''etat des gaz parfaits.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q29', 'test_phys_l1', 'L''unite de la pression dans le systeme international est :', '[{"key":"A","text":"le newton"},{"key":"B","text":"le pascal"},{"key":"C","text":"le bar"},{"key":"D","text":"le joule"}]'::jsonb, 'B', 'Thermodynamique', 28, 1, 'La pression se mesure en pascals (Pa).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_phys_l1_q30', 'test_phys_l1', 'Le second principe de la thermodynamique introduit la notion :', '[{"key":"A","text":"d''energie interne"},{"key":"B","text":"d''entropie"},{"key":"C","text":"de travail"},{"key":"D","text":"d''enthalpie"}]'::jsonb, 'B', 'Thermodynamique', 29, 3, 'L''entropie d''un systeme isole ne peut que croitre.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_chim_l1', 'sub_chim', 'lvl_l1', 'Chimie — L1', 30, 15, 70, 'Test individuel et chronometre. Une seule reponse par question.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q1', 'test_chim_l1', 'Le numero atomique d''un element correspond au nombre :', '[{"key":"A","text":"de neutrons"},{"key":"B","text":"de protons"},{"key":"C","text":"de nucleons"},{"key":"D","text":"d''isotopes"}]'::jsonb, 'B', 'Structure de la matiere', 0, 1, 'Z est le nombre de protons du noyau.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q2', 'test_chim_l1', 'Le nombre d''Avogadro vaut environ :', '[{"key":"A","text":"6,02 x 10^23"},{"key":"B","text":"3 x 10^8"},{"key":"C","text":"1,6 x 10^-19"},{"key":"D","text":"9,8"}]'::jsonb, 'A', 'Structure de la matiere', 1, 2, 'Une mole contient environ 6,02 x 10^23 entites.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q3', 'test_chim_l1', 'Les isotopes d''un element different par leur nombre :', '[{"key":"A","text":"de protons"},{"key":"B","text":"d''electrons"},{"key":"C","text":"de neutrons"},{"key":"D","text":"de charges"}]'::jsonb, 'C', 'Structure de la matiere', 2, 2, 'Meme Z, mais nombre de neutrons different.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q4', 'test_chim_l1', 'La masse molaire de l''eau H2O vaut environ :', '[{"key":"A","text":"16 g/mol"},{"key":"B","text":"18 g/mol"},{"key":"C","text":"20 g/mol"},{"key":"D","text":"22 g/mol"}]'::jsonb, 'B', 'Structure de la matiere', 3, 2, '2 x 1 + 16 = 18 g/mol.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q5', 'test_chim_l1', 'Un atome neutre possede :', '[{"key":"A","text":"plus de protons que d''electrons"},{"key":"B","text":"autant de protons que d''electrons"},{"key":"C","text":"plus d''electrons que de protons"},{"key":"D","text":"aucun electron"}]'::jsonb, 'B', 'Structure de la matiere', 4, 1, 'La neutralite impose l''egalite des charges positives et negatives.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q6', 'test_chim_l1', 'La liaison covalente resulte :', '[{"key":"A","text":"d''un transfert d''electrons"},{"key":"B","text":"d''une mise en commun d''electrons"},{"key":"C","text":"d''une attraction magnetique"},{"key":"D","text":"d''une reaction nucleaire"}]'::jsonb, 'B', 'Structure de la matiere', 5, 2, 'Les atomes partagent une ou plusieurs paires d''electrons.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q7', 'test_chim_l1', 'Dans la classification periodique, les elements d''une meme colonne ont :', '[{"key":"A","text":"le meme nombre de neutrons"},{"key":"B","text":"la meme masse"},{"key":"C","text":"le meme nombre d''electrons de valence"},{"key":"D","text":"le meme numero atomique"}]'::jsonb, 'C', 'Structure de la matiere', 6, 2, 'Une colonne regroupe les elements de meme configuration de valence.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q8', 'test_chim_l1', 'L''element de symbole Na est :', '[{"key":"A","text":"l''azote"},{"key":"B","text":"le sodium"},{"key":"C","text":"le nickel"},{"key":"D","text":"le neon"}]'::jsonb, 'B', 'Structure de la matiere', 7, 1, 'Na designe le sodium (natrium).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q9', 'test_chim_l1', 'Une solution de pH 3 est :', '[{"key":"A","text":"acide"},{"key":"B","text":"neutre"},{"key":"C","text":"basique"},{"key":"D","text":"saturee"}]'::jsonb, 'A', 'Solutions et acides-bases', 8, 1, 'Un pH inferieur a 7 correspond a une solution acide.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q10', 'test_chim_l1', 'Le pH d''une solution neutre a 25 degres Celsius vaut :', '[{"key":"A","text":"0"},{"key":"B","text":"7"},{"key":"C","text":"14"},{"key":"D","text":"1"}]'::jsonb, 'B', 'Solutions et acides-bases', 9, 1, 'A 25 degres, la neutralite correspond a pH 7.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q11', 'test_chim_l1', 'La concentration molaire s''exprime en :', '[{"key":"A","text":"g/L"},{"key":"B","text":"mol/L"},{"key":"C","text":"mol"},{"key":"D","text":"L/mol"}]'::jsonb, 'B', 'Solutions et acides-bases', 10, 1, 'C = n/V, en moles par litre.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q12', 'test_chim_l1', 'Selon Bronsted, un acide est une espece qui :', '[{"key":"A","text":"cede un proton"},{"key":"B","text":"capte un proton"},{"key":"C","text":"cede un electron"},{"key":"D","text":"capte un electron"}]'::jsonb, 'A', 'Solutions et acides-bases', 11, 2, 'Un acide de Bronsted est un donneur de proton H+.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q13', 'test_chim_l1', 'Quelle quantite de matiere represente 36 g d''eau ?', '[{"key":"A","text":"1 mol"},{"key":"B","text":"2 mol"},{"key":"C","text":"18 mol"},{"key":"D","text":"0,5 mol"}]'::jsonb, 'B', 'Solutions et acides-bases', 12, 2, 'n = m/M = 36/18 = 2 mol.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q14', 'test_chim_l1', 'Une dilution consiste a :', '[{"key":"A","text":"augmenter la concentration"},{"key":"B","text":"diminuer la concentration en ajoutant du solvant"},{"key":"C","text":"evaporer le solvant"},{"key":"D","text":"ajouter du solute"}]'::jsonb, 'B', 'Solutions et acides-bases', 13, 1, 'L''ajout de solvant diminue la concentration.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q15', 'test_chim_l1', 'Le produit ionique de l''eau Ke a 25 degres vaut :', '[{"key":"A","text":"10^-7"},{"key":"B","text":"10^-14"},{"key":"C","text":"10^7"},{"key":"D","text":"10^14"}]'::jsonb, 'B', 'Solutions et acides-bases', 14, 3, 'Ke = [H3O+][OH-] = 10^-14 a 25 degres.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q16', 'test_chim_l1', 'Une base selon Bronsted est une espece qui :', '[{"key":"A","text":"cede un proton"},{"key":"B","text":"capte un proton"},{"key":"C","text":"libere des ions H+"},{"key":"D","text":"abaisse le pH"}]'::jsonb, 'B', 'Solutions et acides-bases', 15, 2, 'Une base est un accepteur de proton.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q17', 'test_chim_l1', 'Equilibrer 2 H2 + O2 donne :', '[{"key":"A","text":"H2O"},{"key":"B","text":"2 H2O"},{"key":"C","text":"H2O2"},{"key":"D","text":"2 H2O2"}]'::jsonb, 'B', 'Reactions chimiques', 16, 2, '2 H2 + O2 -> 2 H2O respecte la conservation des atomes.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q18', 'test_chim_l1', 'Dans une reaction chimique, la masse totale est :', '[{"key":"A","text":"conservee"},{"key":"B","text":"toujours augmentee"},{"key":"C","text":"toujours diminuee"},{"key":"D","text":"variable"}]'::jsonb, 'A', 'Reactions chimiques', 17, 1, 'Loi de Lavoisier : conservation de la masse.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q19', 'test_chim_l1', 'Une reaction exothermique :', '[{"key":"A","text":"absorbe de la chaleur"},{"key":"B","text":"libere de la chaleur"},{"key":"C","text":"n''echange pas d''energie"},{"key":"D","text":"produit du courant"}]'::jsonb, 'B', 'Reactions chimiques', 18, 2, 'Une reaction exothermique cede de l''energie au milieu.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q20', 'test_chim_l1', 'Une oxydation correspond a :', '[{"key":"A","text":"un gain d''electrons"},{"key":"B","text":"une perte d''electrons"},{"key":"C","text":"un gain de protons"},{"key":"D","text":"une perte de neutrons"}]'::jsonb, 'B', 'Reactions chimiques', 19, 2, 'Oxydation = perte d''electrons ; reduction = gain.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q21', 'test_chim_l1', 'Un catalyseur a pour effet :', '[{"key":"A","text":"d''augmenter la vitesse de reaction sans etre consomme"},{"key":"B","text":"de deplacer l''equilibre"},{"key":"C","text":"d''augmenter le rendement final"},{"key":"D","text":"de modifier la nature des produits"}]'::jsonb, 'A', 'Reactions chimiques', 20, 2, 'Il abaisse l''energie d''activation sans etre consomme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q22', 'test_chim_l1', 'Le reactif limitant est celui qui :', '[{"key":"A","text":"est en exces"},{"key":"B","text":"est entierement consomme en premier"},{"key":"C","text":"sert de solvant"},{"key":"D","text":"catalyse la reaction"}]'::jsonb, 'B', 'Reactions chimiques', 21, 2, 'Il fixe l''avancement maximal de la reaction.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q23', 'test_chim_l1', 'La combustion complete du methane produit :', '[{"key":"A","text":"CO et H2O"},{"key":"B","text":"CO2 et H2O"},{"key":"C","text":"C et H2"},{"key":"D","text":"CO2 uniquement"}]'::jsonb, 'B', 'Reactions chimiques', 22, 2, 'CH4 + 2 O2 -> CO2 + 2 H2O.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q24', 'test_chim_l1', 'La formule brute du methane est :', '[{"key":"A","text":"CH4"},{"key":"B","text":"C2H6"},{"key":"C","text":"CH3"},{"key":"D","text":"C2H4"}]'::jsonb, 'A', 'Chimie organique', 23, 1, 'Le methane est le premier des alcanes.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q25', 'test_chim_l1', 'Les alcanes ont pour formule generale :', '[{"key":"A","text":"CnH2n"},{"key":"B","text":"CnH2n+2"},{"key":"C","text":"CnH2n-2"},{"key":"D","text":"CnHn"}]'::jsonb, 'B', 'Chimie organique', 24, 2, 'Hydrocarbures satures : CnH(2n+2).')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q26', 'test_chim_l1', 'Le groupe caracteristique des alcools est :', '[{"key":"A","text":"-COOH"},{"key":"B","text":"-OH"},{"key":"C","text":"-CHO"},{"key":"D","text":"-NH2"}]'::jsonb, 'B', 'Chimie organique', 25, 2, 'Le groupe hydroxyle -OH caracterise les alcools.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q27', 'test_chim_l1', 'Le groupe -COOH caracterise :', '[{"key":"A","text":"les alcools"},{"key":"B","text":"les aldehydes"},{"key":"C","text":"les acides carboxyliques"},{"key":"D","text":"les amines"}]'::jsonb, 'C', 'Chimie organique', 26, 2, 'Groupe carboxyle des acides carboxyliques.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q28', 'test_chim_l1', 'Les alcenes se distinguent des alcanes par la presence :', '[{"key":"A","text":"d''une double liaison carbone-carbone"},{"key":"B","text":"d''un cycle"},{"key":"C","text":"d''un atome d''oxygene"},{"key":"D","text":"d''une triple liaison"}]'::jsonb, 'A', 'Chimie organique', 27, 2, 'Une insaturation C=C caracterise les alcenes.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q29', 'test_chim_l1', 'Deux isomeres possedent :', '[{"key":"A","text":"la meme formule brute mais des structures differentes"},{"key":"B","text":"des formules brutes differentes"},{"key":"C","text":"les memes proprietes"},{"key":"D","text":"le meme nombre d''atomes de carbone uniquement"}]'::jsonb, 'A', 'Chimie organique', 28, 2, 'Meme formule brute, arrangements differents.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_chim_l1_q30', 'test_chim_l1', 'L''ethanol a pour formule :', '[{"key":"A","text":"CH3OH"},{"key":"B","text":"C2H5OH"},{"key":"C","text":"C3H7OH"},{"key":"D","text":"CH4O"}]'::jsonb, 'B', 'Chimie organique', 29, 2, 'L''ethanol comporte deux atomes de carbone.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_info_l1', 'sub_info', 'lvl_l1', 'Informatique — L1', 30, 15, 70, 'Test individuel et chronometre. Une seule reponse par question.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q1', 'test_info_l1', 'Un octet est compose de :', '[{"key":"A","text":"4 bits"},{"key":"B","text":"8 bits"},{"key":"C","text":"16 bits"},{"key":"D","text":"32 bits"}]'::jsonb, 'B', 'Bases et representation', 0, 1, 'Un octet (byte) contient 8 bits.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q2', 'test_info_l1', 'Le nombre binaire 1010 vaut en decimal :', '[{"key":"A","text":"8"},{"key":"B","text":"10"},{"key":"C","text":"12"},{"key":"D","text":"1010"}]'::jsonb, 'B', 'Bases et representation', 1, 2, '8 + 0 + 2 + 0 = 10.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q3', 'test_info_l1', 'Combien de valeurs differentes peut coder un octet ?', '[{"key":"A","text":"8"},{"key":"B","text":"128"},{"key":"C","text":"256"},{"key":"D","text":"512"}]'::jsonb, 'C', 'Bases et representation', 2, 2, '2^8 = 256 valeurs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q4', 'test_info_l1', 'Le systeme hexadecimal utilise une base :', '[{"key":"A","text":"2"},{"key":"B","text":"8"},{"key":"C","text":"10"},{"key":"D","text":"16"}]'::jsonb, 'D', 'Bases et representation', 3, 1, 'L''hexadecimal est en base 16.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q5', 'test_info_l1', 'Le nombre decimal 5 s''ecrit en binaire :', '[{"key":"A","text":"101"},{"key":"B","text":"110"},{"key":"C","text":"011"},{"key":"D","text":"111"}]'::jsonb, 'A', 'Bases et representation', 4, 2, '4 + 1 = 5, soit 101.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q6', 'test_info_l1', 'L''unite centrale de traitement d''un ordinateur est :', '[{"key":"A","text":"la RAM"},{"key":"B","text":"le processeur"},{"key":"C","text":"le disque dur"},{"key":"D","text":"la carte graphique"}]'::jsonb, 'B', 'Bases et representation', 5, 1, 'Le processeur (CPU) execute les instructions.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q7', 'test_info_l1', 'La memoire vive (RAM) est :', '[{"key":"A","text":"permanente"},{"key":"B","text":"volatile"},{"key":"C","text":"en lecture seule"},{"key":"D","text":"amovible"}]'::jsonb, 'B', 'Bases et representation', 6, 2, 'Son contenu est perdu a l''extinction de la machine.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q8', 'test_info_l1', 'Une boucle « tant que » s''execute :', '[{"key":"A","text":"exactement une fois"},{"key":"B","text":"tant que sa condition est vraie"},{"key":"C","text":"un nombre fixe de fois"},{"key":"D","text":"jamais"}]'::jsonb, 'B', 'Algorithmique', 7, 1, 'La condition est evaluee avant chaque iteration.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q9', 'test_info_l1', 'Quelle structure permet de choisir entre deux traitements ?', '[{"key":"A","text":"la boucle pour"},{"key":"B","text":"la condition si-sinon"},{"key":"C","text":"la fonction"},{"key":"D","text":"le tableau"}]'::jsonb, 'B', 'Algorithmique', 8, 1, 'L''instruction conditionnelle realise un branchement.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q10', 'test_info_l1', 'La complexite d''une recherche dichotomique dans un tableau trie de n elements est :', '[{"key":"A","text":"O(n)"},{"key":"B","text":"O(log n)"},{"key":"C","text":"O(n^2)"},{"key":"D","text":"O(1)"}]'::jsonb, 'B', 'Algorithmique', 9, 3, 'L''espace de recherche est divise par deux a chaque etape.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q11', 'test_info_l1', 'La complexite du tri a bulles dans le pire des cas est :', '[{"key":"A","text":"O(n)"},{"key":"B","text":"O(n log n)"},{"key":"C","text":"O(n^2)"},{"key":"D","text":"O(log n)"}]'::jsonb, 'C', 'Algorithmique', 10, 3, 'Deux boucles imbriquees sur n elements.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q12', 'test_info_l1', 'Une fonction recursive est une fonction qui :', '[{"key":"A","text":"s''appelle elle-meme"},{"key":"B","text":"ne retourne rien"},{"key":"C","text":"boucle indefiniment"},{"key":"D","text":"n''a pas de parametre"}]'::jsonb, 'A', 'Algorithmique', 11, 2, 'Elle doit comporter un cas d''arret.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q13', 'test_info_l1', 'Dans un tableau indexe a partir de 0, le premier element a pour indice :', '[{"key":"A","text":"0"},{"key":"B","text":"1"},{"key":"C","text":"-1"},{"key":"D","text":"le premier indice libre"}]'::jsonb, 'A', 'Algorithmique', 12, 1, 'L''indexation commence a zero dans la plupart des langages.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q14', 'test_info_l1', 'Une pile fonctionne selon le principe :', '[{"key":"A","text":"premier entre, premier sorti"},{"key":"B","text":"dernier entre, premier sorti"},{"key":"C","text":"aleatoire"},{"key":"D","text":"trie"}]'::jsonb, 'B', 'Algorithmique', 13, 2, 'Une pile est une structure LIFO.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q15', 'test_info_l1', 'Une file fonctionne selon le principe :', '[{"key":"A","text":"premier entre, premier sorti"},{"key":"B","text":"dernier entre, premier sorti"},{"key":"C","text":"aleatoire"},{"key":"D","text":"par priorite uniquement"}]'::jsonb, 'A', 'Algorithmique', 14, 2, 'Une file est une structure FIFO.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q16', 'test_info_l1', 'Un algorithme doit toujours :', '[{"key":"A","text":"utiliser une boucle"},{"key":"B","text":"se terminer en un nombre fini d''etapes"},{"key":"C","text":"etre recursif"},{"key":"D","text":"manipuler des tableaux"}]'::jsonb, 'B', 'Algorithmique', 15, 2, 'La finitude fait partie de la definition d''un algorithme.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q17', 'test_info_l1', 'En programmation, une variable de type booleen peut valoir :', '[{"key":"A","text":"0 a 255"},{"key":"B","text":"vrai ou faux"},{"key":"C","text":"tout nombre entier"},{"key":"D","text":"une chaine"}]'::jsonb, 'B', 'Programmation', 16, 1, 'Un booleen ne prend que deux valeurs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q18', 'test_info_l1', 'Le langage Python se caracterise par :', '[{"key":"A","text":"une compilation obligatoire"},{"key":"B","text":"une indentation significative"},{"key":"C","text":"un typage statique strict"},{"key":"D","text":"l''absence de fonctions"}]'::jsonb, 'B', 'Programmation', 17, 2, 'L''indentation delimite les blocs en Python.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q19', 'test_info_l1', 'Une fonction qui ne retourne aucune valeur est souvent appelee :', '[{"key":"A","text":"procedure"},{"key":"B","text":"constante"},{"key":"C","text":"pointeur"},{"key":"D","text":"classe"}]'::jsonb, 'A', 'Programmation', 18, 2, 'Une procedure realise une action sans valeur de retour.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q20', 'test_info_l1', 'En programmation orientee objet, une classe est :', '[{"key":"A","text":"une instance"},{"key":"B","text":"un modele decrivant des objets"},{"key":"C","text":"une variable globale"},{"key":"D","text":"une boucle"}]'::jsonb, 'B', 'Programmation', 19, 2, 'Les objets sont des instances de la classe.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q21', 'test_info_l1', 'L''encapsulation consiste a :', '[{"key":"A","text":"masquer les details internes d''un objet"},{"key":"B","text":"dupliquer le code"},{"key":"C","text":"supprimer les fonctions"},{"key":"D","text":"compiler plus vite"}]'::jsonb, 'A', 'Programmation', 20, 3, 'Elle regroupe donnees et traitements en controlant l''acces.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q22', 'test_info_l1', 'Un commentaire dans un programme sert a :', '[{"key":"A","text":"accelerer l''execution"},{"key":"B","text":"documenter le code sans etre execute"},{"key":"C","text":"declarer une variable"},{"key":"D","text":"importer un module"}]'::jsonb, 'B', 'Programmation', 21, 1, 'Les commentaires sont ignores par le compilateur ou l''interpreteur.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q23', 'test_info_l1', 'L''heritage en programmation orientee objet permet :', '[{"key":"A","text":"de reutiliser et specialiser une classe existante"},{"key":"B","text":"de supprimer une classe"},{"key":"C","text":"d''accelerer le programme"},{"key":"D","text":"de compiler plusieurs fichiers"}]'::jsonb, 'A', 'Programmation', 22, 2, 'Une classe fille herite des membres de sa classe mere.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q24', 'test_info_l1', 'En SQL, quelle commande permet de lire des donnees ?', '[{"key":"A","text":"INSERT"},{"key":"B","text":"SELECT"},{"key":"C","text":"UPDATE"},{"key":"D","text":"DELETE"}]'::jsonb, 'B', 'Bases de donnees et reseaux', 23, 1, 'SELECT interroge une ou plusieurs tables.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q25', 'test_info_l1', 'Une cle primaire sert a :', '[{"key":"A","text":"identifier de maniere unique chaque ligne"},{"key":"B","text":"trier la table"},{"key":"C","text":"chiffrer les donnees"},{"key":"D","text":"relier deux bases"}]'::jsonb, 'A', 'Bases de donnees et reseaux', 24, 2, 'Elle garantit l''unicite des enregistrements.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q26', 'test_info_l1', 'Une cle etrangere permet :', '[{"key":"A","text":"de chiffrer une colonne"},{"key":"B","text":"de referencer la cle primaire d''une autre table"},{"key":"C","text":"d''indexer un champ"},{"key":"D","text":"de supprimer une table"}]'::jsonb, 'B', 'Bases de donnees et reseaux', 25, 2, 'Elle materialise une relation entre deux tables.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q27', 'test_info_l1', 'En SQL, la clause WHERE sert a :', '[{"key":"A","text":"trier les resultats"},{"key":"B","text":"filtrer les lignes"},{"key":"C","text":"grouper les lignes"},{"key":"D","text":"joindre deux tables"}]'::jsonb, 'B', 'Bases de donnees et reseaux', 26, 1, 'WHERE applique une condition de selection.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q28', 'test_info_l1', 'Le protocole HTTPS assure :', '[{"key":"A","text":"une connexion chiffree"},{"key":"B","text":"une connexion plus rapide"},{"key":"C","text":"un stockage local"},{"key":"D","text":"une compression des images"}]'::jsonb, 'A', 'Bases de donnees et reseaux', 27, 2, 'HTTPS ajoute une couche TLS a HTTP.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q29', 'test_info_l1', 'Une adresse IP sert a :', '[{"key":"A","text":"identifier une machine sur un reseau"},{"key":"B","text":"chiffrer un fichier"},{"key":"C","text":"compiler un programme"},{"key":"D","text":"stocker des donnees"}]'::jsonb, 'A', 'Bases de donnees et reseaux', 28, 1, 'Elle identifie un hote dans un reseau IP.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_info_l1_q30', 'test_info_l1', 'Le modele client-serveur repose sur :', '[{"key":"A","text":"un poste unique"},{"key":"B","text":"des requetes envoyees par le client au serveur"},{"key":"C","text":"un echange sans reseau"},{"key":"D","text":"une base locale uniquement"}]'::jsonb, 'B', 'Bases de donnees et reseaux', 29, 2, 'Le client emet des requetes, le serveur repond.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_fran_lycee', 'sub_fran', 'lvl_lycee', 'Francais — Lycee', 30, 15, 70, 'Test individuel et chronometre. Une seule reponse par question.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q1', 'test_fran_lycee', 'Dans la phrase « Le professeur corrige les copies », le groupe « les copies » est :', '[{"key":"A","text":"sujet"},{"key":"B","text":"complement d''objet direct"},{"key":"C","text":"complement d''objet indirect"},{"key":"D","text":"attribut du sujet"}]'::jsonb, 'B', 'Grammaire', 0, 1, 'Il repond a la question « corrige quoi ? » sans preposition.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q2', 'test_fran_lycee', 'Quel est le mode du verbe dans « qu''il vienne » ?', '[{"key":"A","text":"indicatif"},{"key":"B","text":"subjonctif"},{"key":"C","text":"conditionnel"},{"key":"D","text":"imperatif"}]'::jsonb, 'B', 'Grammaire', 1, 2, 'Le subjonctif present exprime ici un souhait ou une injonction.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q3', 'test_fran_lycee', 'Dans « il a mange », le verbe est conjugue :', '[{"key":"A","text":"au passe simple"},{"key":"B","text":"au passe compose"},{"key":"C","text":"a l''imparfait"},{"key":"D","text":"au plus-que-parfait"}]'::jsonb, 'B', 'Grammaire', 2, 1, 'Auxiliaire au present + participe passe = passe compose.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q4', 'test_fran_lycee', 'Le participe passe employe avec l''auxiliaire « etre » s''accorde avec :', '[{"key":"A","text":"le complement d''objet direct"},{"key":"B","text":"le sujet"},{"key":"C","text":"l''auxiliaire"},{"key":"D","text":"il ne s''accorde jamais"}]'::jsonb, 'B', 'Grammaire', 3, 2, 'Avec etre, l''accord se fait avec le sujet.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q5', 'test_fran_lycee', 'Dans « la maison que j''ai vue », le pronom « que » est :', '[{"key":"A","text":"pronom relatif"},{"key":"B","text":"pronom personnel"},{"key":"C","text":"conjonction"},{"key":"D","text":"adverbe"}]'::jsonb, 'A', 'Grammaire', 4, 2, 'Il introduit une proposition subordonnee relative.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q6', 'test_fran_lycee', 'Quelle proposition est une subordonnee circonstancielle de cause ?', '[{"key":"A","text":"Il part quand il pleut"},{"key":"B","text":"Il part parce qu''il pleut"},{"key":"C","text":"Il part pour partir"},{"key":"D","text":"Il part sans pleuvoir"}]'::jsonb, 'B', 'Grammaire', 5, 2, '« parce que » introduit la cause.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q7', 'test_fran_lycee', 'L''adjectif « beau » au feminin pluriel s''ecrit :', '[{"key":"A","text":"beaux"},{"key":"B","text":"belles"},{"key":"C","text":"beles"},{"key":"D","text":"beaus"}]'::jsonb, 'B', 'Grammaire', 6, 1, 'Feminin « belle », pluriel « belles ».')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q8', 'test_fran_lycee', 'Dans « Pierre semble fatigue », « fatigue » est :', '[{"key":"A","text":"complement d''objet"},{"key":"B","text":"attribut du sujet"},{"key":"C","text":"epithete"},{"key":"D","text":"apposition"}]'::jsonb, 'B', 'Grammaire', 7, 2, 'Il est relie au sujet par le verbe d''etat « semble ».')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q9', 'test_fran_lycee', 'La comparaison se distingue de la metaphore par :', '[{"key":"A","text":"l''absence d''image"},{"key":"B","text":"la presence d''un outil de comparaison"},{"key":"C","text":"sa longueur"},{"key":"D","text":"son registre"}]'::jsonb, 'B', 'Figures de style', 8, 2, '« comme », « tel que » signalent la comparaison.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q10', 'test_fran_lycee', '« Un silence assourdissant » est :', '[{"key":"A","text":"une metaphore"},{"key":"B","text":"un oxymore"},{"key":"C","text":"une hyperbole"},{"key":"D","text":"une litote"}]'::jsonb, 'B', 'Figures de style', 9, 2, 'L''oxymore associe deux termes contradictoires.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q11', 'test_fran_lycee', 'La personnification consiste a :', '[{"key":"A","text":"exagerer une realite"},{"key":"B","text":"attribuer des traits humains a une chose"},{"key":"C","text":"attenuer une idee"},{"key":"D","text":"repeter un mot"}]'::jsonb, 'B', 'Figures de style', 10, 1, 'Elle prete des caracteristiques humaines a l''inanime.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q12', 'test_fran_lycee', '« Je meurs de faim » est une :', '[{"key":"A","text":"litote"},{"key":"B","text":"hyperbole"},{"key":"C","text":"metonymie"},{"key":"D","text":"anaphore"}]'::jsonb, 'B', 'Figures de style', 11, 2, 'L''hyperbole exagere volontairement.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q13', 'test_fran_lycee', 'L''anaphore consiste a repeter un mot :', '[{"key":"A","text":"en fin de phrase"},{"key":"B","text":"en debut de plusieurs phrases ou vers"},{"key":"C","text":"au milieu du texte"},{"key":"D","text":"une seule fois"}]'::jsonb, 'B', 'Figures de style', 12, 2, 'Repetition en tete de segments successifs.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q14', 'test_fran_lycee', '« Boire un verre » est un exemple de :', '[{"key":"A","text":"metonymie"},{"key":"B","text":"oxymore"},{"key":"C","text":"litote"},{"key":"D","text":"antithese"}]'::jsonb, 'A', 'Figures de style', 13, 3, 'Le contenant designe le contenu.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q15', 'test_fran_lycee', 'L''antithese consiste a :', '[{"key":"A","text":"opposer deux idees dans une meme phrase"},{"key":"B","text":"repeter un son"},{"key":"C","text":"attenuer un propos"},{"key":"D","text":"personnifier un objet"}]'::jsonb, 'A', 'Figures de style', 14, 2, 'Elle met en parallele des termes opposes.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q16', 'test_fran_lycee', 'Victor Hugo est un auteur majeur du :', '[{"key":"A","text":"classicisme"},{"key":"B","text":"romantisme"},{"key":"C","text":"surrealisme"},{"key":"D","text":"naturalisme"}]'::jsonb, 'B', 'Litterature', 15, 1, 'Il est la figure centrale du romantisme francais.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q17', 'test_fran_lycee', '« Les Miserables » a ete ecrit par :', '[{"key":"A","text":"Emile Zola"},{"key":"B","text":"Victor Hugo"},{"key":"C","text":"Gustave Flaubert"},{"key":"D","text":"Honore de Balzac"}]'::jsonb, 'B', 'Litterature', 16, 1, 'Roman publie par Victor Hugo en 1862.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q18', 'test_fran_lycee', 'Le naturalisme est principalement associe a :', '[{"key":"A","text":"Emile Zola"},{"key":"B","text":"Jean Racine"},{"key":"C","text":"Paul Verlaine"},{"key":"D","text":"Moliere"}]'::jsonb, 'A', 'Litterature', 17, 2, 'Zola en est le theoricien et le principal representant.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q19', 'test_fran_lycee', 'Moliere est surtout connu comme auteur :', '[{"key":"A","text":"de tragedies"},{"key":"B","text":"de comedies"},{"key":"C","text":"de poemes epiques"},{"key":"D","text":"de romans"}]'::jsonb, 'B', 'Litterature', 18, 1, 'Il est le maitre de la comedie classique.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q20', 'test_fran_lycee', 'Un sonnet est un poeme de :', '[{"key":"A","text":"12 vers"},{"key":"B","text":"14 vers"},{"key":"C","text":"16 vers"},{"key":"D","text":"10 vers"}]'::jsonb, 'B', 'Litterature', 19, 2, 'Deux quatrains suivis de deux tercets.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q21', 'test_fran_lycee', 'L''alexandrin est un vers de :', '[{"key":"A","text":"8 syllabes"},{"key":"B","text":"10 syllabes"},{"key":"C","text":"12 syllabes"},{"key":"D","text":"14 syllabes"}]'::jsonb, 'C', 'Litterature', 20, 2, 'Le vers de douze syllabes est l''alexandrin.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q22', 'test_fran_lycee', 'Le siecle des Lumieres correspond au :', '[{"key":"A","text":"XVIe siecle"},{"key":"B","text":"XVIIe siecle"},{"key":"C","text":"XVIIIe siecle"},{"key":"D","text":"XIXe siecle"}]'::jsonb, 'C', 'Litterature', 21, 2, 'Voltaire, Rousseau et Diderot marquent le XVIIIe siecle.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q23', 'test_fran_lycee', 'Le theatre classique repose sur la regle :', '[{"key":"A","text":"des trois unites"},{"key":"B","text":"des cinq sens"},{"key":"C","text":"du vers libre"},{"key":"D","text":"du monologue unique"}]'::jsonb, 'A', 'Litterature', 22, 2, 'Unite de temps, de lieu et d''action.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q24', 'test_fran_lycee', 'Le registre pathetique cherche a susciter :', '[{"key":"A","text":"le rire"},{"key":"B","text":"la pitie et l''emotion"},{"key":"C","text":"la peur"},{"key":"D","text":"l''admiration"}]'::jsonb, 'B', 'Analyse de texte', 23, 2, 'Il vise a emouvoir le lecteur.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q25', 'test_fran_lycee', 'Un texte argumentatif a pour but :', '[{"key":"A","text":"de raconter une histoire"},{"key":"B","text":"de convaincre ou persuader"},{"key":"C","text":"de decrire un lieu"},{"key":"D","text":"d''expliquer une recette"}]'::jsonb, 'B', 'Analyse de texte', 24, 1, 'Il defend une these aupres d''un destinataire.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q26', 'test_fran_lycee', 'La focalisation interne signifie que le recit adopte :', '[{"key":"A","text":"le point de vue d''un personnage"},{"key":"B","text":"un point de vue omniscient"},{"key":"C","text":"un regard exterieur neutre"},{"key":"D","text":"plusieurs narrateurs"}]'::jsonb, 'A', 'Analyse de texte', 25, 3, 'Le lecteur ne sait que ce que sait le personnage.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q27', 'test_fran_lycee', 'Le registre ironique repose sur :', '[{"key":"A","text":"l''exageration seule"},{"key":"B","text":"un ecart entre ce qui est dit et ce qui est pense"},{"key":"C","text":"la description precise"},{"key":"D","text":"la repetition"}]'::jsonb, 'B', 'Analyse de texte', 26, 2, 'L''ironie dit le contraire de ce qu''elle signifie.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q28', 'test_fran_lycee', 'Dans un recit, l''incipit designe :', '[{"key":"A","text":"le denouement"},{"key":"B","text":"le debut du texte"},{"key":"C","text":"le point culminant"},{"key":"D","text":"la morale"}]'::jsonb, 'B', 'Analyse de texte', 27, 2, 'L''incipit est l''ouverture de l''oeuvre.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q29', 'test_fran_lycee', 'Un champ lexical est :', '[{"key":"A","text":"un ensemble de mots lies a un meme theme"},{"key":"B","text":"une figure de style"},{"key":"C","text":"un type de vers"},{"key":"D","text":"un genre litteraire"}]'::jsonb, 'A', 'Analyse de texte', 28, 1, 'Il regroupe les termes renvoyant a une meme notion.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_fran_lycee_q30', 'test_fran_lycee', 'Le narrateur omniscient se caracterise par :', '[{"key":"A","text":"une connaissance limitee"},{"key":"B","text":"une connaissance totale des personnages"},{"key":"C","text":"l''absence de point de vue"},{"key":"D","text":"une narration a la deuxieme personne"}]'::jsonb, 'B', 'Analyse de texte', 29, 2, 'Il sait tout des personnages et de l''intrigue.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)
  values ('test_angl_lycee', 'sub_angl', 'lvl_lycee', 'Anglais — Lycee', 30, 15, 70, 'Test individuel et chronometre. Une seule reponse par question.')
  on conflict (id) do update set
    title = excluded.title, question_count = excluded.question_count,
    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q1', 'test_angl_lycee', 'Choose the correct form: She ___ to school every day.', '[{"key":"A","text":"go"},{"key":"B","text":"goes"},{"key":"C","text":"going"},{"key":"D","text":"gone"}]'::jsonb, 'B', 'Grammar', 0, 1, 'Third person singular in the present simple takes -s.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q2', 'test_angl_lycee', 'Choose the correct past form: They ___ the film last night.', '[{"key":"A","text":"watch"},{"key":"B","text":"watches"},{"key":"C","text":"watched"},{"key":"D","text":"watching"}]'::jsonb, 'C', 'Grammar', 1, 1, 'Past simple of a regular verb: watched.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q3', 'test_angl_lycee', 'Which sentence is in the present perfect?', '[{"key":"A","text":"I saw him yesterday"},{"key":"B","text":"I have seen him"},{"key":"C","text":"I was seeing him"},{"key":"D","text":"I will see him"}]'::jsonb, 'B', 'Grammar', 2, 2, 'have/has + past participle forms the present perfect.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q4', 'test_angl_lycee', 'Complete: If it ___ tomorrow, we will stay at home.', '[{"key":"A","text":"rain"},{"key":"B","text":"rains"},{"key":"C","text":"rained"},{"key":"D","text":"will rain"}]'::jsonb, 'B', 'Grammar', 3, 2, 'First conditional: if + present simple, will + base form.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q5', 'test_angl_lycee', 'Choose the correct comparative: This book is ___ than that one.', '[{"key":"A","text":"more interesting"},{"key":"B","text":"most interesting"},{"key":"C","text":"interestinger"},{"key":"D","text":"as interesting"}]'::jsonb, 'A', 'Grammar', 4, 2, 'Long adjectives form the comparative with ''more''.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q6', 'test_angl_lycee', 'Complete: She has been teaching ___ 2015.', '[{"key":"A","text":"for"},{"key":"B","text":"since"},{"key":"C","text":"during"},{"key":"D","text":"from"}]'::jsonb, 'B', 'Grammar', 5, 2, '''Since'' introduces a starting point in time.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q7', 'test_angl_lycee', 'Choose the passive form of ''The teacher corrects the exercises''.', '[{"key":"A","text":"The exercises correct the teacher"},{"key":"B","text":"The exercises are corrected by the teacher"},{"key":"C","text":"The exercises were correcting"},{"key":"D","text":"The teacher is corrected"}]'::jsonb, 'B', 'Grammar', 6, 2, 'Passive: be + past participle + by + agent.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q8', 'test_angl_lycee', 'Complete: I wish I ___ more time.', '[{"key":"A","text":"have"},{"key":"B","text":"had"},{"key":"C","text":"will have"},{"key":"D","text":"having"}]'::jsonb, 'B', 'Grammar', 7, 3, 'After ''I wish'', the past simple expresses an unreal present.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q9', 'test_angl_lycee', 'Choose the correct reported speech: He said, ''I am tired.''', '[{"key":"A","text":"He said he is tired"},{"key":"B","text":"He said he was tired"},{"key":"C","text":"He said he will be tired"},{"key":"D","text":"He said he tired"}]'::jsonb, 'B', 'Grammar', 8, 3, 'The present shifts to the past in reported speech.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q10', 'test_angl_lycee', 'Choose the correct question tag: You are a teacher, ___ ?', '[{"key":"A","text":"are you"},{"key":"B","text":"aren''t you"},{"key":"C","text":"don''t you"},{"key":"D","text":"isn''t it"}]'::jsonb, 'B', 'Grammar', 9, 2, 'A positive statement takes a negative tag.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q11', 'test_angl_lycee', 'What is the opposite of ''difficult''?', '[{"key":"A","text":"hard"},{"key":"B","text":"easy"},{"key":"C","text":"heavy"},{"key":"D","text":"strong"}]'::jsonb, 'B', 'Vocabulary', 10, 1, '''Easy'' is the antonym of ''difficult''.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q12', 'test_angl_lycee', 'A person who teaches at a university is usually called a :', '[{"key":"A","text":"pupil"},{"key":"B","text":"lecturer"},{"key":"C","text":"trainee"},{"key":"D","text":"principal"}]'::jsonb, 'B', 'Vocabulary', 11, 2, '''Lecturer'' designates a university teacher.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q13', 'test_angl_lycee', 'The word ''syllabus'' refers to :', '[{"key":"A","text":"a classroom"},{"key":"B","text":"a course programme"},{"key":"C","text":"an exam paper"},{"key":"D","text":"a school holiday"}]'::jsonb, 'B', 'Vocabulary', 12, 2, 'A syllabus outlines the content of a course.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q14', 'test_angl_lycee', 'Choose the correct word: The students ___ the exam next week.', '[{"key":"A","text":"will sit"},{"key":"B","text":"sit down"},{"key":"C","text":"will seat"},{"key":"D","text":"are sat"}]'::jsonb, 'A', 'Vocabulary', 13, 2, '''To sit an exam'' is the standard collocation.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q15', 'test_angl_lycee', 'What does ''to assess'' mean?', '[{"key":"A","text":"to punish"},{"key":"B","text":"to evaluate"},{"key":"C","text":"to register"},{"key":"D","text":"to postpone"}]'::jsonb, 'B', 'Vocabulary', 14, 2, '''Assess'' means to evaluate or judge.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q16', 'test_angl_lycee', 'The head of a secondary school in British English is the :', '[{"key":"A","text":"headmaster"},{"key":"B","text":"dean"},{"key":"C","text":"chancellor"},{"key":"D","text":"tutor"}]'::jsonb, 'A', 'Vocabulary', 15, 2, '''Headmaster'' or ''head teacher'' leads a school.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q17', 'test_angl_lycee', 'Choose the synonym of ''improve'':', '[{"key":"A","text":"worsen"},{"key":"B","text":"enhance"},{"key":"C","text":"reduce"},{"key":"D","text":"delay"}]'::jsonb, 'B', 'Vocabulary', 16, 2, '''Enhance'' means to make better.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q18', 'test_angl_lycee', 'A ''deadline'' is :', '[{"key":"A","text":"a final date"},{"key":"B","text":"a punishment"},{"key":"C","text":"a lesson plan"},{"key":"D","text":"a school subject"}]'::jsonb, 'A', 'Vocabulary', 17, 1, 'A deadline is the latest acceptable time.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q19', 'test_angl_lycee', 'Which sentence is correctly punctuated?', '[{"key":"A","text":"Where are you going"},{"key":"B","text":"Where are you going?"},{"key":"C","text":"Where are you going."},{"key":"D","text":"where are you going?"}]'::jsonb, 'B', 'Written expression', 18, 1, 'A direct question ends with a question mark and starts with a capital.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q20', 'test_angl_lycee', 'Choose the correctly spelled word:', '[{"key":"A","text":"recieve"},{"key":"B","text":"receive"},{"key":"C","text":"receve"},{"key":"D","text":"reciive"}]'::jsonb, 'B', 'Written expression', 19, 2, '''i'' before ''e'' except after ''c''.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q21', 'test_angl_lycee', 'Which linking word expresses contrast?', '[{"key":"A","text":"moreover"},{"key":"B","text":"however"},{"key":"C","text":"therefore"},{"key":"D","text":"besides"}]'::jsonb, 'B', 'Written expression', 20, 2, '''However'' introduces an opposing idea.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q22', 'test_angl_lycee', 'Which linking word expresses consequence?', '[{"key":"A","text":"although"},{"key":"B","text":"therefore"},{"key":"C","text":"whereas"},{"key":"D","text":"despite"}]'::jsonb, 'B', 'Written expression', 21, 2, '''Therefore'' introduces a result.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q23', 'test_angl_lycee', 'Choose the correct sentence:', '[{"key":"A","text":"He don''t like maths"},{"key":"B","text":"He doesn''t likes maths"},{"key":"C","text":"He doesn''t like maths"},{"key":"D","text":"He not like maths"}]'::jsonb, 'C', 'Written expression', 22, 1, 'Third person negative: doesn''t + base form.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q24', 'test_angl_lycee', 'A formal letter usually ends with :', '[{"key":"A","text":"See you"},{"key":"B","text":"Yours sincerely"},{"key":"C","text":"Bye"},{"key":"D","text":"Cheers"}]'::jsonb, 'B', 'Written expression', 23, 2, '''Yours sincerely'' closes a formal letter to a named person.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q25', 'test_angl_lycee', 'Which word is a preposition?', '[{"key":"A","text":"quickly"},{"key":"B","text":"between"},{"key":"C","text":"happy"},{"key":"D","text":"run"}]'::jsonb, 'B', 'Written expression', 24, 1, '''Between'' introduces a relation of place or time.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q26', 'test_angl_lycee', 'In English teaching, ''CEFR'' levels range from :', '[{"key":"A","text":"A1 to C2"},{"key":"B","text":"1 to 10"},{"key":"C","text":"Beginner to Master"},{"key":"D","text":"L1 to L3"}]'::jsonb, 'A', 'Teaching English', 25, 2, 'The Common European Framework goes from A1 to C2.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q27', 'test_angl_lycee', 'A ''listening comprehension'' activity mainly develops :', '[{"key":"A","text":"writing"},{"key":"B","text":"oral understanding"},{"key":"C","text":"grammar drills"},{"key":"D","text":"handwriting"}]'::jsonb, 'B', 'Teaching English', 26, 1, 'It trains the ability to understand spoken English.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q28', 'test_angl_lycee', 'Pair work in class is mainly used to :', '[{"key":"A","text":"reduce speaking time"},{"key":"B","text":"increase learner interaction"},{"key":"C","text":"avoid corrections"},{"key":"D","text":"replace assessment"}]'::jsonb, 'B', 'Teaching English', 27, 2, 'It maximises the time each learner speaks.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q29', 'test_angl_lycee', 'Formative assessment is designed to :', '[{"key":"A","text":"rank students at the end of the year"},{"key":"B","text":"guide learning during the course"},{"key":"C","text":"select candidates"},{"key":"D","text":"replace the syllabus"}]'::jsonb, 'B', 'Teaching English', 28, 3, 'It provides feedback while learning is still in progress.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;
insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)
  values ('test_angl_lycee_q30', 'test_angl_lycee', 'The main aim of a communicative approach is to :', '[{"key":"A","text":"memorise grammar rules"},{"key":"B","text":"use the language in real situations"},{"key":"C","text":"translate texts only"},{"key":"D","text":"practise handwriting"}]'::jsonb, 'B', 'Teaching English', 29, 2, 'It prioritises meaningful communication over rule learning.')
  on conflict (id) do update set statement = excluded.statement, options = excluded.options,
    correct_key = excluded.correct_key, explanation = excluded.explanation;

-- Etablissements de demonstration
insert into institutions (id, name, type, city, address, manager_name, description, verification_status,
                          phone, phone_alt, email, website, founded_year, ownership,
                          academic_system, degrees, specialties, facilities)
  values ('inst_unc', 'Université Nongo Conakry', 'UNIVERSITY', 'Conakry', 'Nongo Contéyah (C/Ratoma), BP 6420, Conakry', 'Direction des ressources humaines', 'Université privée fondée en 2007 à Nongo Contéyah. Formations professionnalisantes et cursus LMD, du BTS au Master.', 'VERIFIED',
          '+224 610 00 38 89', '+224 622 21 35 70', 'contact@unc-edu.org', 'https://unc-edu.org', 2007, 'PRIVATE',
          'LMD', 'BTS,LICENCE,MASTER', 'Droit,Sciences politiques,Génie informatique,Télécommunications,MIAGE,Économie et gestion,Sociologie,Génie civil,Comptabilité,Logistique et transport,Banque et assurance,Master sécurité informatique', '40 salles de classe,8 salles informatique,2 amphithéâtres,1 salle de conférence,1 cyber-centre de recherche,1 bibliothèque,2 laboratoires,1 infirmerie,2 cafétérias et restaurants')
  on conflict (id) do update set name = excluded.name, description = excluded.description,
    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,
    website = excluded.website, founded_year = excluded.founded_year,
    ownership = excluded.ownership, academic_system = excluded.academic_system,
    degrees = excluded.degrees, specialties = excluded.specialties,
    facilities = excluded.facilities;
insert into institutions (id, name, type, city, address, manager_name, description, verification_status,
                          phone, phone_alt, email, website, founded_year, ownership,
                          academic_system, degrees, specialties, facilities)
  values ('inst_gamal', 'Universite Gamal Abdel Nasser', 'UNIVERSITY', 'Conakry', 'Campus de Dixinn, Conakry', 'Direction des ressources humaines', 'Premiere universite publique de Guinee, formant plus de 20 000 etudiants.', 'VERIFIED',
          '+224 622 10 20 30', '+224 664 10 20 31', 'contact@uganc.edu.gn', 'https://uganc.edu.gn', 1962, 'PUBLIC',
          'LMD', 'LICENCE,MASTER,DOCTORAT', 'Mathématiques,Physique,Chimie,Informatique,Médecine,Droit,Lettres modernes,Sciences économiques', '120 salles de classe,6 amphithéâtres,1 bibliothèque centrale,12 laboratoires,1 centre médical,3 restaurants universitaires')
  on conflict (id) do update set name = excluded.name, description = excluded.description,
    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,
    website = excluded.website, founded_year = excluded.founded_year,
    ownership = excluded.ownership, academic_system = excluded.academic_system,
    degrees = excluded.degrees, specialties = excluded.specialties,
    facilities = excluded.facilities;
insert into institutions (id, name, type, city, address, manager_name, description, verification_status,
                          phone, phone_alt, email, website, founded_year, ownership,
                          academic_system, degrees, specialties, facilities)
  values ('inst_excellence', 'Lycee Excellence', 'HIGH_SCHOOL', 'Kankan', 'Quartier Timbo, Kankan', 'Proviseur', 'Etablissement prive d''enseignement general, series scientifiques et litteraires.', 'VERIFIED',
          '+224 621 44 55 66', null, 'direction@lycee-excellence.gn', null, 1998, 'PRIVATE',
          'SECONDAIRE', 'BAC', 'Sciences mathématiques,Sciences expérimentales,Sciences sociales,Lettres', '24 salles de classe,2 salles informatique,1 bibliothèque,1 laboratoire de sciences,1 terrain de sport')
  on conflict (id) do update set name = excluded.name, description = excluded.description,
    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,
    website = excluded.website, founded_year = excluded.founded_year,
    ownership = excluded.ownership, academic_system = excluded.academic_system,
    degrees = excluded.degrees, specialties = excluded.specialties,
    facilities = excluded.facilities;
insert into institutions (id, name, type, city, address, manager_name, description, verification_status,
                          phone, phone_alt, email, website, founded_year, ownership,
                          academic_system, degrees, specialties, facilities)
  values ('inst_kindia', 'Universite de Kindia', 'UNIVERSITY', 'Kindia', 'Route de Mamou, Kindia', 'Service du personnel', 'Universite regionale — sciences, agronomie et sciences de la sante.', 'VERIFIED',
          '+224 628 77 11 22', null, 'scolarite@univ-kindia.gn', 'https://univ-kindia.gn', 2004, 'PUBLIC',
          'LMD', 'LICENCE,MASTER', 'Agronomie,Sciences de la vie,Gestion,Sociologie,Sciences de l’éducation', '45 salles de classe,3 amphithéâtres,1 bibliothèque,4 laboratoires,1 ferme expérimentale,1 cafétéria')
  on conflict (id) do update set name = excluded.name, description = excluded.description,
    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,
    website = excluded.website, founded_year = excluded.founded_year,
    ownership = excluded.ownership, academic_system = excluded.academic_system,
    degrees = excluded.degrees, specialties = excluded.specialties,
    facilities = excluded.facilities;
insert into institutions (id, name, type, city, address, manager_name, description, verification_status,
                          phone, phone_alt, email, website, founded_year, ownership,
                          academic_system, degrees, specialties, facilities)
  values ('inst_ismm', 'Institut Superieur des Mines et Geologie', 'INSTITUTE', 'Boke', 'Boke centre', 'Directeur des etudes', 'Institut specialise dans les metiers des mines et de la geologie.', 'VERIFIED',
          '+224 655 30 40 50', null, 'contact@ismg-boke.gn', null, 1992, 'PUBLIC',
          'LMD', 'BTS,LICENCE,MASTER', 'Géologie,Exploitation minière,Génie civil,Électromécanique,Environnement', '30 salles de classe,5 laboratoires,1 halle technologique,1 bibliothèque,2 salles informatique,1 internat')
  on conflict (id) do update set name = excluded.name, description = excluded.description,
    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,
    website = excluded.website, founded_year = excluded.founded_year,
    ownership = excluded.ownership, academic_system = excluded.academic_system,
    degrees = excluded.degrees, specialties = excluded.specialties,
    facilities = excluded.facilities;
insert into institutions (id, name, type, city, address, manager_name, description, verification_status,
                          phone, phone_alt, email, website, founded_year, ownership,
                          academic_system, degrees, specialties, facilities)
  values ('inst_cfp', 'Centre de Formation Professionnelle Sonfonia', 'TRAINING_CENTER', 'Conakry', 'Sonfonia, Ratoma', 'Coordination pedagogique', 'Formations qualifiantes en informatique, comptabilite et gestion.', 'VERIFIED',
          '+224 620 88 99 00', null, 'cfp.sonfonia@formation.gn', null, 2011, 'PUBLIC',
          'PROFESSIONNEL', 'CAP,BTS', 'Électricité bâtiment,Maintenance informatique,Couture,Mécanique auto,Froid et climatisation', '12 ateliers,6 salles de classe,1 salle informatique,1 magasin d’outillage')
  on conflict (id) do update set name = excluded.name, description = excluded.description,
    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,
    website = excluded.website, founded_year = excluded.founded_year,
    ownership = excluded.ownership, academic_system = excluded.academic_system,
    degrees = excluded.degrees, specialties = excluded.specialties,
    facilities = excluded.facilities;

-- Offres publiees (§17)
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_math_gamal', 'inst_gamal', 'Professeur de Mathematiques', 'sub_math', array['lvl_l2', 'lvl_l3']::text[], 'Conakry', 'PERMANENT', 'L''Universite Gamal Abdel Nasser recrute un enseignant de mathematiques pour les cours d''analyse et d''algebre lineaire en L2 et L3. Charge horaire de 12 heures hebdomadaires, encadrement de travaux diriges et participation aux jurys d''examen.',
          3000000, 4200000, true, 3, true,
          'PUBLIC', 'PUBLISHED', now() - interval '4 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_phys_excellence', 'inst_excellence', 'Enseignant de Physique', 'sub_phys', array['lvl_11', 'lvl_12']::text[], 'Kankan', 'FIXED_TERM', 'Le Lycee Excellence recherche un enseignant de physique pour les classes de 11eme et 12eme annee, series scientifiques. Preparation aux examens nationaux et animation du laboratoire.',
          2200000, 2800000, true, 2, false,
          'PUBLIC', 'PUBLISHED', now() - interval '5 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_chim_kindia', 'inst_kindia', 'Professeur de Chimie', 'sub_chim', array['lvl_l1', 'lvl_l2', 'lvl_l3']::text[], 'Kindia', 'PERMANENT', 'Poste de professeur de chimie generale et organique, licences scientifiques. Encadrement de travaux pratiques et suivi des memoires de licence.',
          2800000, 3600000, true, 3, true,
          'PUBLIC', 'PUBLISHED', now() - interval '6 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_info_cfp', 'inst_cfp', 'Formateur en Informatique', 'sub_info', array['lvl_l1', 'lvl_l2']::text[], 'Conakry', 'HOURLY', 'Formation aux bases de la programmation, aux bases de donnees et a la bureautique avancee. Vacations de 15 heures par semaine, possibilite d''evolution vers un contrat permanent.',
          1800000, 2400000, true, 1, false,
          'PUBLIC', 'PUBLISHED', now() - interval '2 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_math_ismm', 'inst_ismm', 'Enseignant-chercheur en Mathematiques appliquees', 'sub_math', array['lvl_l3', 'lvl_m1']::text[], 'Boke', 'PERMANENT', 'Enseignement des mathematiques appliquees a la geologie et aux mines. Statistiques, modelisation et analyse numerique. Participation aux projets de recherche de l''institut.',
          3500000, 4500000, true, 5, true,
          'PUBLIC', 'PUBLISHED', now() - interval '8 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_fran_excellence', 'inst_excellence', 'Professeur de Francais', 'sub_fran', array['lvl_lycee']::text[], 'Kankan', 'FIXED_TERM', 'Enseignement du francais au lycee : litterature, expression ecrite et preparation au baccalaureat. Remplacement d''un an renouvelable.',
          2000000, 2500000, false, 2, false,
          'PUBLIC', 'PUBLISHED', now() - interval '11 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_angl_gamal', 'inst_gamal', 'Enseignant d''Anglais', 'sub_angl', array['lvl_l1', 'lvl_l2']::text[], 'Conakry', 'HOURLY', 'Cours d''anglais general et d''anglais de specialite pour les filieres scientifiques. Vacations reparties sur trois jours par semaine.',
          1500000, 2000000, true, 1, false,
          'PUBLIC', 'PUBLISHED', now() - interval '1 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_math_unc', 'inst_unc', 'Professeur de Mathematiques', 'sub_math', array['lvl_7', 'lvl_terminale']::text[], 'Conakry', 'HOURLY', 'Université Nongo Conakry recrute un enseignant de mathematiques. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          3000000, 3500000, true, 1, true,
          'PUBLIC', 'PUBLISHED', now() - interval '5 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_fran_gamal', 'inst_gamal', 'Professeur de Francais', 'sub_fran', array['lvl_l3', 'lvl_m1']::text[], 'Conakry', 'FIXED_TERM', 'Universite Gamal Abdel Nasser recrute un enseignant de francais. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          2500000, 3300000, true, 0, false,
          'PUBLIC', 'PUBLISHED', now() - interval '17 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_angl_excellence', 'inst_excellence', 'Professeur d’Anglais', 'sub_angl', array['lvl_7', 'lvl_12']::text[], 'Kankan', 'PERMANENT', 'Lycee Excellence recrute un enseignant de anglais. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          1500000, 2700000, true, 1, false,
          'PUBLIC', 'PUBLISHED', now() - interval '4 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_phys_kindia', 'inst_kindia', 'Professeur de Physique', 'sub_phys', array['lvl_l2', 'lvl_12']::text[], 'Kindia', 'HOURLY', 'Universite de Kindia recrute un enseignant de physique. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          1500000, 2300000, false, 5, true,
          'PUBLIC', 'PUBLISHED', now() - interval '21 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_info_ismm', 'inst_ismm', 'Enseignant en Informatique', 'sub_info', array['lvl_m1', 'lvl_terminale']::text[], 'Boke', 'FIXED_TERM', 'Institut Superieur des Mines et Geologie recrute un enseignant de informatique. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          2500000, 3700000, true, 2, false,
          'PUBLIC', 'PUBLISHED', now() - interval '17 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_biol_cfp', 'inst_cfp', 'Professeur de Biologie', 'sub_biol', array['lvl_terminale', 'lvl_8']::text[], 'Conakry', 'PERMANENT', 'Centre de Formation Professionnelle Sonfonia recrute un enseignant de biologie. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          2500000, 3300000, true, 5, false,
          'PUBLIC', 'PUBLISHED', now() - interval '9 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_hist_unc', 'inst_unc', 'Professeur d’Histoire', 'sub_hist', array['lvl_10', 'lvl_l2']::text[], 'Conakry', 'HOURLY', 'Université Nongo Conakry recrute un enseignant de histoire. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          2000000, 3200000, true, 2, true,
          'PUBLIC', 'PUBLISHED', now() - interval '12 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_econ_gamal', 'inst_gamal', 'Enseignant en Economie', 'sub_econ', array['lvl_l2', 'lvl_terminale']::text[], 'Conakry', 'PERMANENT', 'Universite Gamal Abdel Nasser recrute un enseignant de economie. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          2500000, 3000000, false, 0, false,
          'PUBLIC', 'PUBLISHED', now() - interval '10 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_chim_excellence', 'inst_excellence', 'Professeur de Chimie', 'sub_chim', array['lvl_l3', 'lvl_12']::text[], 'Kankan', 'PERMANENT', 'Lycee Excellence recrute un enseignant de chimie. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          1500000, 2700000, true, 0, false,
          'PUBLIC', 'PUBLISHED', now() - interval '12 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;
insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,
                  salary_min, salary_max, salary_published, min_experience, requires_certification,
                  visibility, status, published_at)
  values ('job_philo_kindia', 'inst_kindia', 'Professeur de Philosophie', 'sub_philo', array['lvl_l1', 'lvl_l3']::text[], 'Kindia', 'HOURLY', 'Universite de Kindia recrute un enseignant de philosophie. Charge horaire a convenir, encadrement des travaux diriges et participation aux jurys.',
          2500000, 3000000, true, 1, true,
          'PUBLIC', 'PUBLISHED', now() - interval '13 days')
  on conflict (id) do update set title = excluded.title, description = excluded.description,
    status = excluded.status, published_at = excluded.published_at;

insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_forfait_500mo', 'Forfait internet 500 Mo', 'La premiere recompense a portee : deux seances suivies suffisent.', '',
          150, 7500, 100, 0, 'DIRECT', null)
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_forfait_1go', 'Forfait internet 1 Go', 'De quoi suivre quatre seances en direct, ou telecharger une dizaine de cours video.', '',
          250, 15000, 50, 1, 'DIRECT', null)
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_mois_offert', 'Un mois d''abonnement offert', 'Le mois suivant ne vous est pas facture. L''assistant et les cours restent ouverts.', '',
          400, 50000, 30, 2, 'DIRECT', null)
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_seance_offerte', 'Une seance en direct offerte', 'Une place dans la seance de votre choix, sans la payer.', '',
          600, 40000, 40, 3, 'DIRECT', null)
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_forfait_3go', 'Forfait internet 3 Go', 'De quoi tenir un mois de seances en direct.', '',
          700, 45000, 25, 4, 'DIRECT', null)
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_cours_video', 'Un cours video au choix', 'N''importe quel cours du catalogue, jusqu''a 50 000 GNF.', '',
          800, 50000, 20, 5, 'DIRECT', null)
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_galaxy_a5', 'Samsung Galaxy A5', 'Telephone Android, ecran 5,2 pouces. Mis au tirage : chaque entree est une chance.', 'lot-galaxy-a5',
          150, 750000, 3, 6, 'RAFFLE', now() + interval '30 days')
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_watch_ultra_3', 'Apple Watch Ultra 3', 'Montre connectee, bracelet Alpine. Mise au tirage.', 'lot-watch-ultra-3',
          300, 6500000, 1, 7, 'RAFFLE', now() + interval '90 days')
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_iphone_15', 'iPhone 15', '128 Go, double capteur photo. Mis au tirage.', 'lot-iphone-15',
          300, 5000000, 1, 8, 'RAFFLE', now() + interval '90 days')
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();
insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)
  values ('lot_iphone_17', 'iPhone 17', '128 Go. Le grand tirage de fin d annee.', 'lot-iphone-17',
          500, 8000000, 1, 9, 'RAFFLE', now() + interval '180 days')
  on conflict (id) do update set name = excluded.name, summary = excluded.summary,
    image = excluded.image, points_price = excluded.points_price,
    value_gnf = excluded.value_gnf, position = excluded.position,
    kind = excluded.kind, updated_at = now();

commit;
