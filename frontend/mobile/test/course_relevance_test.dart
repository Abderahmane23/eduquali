import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/usecases/course_relevance.dart';

/// Le catalogue parle-t-il de l'apprenant ?
///
/// Il ne le faisait pas : `published()` ne filtre que le statut, et quelqu'un
/// qui venait de déclarer sa classe et cinq matières voyait le catalogue d'un
/// élève de CE2. Ces règles sont pures, donc vérifiables sans base.
void main() {
  const cours = [
    (id: 'maths_12', subject: 'math', levels: ['lvl_12']),
    (id: 'maths_7', subject: 'math', levels: ['lvl_7']),
    (id: 'hist_12', subject: 'hist', levels: ['lvl_12']),
    (id: 'chim_l1', subject: 'chim', levels: ['lvl_l1']),
  ];

  List<String> ids(
    List<({String id, String subject, List<String> levels})> l,
  ) => [for (final c in l) c.id];

  List<({String id, String subject, List<String> levels})> trier(
    LearnerTaste taste,
  ) => coursesByAffinity(
    cours,
    taste: taste,
    subjectOf: (c) => c.subject,
    levelsOf: (c) => c.levels,
  );

  group('le classement par affinité', () {
    test('la matière pèse plus que le niveau', () {
      // « Maths en 7ème » reste des maths ; « histoire en 12ème » est la
      // bonne classe dans une matière qu'on ne suit pas.
      final taste = LearnerTaste(levelId: 'lvl_12', subjectIds: {'math'});
      expect(ids(trier(taste)).first, 'maths_12');
      expect(ids(trier(taste))[1], 'maths_7');
    });

    test('rien de déclaré laisse l’ordre du catalogue intact', () {
      expect(ids(trier(const LearnerTaste())), ids(cours));
    });

    test('aucun cours ne disparaît', () {
      final taste = LearnerTaste(levelId: 'lvl_12', subjectIds: {'math'});
      // Le catalogue se réordonne, il ne rétrécit pas : un cours d'une autre
      // classe sert à réviser l'année passée.
      expect(trier(taste), hasLength(cours.length));
    });

    test('à score égal, l’ordre d’origine est conservé', () {
      // `sort` de Dart n'est pas stable : sans position de départ, deux cours
      // sans rapport avec l'apprenant pouvaient s'échanger à chaque ouverture.
      final taste = LearnerTaste(levelId: 'lvl_l1', subjectIds: {'chim'});
      final ordre = ids(trier(taste));
      expect(ordre.first, 'chim_l1');
      expect(ordre.sublist(1), ['maths_12', 'maths_7', 'hist_12']);
    });
  });

  group('la mise en avant sur l’accueil', () {
    List<({String id, String subject, List<String> levels})> avant(
      LearnerTaste taste, {
      int max = 4,
    }) => recommendedCourses(
      cours,
      taste: taste,
      subjectOf: (c) => c.subject,
      levelsOf: (c) => c.levels,
      max: max,
    );

    test('ne retient que ce qui correspond vraiment', () {
      final retenus = ids(
        avant(LearnerTaste(levelId: 'lvl_12', subjectIds: {'math'})),
      );
      expect(retenus, containsAll(['maths_12', 'maths_7', 'hist_12']));
      expect(
        retenus,
        isNot(contains('chim_l1')),
        reason: 'ni la matière ni la classe : la section mentirait',
      );
    });

    test('vide quand rien ne correspond, plutôt que remplie au hasard', () {
      expect(
        avant(LearnerTaste(levelId: 'lvl_x', subjectIds: {'angl'})),
        isEmpty,
      );
    });

    test('vide quand on ne sait rien de l’apprenant', () {
      expect(avant(const LearnerTaste()), isEmpty);
    });

    test('respecte le maximum demandé', () {
      expect(
        avant(LearnerTaste(levelId: 'lvl_12', subjectIds: {'math'}), max: 2),
        hasLength(2),
      );
    });
  });
}
