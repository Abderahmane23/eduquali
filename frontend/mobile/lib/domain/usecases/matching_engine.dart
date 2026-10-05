import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';

/// Contribution d'un critère au score global — le classement doit rester
/// explicable pour l'établissement (§22, §61).
class MatchFactor {
  const MatchFactor({
    required this.key,
    required this.label,
    required this.weight,
    required this.ratio,
    required this.detail,
  });

  final String key;
  final String label;

  /// Poids du critère dans le score final (0 a 1).
  final double weight;

  /// Satisfaction du critère (0 a 1).
  final double ratio;

  /// Explication lisible : « Mathématiques — correspond a l'offre ».
  final String detail;

  int get points => (weight * ratio * 100).round();
  int get maxPoints => (weight * 100).round();
}

/// Score de compatibilite entre un besoin et un profil (§22).
class MatchScore {
  const MatchScore({required this.value, required this.factors});

  /// Compatibilite finale de 0 a 100.
  final int value;
  final List<MatchFactor> factors;

  /// Les critères les plus penalisants, pour expliquer un score faible.
  List<MatchFactor> get weakest {
    final sorted = [...factors]..sort((a, b) => (a.ratio).compareTo(b.ratio));
    return sorted.where((f) => f.ratio < 1).toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'factors': [
      for (final f in factors)
        {
          'key': f.key,
          'label': f.label,
          'ratio': f.ratio,
          'points': f.points,
          'max': f.maxPoints,
          'detail': f.detail,
        },
    ],
  };
}

/// Besoin exprime par un établissement (offre ou recherche).
class MatchRequirement {
  const MatchRequirement({
    required this.subjectId,
    required this.levelIds,
    required this.city,
    this.minExperience = 0,
    this.requiresCertification = false,
    this.contractType,
    this.institutionType,
  });

  final String? subjectId;
  final List<String> levelIds;
  final String? city;
  final int minExperience;
  final bool requiresCertification;
  final ContractType? contractType;
  final InstitutionType? institutionType;
}

/// Profil candidat, reduit aux données utiles au matching.
class MatchCandidate {
  const MatchCandidate({
    required this.teacherId,
    required this.subjectIds,
    required this.levelPairs,
    required this.certifications,
    required this.yearsExperience,
    required this.city,
    required this.availability,
    this.preferredContractTypes = const [],
    this.preferredInstitutionTypes = const [],
    this.identityVerified = false,
    this.diplomaVerified = false,
    this.highestDiploma = '',
  });

  final String teacherId;
  final List<String> subjectIds;

  /// Couples « matière:niveau » declares par l'enseignant.
  final List<String> levelPairs;

  /// Scores obtenus par couple « matière:niveau ».
  final Map<String, int> certifications;

  final int yearsExperience;
  final String? city;
  final Availability availability;
  final List<String> preferredContractTypes;
  final List<String> preferredInstitutionTypes;
  final bool identityVerified;
  final bool diplomaVerified;

  /// Plus haut diplome declare : `DOCTORAT`, `MASTER`, `LICENCE`, ou vide.
  final String highestDiploma;

  static String pairKey(String subjectId, String levelId) =>
      '$subjectId:$levelId';
}

/// Moteur de matching (§61).
///
/// Le score combine matière, niveau, compétence évaluée, experience,
/// localisation et disponibilité. Chaque contribution est conservée afin que
/// l'établissement puisse comprendre le classement — le score ne doit pas
/// devenir une boite noire.
abstract final class MatchingEngine {
  /// Bareme du 21/09 : disponible 30, diplome 30 (master) ou 10 (licence),
  /// ville 30, experience 10.
  ///
  /// **Le score de certification ne classe plus.** La note du 21/09 ne le
  /// mentionne pas, et il pesait 25 % auparavant. Les tests de competence
  /// restent affiches sur la fiche du professeur ; ils ne departagent plus
  /// deux candidats.
  ///
  /// La matiere et le niveau ne rapportent pas de points — ce sont des
  /// conditions. Un professeur de francais ne se classe pas « un peu » sur
  /// un poste de mathematiques : il n'y a pas sa place, et son score est nul.
  static MatchScore score(MatchRequirement need, MatchCandidate candidate) {
    final p = AppConstants.matchingPoints;
    final subject = _subjectFactor(need, candidate, 0);
    final level = _levelFactor(need, candidate, 0);

    final factors = <MatchFactor>[
      subject,
      level,
      _availabilityFactor(candidate, p['availability']! / 100),
      _diplomaFactor(candidate, p['diploma']! / 100),
      _locationFactor(need, candidate, p['location']! / 100),
      _experienceFactor(need, candidate, p['experience']! / 100),
    ];

    // Condition non remplie : aucun point, et la raison reste lisible dans
    // les facteurs.
    if (subject.ratio == 0 || level.ratio == 0) {
      return MatchScore(value: 0, factors: factors);
    }

    final total = factors.fold<double>(0, (sum, f) => sum + f.weight * f.ratio);
    return MatchScore(
      value: (total * 100).round().clamp(0, 100),
      factors: factors,
    );
  }

