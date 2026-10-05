import '../../core/constants/app_enums.dart';
import '../usecases/profile_completion.dart';
import '../usecases/trust_score.dart';

/// Référence simple du referentiel (matière ou niveau).
class RefItem {
  const RefItem({
    required this.id,
    required this.name,
    this.code,
    this.category,
    this.cycles = const [],
  });

  final String id;
  final String name;
  final String? code;

  /// Pour un niveau : PRIMARY | SECONDARY | UNIVERSITY (§9).
  final String? category;

  /// Cycles concernés : `PRIMAIRE`, `COLLEGE`, `LYCEE`, `SUPERIEUR`.
  /// Un niveau n'en a qu'un ; une matière peut en couvrir plusieurs.
  final List<String> cycles;

  @override
  bool operator ==(Object other) => other is RefItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Certification par matière et niveau (§13).
class CertificationItem {
  const CertificationItem({
    required this.id,
    required this.subject,
    required this.level,
    required this.score,
    required this.issuedAt,
    this.domainScoresJson,
  });

  final String id;
  final RefItem subject;
  final RefItem level;
  final int score;
  final DateTime issuedAt;
  final String? domainScoresJson;

  /// « Mathématiques — L1 »
  String get title => '${subject.name} — ${level.name}';
}

/// Couple matière + niveau declare par l'enseignant (§8, §9).
class TeachingCapability {
  const TeachingCapability({
    required this.subject,
    required this.levels,
    required this.certifiedScores,
  });

  final RefItem subject;
  final List<RefItem> levels;

  /// Score obtenu par niveau, lorsqu'une évaluation existe.
  final Map<String, int> certifiedScores;

  bool isCertified(String levelId) => certifiedScores.containsKey(levelId);
}

/// Expérience professionnelle (§15).
class ExperienceItem {
  const ExperienceItem({
    required this.id,
    required this.institutionName,
    required this.position,
    required this.startDate,
    this.endDate,
    this.city,
    this.description,
    this.verificationStatus = VerificationStatus.none,
  });

  final String id;
  final String institutionName;
  final String position;
  final DateTime startDate;
  final DateTime? endDate;
  final String? city;
  final String? description;
  final VerificationStatus verificationStatus;

  bool get isCurrent => endDate == null;
}

/// Diplôme declare (§7).
class DiplomaItem {
  const DiplomaItem({
    required this.id,
    required this.diplomaType,
    required this.institutionName,
    required this.graduationYear,
    required this.status,
    this.field,
    this.speciality,
    this.documentId,
    this.rejectionReason,
  });

  final String id;
  final String diplomaType;
  final String institutionName;
  final int graduationYear;
  final VerificationStatus status;
  final String? field;
  final String? speciality;
  final String? documentId;
  final String? rejectionReason;
}

/// Indicateurs de reputation vérifiés (§33).
class ReputationStats {
  const ReputationStats({
    this.institutionCount = 0,
    this.yearsExperience = 0,
    this.platformRecruitments = 0,
    this.satisfaction,
    this.reviewCount = 0,
  });

  final int institutionCount;
  final int yearsExperience;
  final int platformRecruitments;

  /// Satisfaction moyenne sur 100, ou `null` si aucune évaluation.
  final double? satisfaction;
  final int reviewCount;
}

/// Profil enseignant complet (§15) — agregat utilise par l'interface.
class TeacherProfile {
  const TeacherProfile({
    required this.teacherId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.availability,
    required this.identityStatus,
    required this.diplomaStatus,
    required this.yearsExperience,
    required this.capabilities,
    required this.certifications,
    required this.experiences,
    required this.diplomas,
    required this.completion,
    required this.trust,
    required this.badges,
    required this.reputation,
    this.email,
    this.city,
    this.photoPath,
    this.headline,
    this.bio,
    this.preferredInstitutionTypes = const [],
    this.boostedUntil,
  });

  final String teacherId;
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? city;
  final String? photoPath;
  final String? headline;
  final String? bio;
  final Availability availability;
  final VerificationStatus identityStatus;
  final VerificationStatus diplomaStatus;
  final int yearsExperience;
  final List<TeachingCapability> capabilities;
  final List<CertificationItem> certifications;
  final List<ExperienceItem> experiences;
  final List<DiplomaItem> diplomas;
  final ProfileCompletion completion;
  final TrustScore trust;
  final Set<TrustBadge> badges;
  final ReputationStats reputation;
  final List<InstitutionType> preferredInstitutionTypes;
  final DateTime? boostedUntil;

  String get fullName => '$firstName $lastName'.trim();

  /// « Enseignant en Mathématiques » — deduit des matières si non renseigne.
  String get displayHeadline {
    if (headline != null && headline!.trim().isNotEmpty) return headline!;
    if (capabilities.isEmpty) return 'Enseignant';
    return 'Enseignant en ${capabilities.first.subject.name}';
  }

  bool get hasBoost =>
      boostedUntil != null && boostedUntil!.isAfter(DateTime.now());

  /// Scores de certification indexes par « matière:niveau », pour le matching.
  Map<String, int> get certificationMap => {
    for (final c in certifications) '${c.subject.id}:${c.level.id}': c.score,
  };
}
