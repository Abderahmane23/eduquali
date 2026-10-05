import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/core/utils/contact_masker.dart';
import 'package:veriprof/core/utils/formatters.dart';
import 'package:veriprof/core/utils/validators.dart';
import 'package:veriprof/domain/usecases/matching_engine.dart';
import 'package:veriprof/domain/usecases/profile_completion.dart';
import 'package:veriprof/domain/usecases/test_scoring.dart';
import 'package:veriprof/domain/usecases/trust_score.dart';

void main() {
  group('Correction du test de competence (§12)', () {
    final questions = [
      const ScorableQuestion(id: 'q1', correctKey: 'A', domain: 'Algebre'),
      const ScorableQuestion(id: 'q2', correctKey: 'B', domain: 'Algebre'),
      const ScorableQuestion(id: 'q3', correctKey: 'C', domain: 'Analyse'),
      const ScorableQuestion(id: 'q4', correctKey: 'D', domain: 'Analyse'),
    ];

    test('calcule le score global et le detail par domaine', () {
      final result = TestScoring.score(
        questions: questions,
        answers: {'q1': 'A', 'q2': 'B', 'q3': 'C', 'q4': 'A'},
        passingScore: 70,
      );

      expect(result.correctCount, 3);
      expect(result.score, 75);
      expect(result.passed, isTrue);

      final algebre = result.domainScores.firstWhere(
        (d) => d.domain == 'Algebre',
      );
      expect(algebre.percentage, 100);

      final analyse = result.domainScores.firstWhere(
        (d) => d.domain == 'Analyse',
      );
      expect(analyse.percentage, 50);
    });

    test('compte une question sans reponse comme incorrecte', () {
      final result = TestScoring.score(
        questions: questions,
        answers: {'q1': 'A', 'q2': 'B', 'q3': 'C'},
        passingScore: 70,
      );

      expect(result.answeredCount, 3);
      expect(result.unansweredCount, 1);
      expect(result.score, 75);
    });

    test('echoue sous le seuil configure', () {
      final result = TestScoring.score(
        questions: questions,
        answers: {'q1': 'A'},
        passingScore: 70,
      );

      expect(result.score, 25);
      expect(result.passed, isFalse);
    });
  });

  group('Moteur de matching (§61)', () {
    const need = MatchRequirement(
      subjectId: 'sub_math',
      levelIds: ['lvl_l1'],
      city: 'Conakry',
      minExperience: 3,
      requiresCertification: true,
    );

    test('classe au-dessus un profil diplome et local', () {
      final strong = MatchingEngine.score(
        need,
        const MatchCandidate(
          teacherId: 't1',
          subjectIds: ['sub_math'],
          levelPairs: ['sub_math:lvl_l1'],
          certifications: {'sub_math:lvl_l1': 91},
          yearsExperience: 5,
          city: 'Conakry',
          availability: Availability.available,
          highestDiploma: 'MASTER',
        ),
      );

      final weak = MatchingEngine.score(
        need,
        const MatchCandidate(
          teacherId: 't2',
          subjectIds: ['sub_math'],
          levelPairs: ['sub_math:lvl_l1'],
          certifications: {},
          yearsExperience: 1,
          city: 'Labe',
          availability: Availability.availableSoon,
          highestDiploma: 'LICENCE',
        ),
      );

      expect(strong.value, greaterThan(weak.value));
      expect(strong.value, greaterThanOrEqualTo(85));
    });

    test('reste explicable : chaque critere porte son detail', () {
      final score = MatchingEngine.score(
        need,
        const MatchCandidate(
          teacherId: 't3',
          subjectIds: ['sub_phys'],
          levelPairs: [],
          certifications: {},
          yearsExperience: 0,
          city: 'Boke',
          availability: Availability.unavailable,
        ),
      );

      expect(score.factors, hasLength(6));
      for (final factor in score.factors) {
        expect(factor.detail, isNotEmpty);
      }
      // Matiere absente et aucune certification : score tres bas.
      expect(score.value, lessThan(30));
    });

    test('la certification ne classe plus, depuis le bareme du 21/09', () {
      final score = MatchingEngine.score(
        need,
        const MatchCandidate(
          teacherId: 't4',
          subjectIds: ['sub_math'],
          levelPairs: ['sub_math:lvl_l1'],
          certifications: {},
          yearsExperience: 5,
          city: 'Conakry',
          availability: Availability.available,
        ),
      );

      // Les tests de competence restent affiches sur la fiche du
      // professeur ; ils ne departagent plus deux candidats.
      expect(
        score.factors.any((f) => f.key == 'competency'),
        isFalse,
        reason: 'le critere de certification est revenu dans le classement',
      );
      expect(
        score.factors.map((f) => f.key),
        containsAll(['availability', 'diploma', 'location', 'experience']),
      );
    });
  });

  group('Completion du profil (§16)', () {
    test('un profil vide part de zero', () {
      final completion = ProfileCompletionCalculator.compute(
        const CompletionInput(
          hasPersonalInfo: false,
          hasPhoto: false,
          identityStatus: VerificationStatus.none,
          diplomaStatus: VerificationStatus.none,
          subjectCount: 0,
          levelCount: 0,
          experienceCount: 0,
          hasAvailability: false,
          certificationCount: 0,
        ),
      );

      expect(completion.rate, 0);
      expect(completion.isComplete, isFalse);
      expect(completion.nextStep, isNotNull);
    });

    test('un profil complet atteint 100 %', () {
      final completion = ProfileCompletionCalculator.compute(
        const CompletionInput(
          hasPersonalInfo: true,
          hasPhoto: true,
          identityStatus: VerificationStatus.verified,
          diplomaStatus: VerificationStatus.verified,
          subjectCount: 2,
          levelCount: 3,
          experienceCount: 1,
          hasAvailability: true,
          certificationCount: 1,
        ),
      );

      expect(completion.rate, 100);
      expect(completion.isComplete, isTrue);
      expect(completion.remaining, isEmpty);
    });

    test('propose en priorite l’etape la plus lourde', () {
      final completion = ProfileCompletionCalculator.compute(
        const CompletionInput(
          hasPersonalInfo: true,
          hasPhoto: true,
          identityStatus: VerificationStatus.none,
          diplomaStatus: VerificationStatus.none,
          subjectCount: 1,
          levelCount: 1,
          experienceCount: 1,
          hasAvailability: true,
          certificationCount: 0,
        ),
      );

      // Identite et diplome pesent 20 chacun, la certification 15.
      expect(completion.nextStep!.weight, 20);
    });
  });

  group('Trust score et badges (§14, §62)', () {
    test('agrege les dimensions verifiables', () {
      const input = TrustInput(
        identityStatus: VerificationStatus.verified,
        diplomaStatus: VerificationStatus.verified,
        certifications: {'sub_math:lvl_l1': 91},
        verifiedExperienceCount: 2,
        yearsExperience: 5,
        reviewAverage: 92,
        reviewCount: 4,
        completedRecruitments: 3,
      );

      final score = TrustScoreCalculator.compute(input);
      expect(score.value, greaterThan(85));
      expect(score.dimensions, hasLength(6));

      final badges = TrustScoreCalculator.badges(input);
      expect(badges, contains(TrustBadge.identity));
      expect(badges, contains(TrustBadge.competency));
      // Identite + diplome + competence entrainent « Profil verifie ».
      expect(badges, contains(TrustBadge.profile));
    });

    test('sans verification, aucun badge n’est attribue', () {
      const input = TrustInput(
        identityStatus: VerificationStatus.pending,
        diplomaStatus: VerificationStatus.none,
        certifications: {},
        verifiedExperienceCount: 0,
        yearsExperience: 0,
        reviewAverage: null,
        reviewCount: 0,
        completedRecruitments: 0,
      );

      expect(TrustScoreCalculator.compute(input).value, 0);
      expect(TrustScoreCalculator.badges(input), isEmpty);
    });
  });

  group('Protection contre le contournement (§30)', () {
    test('masque numeros, emails et liens avant recrutement', () {
      final result = ContactMasker.mask(
        'Appelez-moi au 620 12 34 56 ou ecrivez a jean@example.com',
        unlocked: false,
      );

      expect(result.masked, isTrue);
      expect(result.text, isNot(contains('620')));
      expect(result.text, isNot(contains('example.com')));
    });

    test('laisse le texte intact une fois le recrutement conclu', () {
      const original = 'Mon numero est le 620 12 34 56';
      final result = ContactMasker.mask(original, unlocked: true);

      expect(result.masked, isFalse);
      expect(result.text, original);
    });

    test('detecte les messageries externes', () {
      expect(
        ContactMasker.containsContactDetails('On continue sur WhatsApp ?'),
        isTrue,
      );
      expect(
        ContactMasker.containsContactDetails('Bonjour, quand puis-je venir ?'),
        isFalse,
      );
    });
  });

  group('Validation des saisies', () {
    test('accepte un numero guineen et le normalise', () {
      expect(Validators.phone('620 00 00 00'), isNull);
      expect(Validators.phone('+224620000000'), isNull);
      expect(Validators.normalizePhone('620 00 00 00'), '+224620000000');
    });

    test('rejette un numero de mauvaise longueur', () {
      expect(Validators.phone('123'), isNotNull);
    });

    test('exige un mot de passe suffisant', () {
      expect(Validators.password('court1'), isNotNull);
      expect(Validators.password('motdepasse'), isNotNull);
      expect(Validators.password('motdepasse1'), isNull);
    });
  });

  group('Formatage', () {
    test('formate le chronometre du test', () {
      expect(Fmt.clock(2730), '45:30');
      expect(Fmt.clock(3930), '1:05:30');
      expect(Fmt.clock(0), '00:00');
    });

    test('masque partiellement un numero', () {
      final masked = ContactMasker.maskPhone('+224620000107');
      expect(masked, contains('07'));
      expect(masked, isNot(contains('620000107')));
    });
  });
}