  /// Le diplome, tel que la note du 21/09 le compte.
  static MatchFactor _diplomaFactor(MatchCandidate candidate, double weight) {
    final level = candidate.highestDiploma.trim().toUpperCase();
    final points = AppConstants.diplomaPoints[level] ?? 0;
    final best = AppConstants.diplomaPoints.values.reduce(
      (a, b) => a > b ? a : b,
    );

    return MatchFactor(
      key: 'diploma',
      label: 'Diplôme',
      weight: weight,
      ratio: best == 0 ? 0 : points / best,
      detail: points > 0
          ? '${candidate.highestDiploma} — $points points'
          : 'Aucun diplôme déclaré',
    );
  }

  static MatchFactor _subjectFactor(
    MatchRequirement need,
    MatchCandidate candidate,
    double weight,
  ) {
    if (need.subjectId == null) {
      return MatchFactor(
        key: 'subject',
        label: 'Matière',
        weight: weight,
        ratio: 1,
        detail: 'Aucune matière imposee',
      );
    }
    final match = candidate.subjectIds.contains(need.subjectId);
    return MatchFactor(
      key: 'subject',
      label: 'Matière',
      weight: weight,
      ratio: match ? 1 : 0,
      detail: match
          ? 'Matière enseignee par le candidat'
          : 'Matière non declaree par le candidat',
    );
  }

  static MatchFactor _levelFactor(
    MatchRequirement need,
    MatchCandidate candidate,
    double weight,
  ) {
    if (need.levelIds.isEmpty || need.subjectId == null) {
      return MatchFactor(
        key: 'level',
        label: 'Niveau',
        weight: weight,
        ratio: 1,
        detail: 'Aucun niveau impose',
      );
    }
    final covered = need.levelIds
        .where(
          (l) => candidate.levelPairs.contains(
            MatchCandidate.pairKey(need.subjectId!, l),
          ),
        )
        .length;
    final ratio = covered / need.levelIds.length;
    return MatchFactor(
      key: 'level',
      label: 'Niveau',
      weight: weight,
      ratio: ratio,
      detail: covered == need.levelIds.length
          ? 'Tous les niveaux demandes sont couverts'
          : '$covered niveau(x) couvert(s) sur ${need.levelIds.length}',
    );
  }

  static MatchFactor _experienceFactor(
    MatchRequirement need,
    MatchCandidate candidate,
    double weight,
  ) {
    if (need.minExperience <= 0) {
      // Sans exigence, l'experience valorise progressivement jusqu'a 5 ans.
      final ratio = (candidate.yearsExperience / 5).clamp(0.0, 1.0);
      return MatchFactor(
        key: 'experience',
        label: 'Expérience',
        weight: weight,
        ratio: ratio,
        detail: '${candidate.yearsExperience} an(s) d’experience',
      );
    }
    final ratio = (candidate.yearsExperience / need.minExperience).clamp(
      0.0,
      1.0,
    );
    return MatchFactor(
      key: 'experience',
      label: 'Expérience',
      weight: weight,
      ratio: ratio,
      detail: ratio >= 1
          ? '${candidate.yearsExperience} ans — exigence de ${need.minExperience} ans satisfaite'
          : '${candidate.yearsExperience} ans sur ${need.minExperience} ans demandes',
    );
  }

  static MatchFactor _locationFactor(
    MatchRequirement need,
    MatchCandidate candidate,
    double weight,
  ) {
    if (need.city == null || need.city!.isEmpty) {
      return MatchFactor(
        key: 'location',
        label: 'Localisation',
        weight: weight,
        ratio: 1,
        detail: 'Aucune ville imposee',
      );
    }
    final same =
        candidate.city != null &&
        candidate.city!.toLowerCase() == need.city!.toLowerCase();
    return MatchFactor(
      key: 'location',
      label: 'Localisation',
      weight: weight,
      // Une ville différente n'est pas eliminatoire : mobilité possible.
      ratio: same ? 1 : 0.3,
      detail: same
          ? 'Reside a ${need.city}'
          : 'Reside a ${candidate.city ?? "ville non renseignee"}',
    );
  }

  static MatchFactor _availabilityFactor(
    MatchCandidate candidate,
    double weight,
  ) {
    final ratio = switch (candidate.availability) {
      Availability.available => 1.0,
      Availability.availableSoon => 0.6,
      Availability.unavailable => 0.0,
    };
    return MatchFactor(
      key: 'availability',
      label: 'Disponibilité',
      weight: weight,
      ratio: ratio,
      detail: candidate.availability.label,
    );
  }
}
