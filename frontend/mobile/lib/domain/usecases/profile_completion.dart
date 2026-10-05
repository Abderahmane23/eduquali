import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';

/// Une action restante affichee sur l'écran de completion (§16).
class CompletionStep {
  const CompletionStep({
    required this.key,
    required this.label,
    required this.done,
    required this.weight,
    required this.route,
  });

  final String key;
  final String label;
  final bool done;
  final int weight;
  final String route;
}

/// Résultat du calcul de completion du profil.
class ProfileCompletion {
  const ProfileCompletion({required this.rate, required this.steps});

  /// Taux de completion, de 0 a 100.
  final int rate;
  final List<CompletionStep> steps;

  List<CompletionStep> get remaining =>
      steps.where((s) => !s.done).toList(growable: false);

  bool get isComplete => rate >= 100;

  /// Prochaine action a proposer en priorité (la plus lourde d'abord).
  CompletionStep? get nextStep {
    final pending = remaining;
    if (pending.isEmpty) return null;
    pending.sort((a, b) => b.weight.compareTo(a.weight));
    return pending.first;
  }
}

/// Entrees necessaires au calcul, indépendantes de la couche de données.
class CompletionInput {
  const CompletionInput({
    required this.hasPersonalInfo,
    required this.hasPhoto,
    required this.identityStatus,
    required this.diplomaStatus,
    required this.subjectCount,
    required this.levelCount,
    required this.experienceCount,
    required this.hasAvailability,
    required this.certificationCount,
  });

  final bool hasPersonalInfo;
  final bool hasPhoto;
  final VerificationStatus identityStatus;
  final VerificationStatus diplomaStatus;
  final int subjectCount;
  final int levelCount;
  final int experienceCount;
  final bool hasAvailability;
  final int certificationCount;
}

/// Calcule le taux de completion et les actions restantes (§16).
///
/// Les ponderations proviennent de [AppConstants.completionWeights] afin de
/// rester alignees avec le parametrage du back-office.
abstract final class ProfileCompletionCalculator {
  static ProfileCompletion compute(CompletionInput input) {
    final w = AppConstants.completionWeights;

    final steps = <CompletionStep>[
      CompletionStep(
        key: 'personal_info',
        label: 'Completer vos informations personnelles',
        done: input.hasPersonalInfo,
        weight: w['personal_info']!,
        route: '/teacher/profile/edit',
      ),
      CompletionStep(
        key: 'photo',
        label: 'Ajouter une photo de profil',
        done: input.hasPhoto,
        weight: w['photo']!,
        route: '/teacher/profile/edit',
      ),
      CompletionStep(
        key: 'identity',
        label: 'Vérifier votre identité',
        done: input.identityStatus.isVerified,
        weight: w['identity']!,
        route: '/teacher/identity',
      ),
      CompletionStep(
        key: 'diploma',
        label: 'Vérifier votre diplôme',
        done: input.diplomaStatus.isVerified,
        weight: w['diploma']!,
        route: '/teacher/diplomas',
      ),
      CompletionStep(
        key: 'subjects',
        label: 'Ajouter vos matières',
        done: input.subjectCount > 0,
        weight: w['subjects']!,
        route: '/teacher/subjects',
      ),
      CompletionStep(
        key: 'levels',
        label: 'Ajouter vos niveaux',
        done: input.levelCount > 0,
        weight: w['levels']!,
        route: '/teacher/levels',
      ),
      CompletionStep(
        key: 'experience',
        label: 'Renseigner votre experience',
        done: input.experienceCount > 0,
        weight: w['experience']!,
        route: '/teacher/experience',
      ),
      CompletionStep(
        key: 'availability',
        label: 'Indiquer votre disponibilité',
        done: input.hasAvailability,
        weight: w['availability']!,
        route: '/teacher/availability',
      ),
      CompletionStep(
        key: 'certification',
        label: 'Passer votre test de compétence',
        done: input.certificationCount > 0,
        weight: w['certification']!,
        route: '/teacher/tests',
      ),
    ];

    final earned = steps
        .where((s) => s.done)
        .fold<int>(0, (sum, s) => sum + s.weight);

    return ProfileCompletion(rate: earned.clamp(0, 100), steps: steps);
  }
}
