import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';

/// Dimension du Trust Score, conservée pour rester explicable (§62).
class TrustDimension {
  const TrustDimension({
    required this.key,
    required this.label,
    required this.earned,
    required this.max,
    required this.detail,
  });

  final String key;
  final String label;
  final int earned;
  final int max;
  final String detail;

  bool get complete => earned >= max;
}

/// Indicateur central de confiance (§62).
///
/// Il ne s'agit pas d'une note arbitraire mais de l'agregation d'éléments
/// verifiables permettant a l'établissement de decider.
class TrustScore {
  const TrustScore({required this.value, required this.dimensions});

  final int value;
  final List<TrustDimension> dimensions;

  List<TrustDimension> get missing =>
      dimensions.where((d) => !d.complete).toList(growable: false);

  /// Qualification textuelle, sans survendre le score.
  String get label => switch (value) {
    >= 85 => 'Profil très complet',
    >= 65 => 'Profil solide',
    >= 40 => 'Profil partiellement vérifié',
    _ => 'Profil a completer',
  };
}

class TrustInput {
  const TrustInput({
    required this.identityStatus,
    required this.diplomaStatus,
    required this.certifications,
    required this.verifiedExperienceCount,
    required this.yearsExperience,
    required this.reviewAverage,
    required this.reviewCount,
    required this.completedRecruitments,
  });

  final VerificationStatus identityStatus;
  final VerificationStatus diplomaStatus;

  /// Scores de certification par couple « matière:niveau ».
  final Map<String, int> certifications;
  final int verifiedExperienceCount;
  final int yearsExperience;

  /// Moyenne de satisfaction sur 100, ou `null` en l'absence d'évaluation.
  final double? reviewAverage;
  final int reviewCount;
  final int completedRecruitments;
}

abstract final class TrustScoreCalculator {
  static TrustScore compute(TrustInput input) {
    final w = AppConstants.trustWeights;

    final identity = input.identityStatus.isVerified ? w['identity']! : 0;
    final diploma = input.diplomaStatus.isVerified ? w['diploma']! : 0;

    // Compétence : meilleur score obtenu, ramene au poids de la dimension.
    final best = input.certifications.values.isEmpty
        ? 0
        : input.certifications.values.reduce((a, b) => a > b ? a : b);
    final competency = (w['competency']! * best / 100).round();

    // Expérience : une experience vérifiée vaut davantage qu'une declaration.
    final experienceRatio = input.verifiedExperienceCount > 0
        ? (input.yearsExperience / 5).clamp(0.0, 1.0)
        : (input.yearsExperience / 10).clamp(0.0, 0.5);
    final experience = (w['experience']! * experienceRatio).round();

    final reputation = input.reviewAverage == null
        ? 0
        : (w['reputation']! * (input.reviewAverage! / 100)).round();

    final history =
        (w['history']! * (input.completedRecruitments / 3).clamp(0.0, 1.0))
            .round();

    final dimensions = <TrustDimension>[
      TrustDimension(
        key: 'identity',
        label: 'Identité',
        earned: identity,
        max: w['identity']!,
        detail: input.identityStatus.isVerified
            ? 'Identité vérifiée'
            : input.identityStatus.label,
      ),
      TrustDimension(
        key: 'diploma',
        label: 'Diplôme',
        earned: diploma,
        max: w['diploma']!,
        detail: input.diplomaStatus.isVerified
            ? 'Diplôme vérifié'
            : input.diplomaStatus.label,
      ),
      TrustDimension(
        key: 'competency',
        label: 'Compétence',
        earned: competency,
        max: w['competency']!,
        detail: best == 0
            ? 'Aucune compétence évaluée'
            : '${input.certifications.length} certification(s), meilleur score $best %',
      ),
      TrustDimension(
        key: 'experience',
        label: 'Expérience',
        earned: experience,
        max: w['experience']!,
        detail: input.verifiedExperienceCount > 0
            ? '${input.yearsExperience} an(s), ${input.verifiedExperienceCount} experience(s) vérifiée(s)'
            : '${input.yearsExperience} an(s) declare(s)',
      ),
      TrustDimension(
        key: 'reputation',
        label: 'Reputation',
        earned: reputation,
        max: w['reputation']!,
        detail: input.reviewAverage == null
            ? 'Aucune évaluation'
            : '${input.reviewAverage!.round()} % de satisfaction sur ${input.reviewCount} évaluation(s)',
      ),
      TrustDimension(
        key: 'history',
        label: 'Historique',
        earned: history,
        max: w['history']!,
        detail: input.completedRecruitments == 0
            ? 'Aucun recrutement via la plateforme'
            : '${input.completedRecruitments} recrutement(s) via la plateforme',
      ),
    ];

    final total = dimensions.fold<int>(0, (sum, d) => sum + d.earned);
    return TrustScore(value: total.clamp(0, 100), dimensions: dimensions);
  }

  /// Badges de confiance affiches sur le profil (§14).
  static Set<TrustBadge> badges(TrustInput input) {
    final badges = <TrustBadge>{};
    if (input.identityStatus.isVerified) badges.add(TrustBadge.identity);
    if (input.diplomaStatus.isVerified) badges.add(TrustBadge.diploma);
    if (input.certifications.isNotEmpty) badges.add(TrustBadge.competency);
    if (input.verifiedExperienceCount > 0) badges.add(TrustBadge.experience);

    // Le badge « Profil vérifié » agrege les controles principaux (§14).
    if (badges.contains(TrustBadge.identity) &&
        badges.contains(TrustBadge.diploma) &&
        badges.contains(TrustBadge.competency)) {
      badges.add(TrustBadge.profile);
    }
    return badges;
  }
}
