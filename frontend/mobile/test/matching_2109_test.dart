import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/domain/usecases/matching_engine.dart';

/// Le barème de mise en relation fixé le 21/09.
///
/// Disponible 30, diplôme (master 30, licence 10), ville 30. L'expérience
/// complète les 10 points restants.
void main() {
  const need = MatchRequirement(
    subjectId: 'sub_math',
    levelIds: ['lvl_11'],
    city: 'Conakry',
    minExperience: 0,
  );

  MatchCandidate candidate({
    String diploma = 'MASTER',
    String? city = 'Conakry',
    Availability availability = Availability.available,
    int years = 10,
    List<String> subjects = const ['sub_math'],
    List<String> pairs = const ['sub_math:lvl_11'],
  }) => MatchCandidate(
    teacherId: 't1',
    subjectIds: subjects,
    levelPairs: pairs,
    certifications: const {},
    yearsExperience: years,
    city: city,
    availability: availability,
    highestDiploma: diploma,
  );

  int points(MatchScore score, String key) =>
      score.factors.firstWhere((f) => f.key == key).points;

  group('Le barème', () {
    test('les trois critères de la note valent 30 points chacun', () {
      expect(AppConstants.matchingPoints['availability'], 30);
      expect(AppConstants.matchingPoints['diploma'], 30);
      expect(AppConstants.matchingPoints['location'], 30);
    });

    test('le total fait 100', () {
      final total = AppConstants.matchingPoints.values.reduce((a, b) => a + b);
      expect(total, 100);
    });

    test('master 30, licence 10', () {
      expect(AppConstants.diplomaPoints['MASTER'], 30);
      expect(AppConstants.diplomaPoints['LICENCE'], 10);
    });
  });

  group('Ce que rapporte chaque critère', () {
    test('un profil parfait atteint 100', () {
      expect(scoreOf(need, candidate()).value, 100);
    });

    test('un master rapporte 30, une licence 10', () {
      expect(points(scoreOf(need, candidate()), 'diploma'), 30);
      expect(
        points(scoreOf(need, candidate(diploma: 'LICENCE')), 'diploma'),
        10,
      );
    });

    test('sans diplôme déclaré, aucun point de diplôme', () {
      final score = scoreOf(need, candidate(diploma: ''));
      expect(points(score, 'diploma'), 0);
      expect(score.value, 70);
    });

    test('une autre ville coûte la plus grande part des 30 points', () {
      // Sans être éliminatoire : un professeur de Labé peut se rapprocher
      // pour un poste à Conakry, et l'écarter d'office priverait les zones
      // où personne n'habite sur place.
      final score = scoreOf(need, candidate(city: 'Labé'));
      expect(points(score, 'location'), lessThan(15));
      expect(points(score, 'location'), greaterThan(0));
      expect(score.value, lessThan(scoreOf(need, candidate()).value));
    });

    test('un professeur indisponible perd les 30 points de disponibilité', () {
      final score = scoreOf(
        need,
        candidate(availability: Availability.unavailable),
      );
      expect(points(score, 'availability'), lessThan(30));
    });
  });

  group('La matière et le niveau sont des conditions, pas des points', () {
    test('la mauvaise matière annule le score, malgré tout le reste', () {
      // Un professeur de français ne se classe pas « un peu » sur un poste
      // de mathématiques.
      final score = scoreOf(
        need,
        candidate(subjects: ['sub_fran'], pairs: ['sub_fran:lvl_11']),
      );
      expect(score.value, 0);
    });

    test('le mauvais niveau annule aussi', () {
      final score = scoreOf(need, candidate(pairs: ['sub_math:lvl_terminale']));
      expect(score.value, 0);
    });

    test('la raison reste lisible même à zéro', () {
      // Un score nul sans explication laisserait l'établissement penser à
      // un bug.
      final score = scoreOf(
        need,
        candidate(subjects: ['sub_fran'], pairs: ['sub_fran:lvl_11']),
      );
      expect(score.factors.map((f) => f.key), contains('subject'));
      expect(score.weakest, isNotEmpty);
    });
  });

  group('Le classement', () {
    test('à égalité par ailleurs, le master passe devant la licence', () {
      final master = scoreOf(need, candidate()).value;
      final licence = scoreOf(need, candidate(diploma: 'LICENCE')).value;
      expect(master, greaterThan(licence));
      expect(master - licence, 20);
    });

    test('les deux critères pèsent 30, mais ne se perdent pas pareil', () {
      // Le diplôme se possède ou non ; la ville admet une nuance. À poids
      // égal, l'absence de diplôme coûte donc plus cher qu'un éloignement.
      final sansVille = scoreOf(need, candidate(city: 'Labé')).value;
      final sansDiplome = scoreOf(need, candidate(diploma: '')).value;
      expect(sansDiplome, lessThan(sansVille));
      expect(
        AppConstants.matchingPoints['location'],
        AppConstants.matchingPoints['diploma'],
      );
    });
  });
}

/// Raccourci de lecture : le moteur, appelé tel quel.
MatchScore scoreOf(MatchRequirement need, MatchCandidate candidate) =>
    MatchingEngine.score(need, candidate);
