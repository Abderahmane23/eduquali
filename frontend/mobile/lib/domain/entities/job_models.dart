import '../../core/constants/app_enums.dart';
import '../usecases/matching_engine.dart';
import 'teacher_profile.dart';

/// Établissement, tel qu'affiche dans une offre ou un espace de recrutement.
class InstitutionSummary {
  const InstitutionSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    this.logoPath,
    this.description,
    this.address,
    this.managerName,
    this.verificationStatus = VerificationStatus.pending,
    this.phone,
    this.phoneAlt,
    this.email,
    this.website,
    this.foundedYear,
    this.ownership,
    this.academicSystem,
    this.degrees = const [],
    this.specialties = const [],
    this.facilities = const [],
  });

  final String id;
  final String name;
  final InstitutionType type;
  final String city;
  final String? logoPath;
  final String? description;
  final String? address;
  final String? managerName;
  final VerificationStatus verificationStatus;

  // --- Fiche detaillee (§19) ---------------------------------------------
  final String? phone;

  /// Second numero : les etablissements en publient souvent deux.
  final String? phoneAlt;
  final String? email;
  final String? website;
  final int? foundedYear;

  /// PUBLIC ou PRIVATE.
  final String? ownership;

  /// Systeme d'etudes : « LMD » pour le superieur.
  final String? academicSystem;

  /// Diplomes delivres : BTS, LICENCE, MASTER, DOCTORAT...
  final List<String> degrees;
  final List<String> specialties;
  final List<String> facilities;

  bool get isVerified => verificationStatus.isVerified;

  /// Libelle court : « Privée · depuis 2007 ».
  String? get originLine {
    final parts = <String>[
      if (ownership == 'PRIVATE')
        'Privée'
      else if (ownership == 'PUBLIC')
        'Publique',
      if (foundedYear != null) 'depuis $foundedYear',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Les listes sont stockees en chaines separees par des virgules : une
  /// table par filiere ne se justifie pas pour une donnee d'affichage.
  static List<String> splitList(String? raw) => raw == null || raw.isEmpty
      ? const []
      : [
          for (final part in raw.split(','))
            if (part.trim().isNotEmpty) part.trim(),
        ];
}

/// Offre d'emploi (§17, §29).
class JobOffer {
  const JobOffer({
    required this.id,
    required this.institution,
    required this.title,
    required this.subject,
    required this.levels,
    required this.city,
    required this.contractType,
    required this.visibility,
    required this.status,
    required this.publishedAt,
    this.description,
    this.salaryMin,
    this.salaryMax,
    this.salaryPublished = false,
    this.minExperience = 0,
    this.requiresCertification = false,
    this.startDate,
    this.closesAt,
    this.applicationCount = 0,
    this.matchScore,
    this.hasApplied = false,
  });

  final String id;
  final InstitutionSummary institution;
  final String title;
  final RefItem subject;
  final List<RefItem> levels;
  final String city;
  final ContractType contractType;
  final JobVisibility visibility;
  final JobStatus status;
  final DateTime publishedAt;
  final String? description;
  final int? salaryMin;
  final int? salaryMax;
  final bool salaryPublished;
  final int minExperience;
  final bool requiresCertification;
  final DateTime? startDate;
  final DateTime? closesAt;
  final int applicationCount;

  /// Compatibilite calculee pour l'enseignant courant (§61).
  final MatchScore? matchScore;
  final bool hasApplied;

  bool get isPrivate => visibility == JobVisibility.private;

  /// « L2 - L3 »
  String get levelLabel => levels.map((l) => l.name).join(' - ');

  bool get isOpen =>
      status == JobStatus.published &&
      (closesAt == null || closesAt!.isAfter(DateTime.now()));

  /// Besoin exprime par l'offre, utilise par le moteur de matching.
  MatchRequirement get requirement => MatchRequirement(
    subjectId: subject.id,
    levelIds: levels.map((l) => l.id).toList(growable: false),
    city: city,
    minExperience: minExperience,
    requiresCertification: requiresCertification,
    contractType: contractType,
    institutionType: institution.type,
  );
}

/// Candidature vue par l'enseignant (§18).
class ApplicationItem {
  const ApplicationItem({
    required this.id,
    required this.job,
    required this.status,
    required this.appliedAt,
    required this.statusChangedAt,
    this.coverNote,
    this.matchScore,
    this.roomId,
  });

  final String id;
  final JobOffer job;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime statusChangedAt;
  final String? coverNote;
  final int? matchScore;
  final String? roomId;

  bool get isActive => !status.isClosed && status != ApplicationStatus.hired;
}

/// Candidat classe, cote établissement (§22).
class RankedCandidate {
  const RankedCandidate({
    required this.profile,
    required this.match,
    this.applicationId,
    this.applicationStatus,
    this.shortlisted = false,
  });

  final TeacherProfile profile;
  final MatchScore match;
  final String? applicationId;
  final ApplicationStatus? applicationStatus;
  final bool shortlisted;

  bool get hasApplied => applicationId != null;
}

/// Critères de recherche d'enseignants (§21).
class TeacherSearchFilters {
  const TeacherSearchFilters({
    this.subjectId,
    this.levelId,
    this.city,
    this.availability,
    this.minScore,
    this.minExperience,
    this.certifiedOnly = false,
    this.identityVerifiedOnly = false,
    this.diplomaVerifiedOnly = false,
    this.institutionType,
    this.contractType,
    this.query,
  });

  final String? subjectId;
  final String? levelId;
  final String? city;
  final Availability? availability;
  final int? minScore;
  final int? minExperience;
  final bool certifiedOnly;
  final bool identityVerifiedOnly;
  final bool diplomaVerifiedOnly;
  final InstitutionType? institutionType;
  final ContractType? contractType;
  final String? query;

  bool get isEmpty =>
      subjectId == null &&
      levelId == null &&
      city == null &&
      availability == null &&
      minScore == null &&
      minExperience == null &&
      !certifiedOnly &&
      !identityVerifiedOnly &&
      !diplomaVerifiedOnly &&
      institutionType == null &&
      contractType == null &&
      (query == null || query!.isEmpty);

  /// Nombre de filtres actifs, affiche sur le bouton de filtrage.
  int get activeCount {
    var count = 0;
    if (subjectId != null) count++;
    if (levelId != null) count++;
    if (city != null) count++;
    if (availability != null) count++;
    if (minScore != null) count++;
    if (minExperience != null) count++;
    if (certifiedOnly) count++;
    if (identityVerifiedOnly) count++;
    if (diplomaVerifiedOnly) count++;
    if (institutionType != null) count++;
    if (contractType != null) count++;
    return count;
  }

  TeacherSearchFilters copyWith({
    String? subjectId,
    String? levelId,
    String? city,
    Availability? availability,
    int? minScore,
    int? minExperience,
    bool? certifiedOnly,
    bool? identityVerifiedOnly,
    bool? diplomaVerifiedOnly,
    InstitutionType? institutionType,
    ContractType? contractType,
    String? query,
    bool clearSubject = false,
    bool clearLevel = false,
    bool clearCity = false,
    bool clearAvailability = false,
    bool clearMinScore = false,
    bool clearMinExperience = false,
    bool clearInstitutionType = false,
    bool clearContractType = false,
  }) => TeacherSearchFilters(
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    levelId: clearLevel ? null : (levelId ?? this.levelId),
    city: clearCity ? null : (city ?? this.city),
    availability: clearAvailability
        ? null
        : (availability ?? this.availability),
    minScore: clearMinScore ? null : (minScore ?? this.minScore),
    minExperience: clearMinExperience
        ? null
        : (minExperience ?? this.minExperience),
    certifiedOnly: certifiedOnly ?? this.certifiedOnly,
    identityVerifiedOnly: identityVerifiedOnly ?? this.identityVerifiedOnly,
    diplomaVerifiedOnly: diplomaVerifiedOnly ?? this.diplomaVerifiedOnly,
    institutionType: clearInstitutionType
        ? null
        : (institutionType ?? this.institutionType),
    contractType: clearContractType
        ? null
        : (contractType ?? this.contractType),
    query: query ?? this.query,
  );

  /// Besoin équivalent, pour classer les résultats par pertinence.
  MatchRequirement toRequirement() => MatchRequirement(
    subjectId: subjectId,
    levelIds: levelId == null ? const [] : [levelId!],
    city: city,
    minExperience: minExperience ?? 0,
    requiresCertification: certifiedOnly,
    contractType: contractType,
    institutionType: institutionType,
  );
}
