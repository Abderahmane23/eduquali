import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../domain/entities/job_models.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/usecases/matching_engine.dart';
import '../../domain/usecases/offer_visibility.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';
import 'teacher_repository.dart';

/// Offres, candidatures et recherche d'enseignants (§17, §18, §21, §22).
class JobRepository {
  JobRepository(this._db, this._sync, this._teachers);

  final AppDatabase _db;
  final SyncEngine _sync;
  final TeacherRepository _teachers;
  static const _uuid = Uuid();

  // --- Cote enseignant : opportunites (§17).

  /// Offres visibles par un enseignant, classées par compatibilité.
  ///
  /// Seulement celles de ses matières (voir `offersInSubjects`). Les offres
  /// privées ne sont visibles que par les enseignants invités (§29).
  Future<List<JobOffer>> opportunities({required String teacherId}) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT j.*, i.name AS inst_name, i.type AS inst_type,
                 i.city AS inst_city, i.logo_path AS inst_logo,
                 i.verification_status AS inst_status,
                 i.description AS inst_description, i.address AS inst_address,
                 i.manager_name AS inst_manager,
                 s.name AS subject_name, s.code AS subject_code,
                 a.id AS application_id,
                 (SELECT COUNT(*) FROM applications WHERE job_id = j.id)
                   AS application_count
          FROM jobs j
          JOIN institutions i ON i.id = j.institution_id
          JOIN subjects s ON s.id = j.subject_id
          LEFT JOIN applications a
            ON a.job_id = j.id AND a.teacher_id = ?1
          WHERE j.status = 'PUBLISHED'
            AND (j.closes_at IS NULL OR j.closes_at > ?2)
            AND (
              j.visibility = 'PUBLIC'
              OR EXISTS (SELECT 1 FROM job_invitations
                          WHERE job_id = j.id AND teacher_id = ?1)
            )
          ORDER BY j.published_at DESC
          ''',
          variables: [
            Variable<String>(teacherId),
            Variable<DateTime>(DateTime.now()),
          ],
          readsFrom: {
            _db.jobs,
            _db.institutions,
            _db.subjects,
            _db.applications,
            _db.jobInvitations,
          },
        )
        .get();

    final levelLookup = await _levelLookup();
    final candidate = await _candidateFor(teacherId);

    final inSubjects = offersInSubjects(
      [for (final row in rows) _mapJob(row, levelLookup)],
      teacherSubjectIds: {...?candidate?.subjectIds},
      subjectOf: (offer) => offer.subject.id,
    );

    final offers = <JobOffer>[];
    for (final offer in inSubjects) {
      offers.add(
        candidate == null
            ? offer
            : _withMatch(
                offer,
                MatchingEngine.score(offer.requirement, candidate),
              ),
      );
    }

    // Sans profil exploitable, on conserve l'ordre chronologique.
    if (candidate != null) {
      offers.sort((a, b) {
        final byScore = (b.matchScore?.value ?? 0).compareTo(
          a.matchScore?.value ?? 0,
        );
        return byScore != 0 ? byScore : b.publishedAt.compareTo(a.publishedAt);
      });
    }
    return offers;
  }

  Future<JobOffer?> job(String jobId, {String? teacherId}) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT j.*, i.name AS inst_name, i.type AS inst_type,
                 i.city AS inst_city, i.logo_path AS inst_logo,
                 i.verification_status AS inst_status,
                 i.description AS inst_description, i.address AS inst_address,
                 i.manager_name AS inst_manager,
                 s.name AS subject_name, s.code AS subject_code,
                 a.id AS application_id,
                 (SELECT COUNT(*) FROM applications WHERE job_id = j.id)
                   AS application_count
          FROM jobs j
          JOIN institutions i ON i.id = j.institution_id
          JOIN subjects s ON s.id = j.subject_id
          LEFT JOIN applications a ON a.job_id = j.id AND a.teacher_id = ?2
          WHERE j.id = ?1
          ''',
          variables: [
            Variable<String>(jobId),
            Variable<String>(teacherId ?? ''),
          ],
          readsFrom: {
            _db.jobs,
            _db.institutions,
            _db.subjects,
            _db.applications,
          },
        )
        .get();

    if (rows.isEmpty) return null;
    final offer = _mapJob(rows.first, await _levelLookup());
    if (teacherId == null) return offer;

    final candidate = await _candidateFor(teacherId);
    return candidate == null
        ? offer
        : _withMatch(offer, MatchingEngine.score(offer.requirement, candidate));
  }

  // --- Candidatures (§18).

  Future<String> apply({
    required String jobId,
    required String teacherId,
    String? coverNote,
  }) async {
    final existing =
        await (_db.select(_db.applications)..where(
              (t) => t.jobId.equals(jobId) & t.teacherId.equals(teacherId),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final offer = await job(jobId, teacherId: teacherId);
    final id = _uuid.v4();

    await _db
        .into(_db.applications)
        .insert(
          ApplicationsCompanion.insert(
            id: id,
            jobId: jobId,
            teacherId: teacherId,
            status: Value(ApplicationStatus.sent.code),
            coverNote: Value(coverNote),
            // Le score est fige a la candidature pour rester explicable (§22).
            matchScore: Value(offer?.matchScore?.value),
            matchFactorsJson: Value(
              offer?.matchScore == null
                  ? null
                  : jsonEncode(offer!.matchScore!.toJson()),
            ),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'application',
      entityId: id,
      operation: SyncOperation.create,
      // `cover_note` est le nom de la colonne ; `note` était listé côté
      // serveur et n'existe pas.
      payload: {
        'job_id': jobId,
        'teacher_id': teacherId,
        'cover_note': coverNote,
      },
    );
    return id;
  }

  Future<void> withdraw(String applicationId) async {
    await _setApplicationStatus(applicationId, ApplicationStatus.withdrawn);
  }

  Future<void> _setApplicationStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    await (_db.update(
      _db.applications,
    )..where((t) => t.id.equals(applicationId))).write(
      ApplicationsCompanion(
        status: Value(status.code),
        statusChangedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'application',
      entityId: applicationId,
      operation: SyncOperation.update,
      payload: {'status': status.code},
    );
  }

  /// Candidatures d'un enseignant (§18).
  Stream<List<ApplicationItem>> watchApplications(String teacherId) {
    return _db
        .customSelect(
          '''
          SELECT a.*, r.id AS room_id
          FROM applications a
          LEFT JOIN recruitment_rooms r ON r.application_id = a.id
          WHERE a.teacher_id = ?1
          ORDER BY a.applied_at DESC
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {_db.applications, _db.recruitmentRooms},
        )
        .watch()
        .asyncMap((rows) async {
          final levelLookup = await _levelLookup();
          final items = <ApplicationItem>[];
          for (final row in rows) {
            final offer = await _jobById(
              row.read<String>('job_id'),
              levelLookup,
            );
            if (offer == null) continue;
            items.add(
              ApplicationItem(
                id: row.read<String>('id'),
                job: offer,
                status: ApplicationStatus.fromCode(row.read<String>('status')),
                appliedAt: row.read<DateTime>('applied_at'),
                statusChangedAt: row.read<DateTime>('status_changed_at'),
                coverNote: row.read<String?>('cover_note'),
                matchScore: row.read<int?>('match_score'),
                roomId: row.read<String?>('room_id'),
              ),
            );
          }
          return items;
        });
  }

  // --- Cote établissement : publication et recherche.

  Future<String> publishJob({
    required String institutionId,
    required String title,
    required String subjectId,
    required List<String> levelIds,
    required String city,
    required ContractType contractType,
    required JobVisibility visibility,
    String? description,
    int? salaryMin,
    int? salaryMax,
    bool salaryPublished = false,
    int minExperience = 0,
    bool requiresCertification = false,
    DateTime? startDate,
    DateTime? closesAt,
    List<String> invitedTeacherIds = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db
          .into(_db.jobs)
          .insert(
            JobsCompanion.insert(
              id: id,
              institutionId: institutionId,
              title: title,
              subjectId: subjectId,
              levelIds: Value(levelIds.join(',')),
              city: city,
              contractType: contractType.code,
              description: Value(description),
              salaryMin: Value(salaryMin),
              salaryMax: Value(salaryMax),
              salaryPublished: Value(salaryPublished),
              minExperience: Value(minExperience),
              requiresCertification: Value(requiresCertification),
              visibility: Value(visibility.code),
              status: Value(JobStatus.published.code),
              publishedAt: Value(now),
              startDate: Value(startDate),
              closesAt: Value(closesAt),
              dirty: const Value(true),
            ),
          );

      // Offre privee : seuls les enseignants invites y ont acces (§29).
      if (invitedTeacherIds.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.jobInvitations, [
            for (final teacherId in invitedTeacherIds)
              JobInvitationsCompanion.insert(
                id: _uuid.v4(),
                jobId: id,
                teacherId: teacherId,
                dirty: const Value(true),
              ),
          ], mode: InsertMode.insertOrReplace);
        });
      }
    });

    await _sync.enqueue(
      entity: 'job',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'institutionId': institutionId,
        'title': title,
        'subjectId': subjectId,
        'levelIds': levelIds,
        'city': city,
        'contractType': contractType.code,
        'visibility': visibility.code,
        'invitedTeacherIds': invitedTeacherIds,
      },
    );
    return id;
  }

  Future<void> setJobStatus(String jobId, JobStatus status) async {
    await (_db.update(_db.jobs)..where((t) => t.id.equals(jobId))).write(
      JobsCompanion(
        status: Value(status.code),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'job',
      entityId: jobId,
      operation: SyncOperation.update,
      payload: {'status': status.code},
    );
  }

  /// Offres d'un établissement, avec le nombre de candidatures (§20).
  Stream<List<JobOffer>> watchInstitutionJobs(String institutionId) {
    return _db
        .customSelect(
          '''
          SELECT j.*, i.name AS inst_name, i.type AS inst_type,
                 i.city AS inst_city, i.logo_path AS inst_logo,
                 i.verification_status AS inst_status,
                 i.description AS inst_description, i.address AS inst_address,
                 i.manager_name AS inst_manager,
                 s.name AS subject_name, s.code AS subject_code,
                 NULL AS application_id,
                 (SELECT COUNT(*) FROM applications WHERE job_id = j.id)
                   AS application_count
          FROM jobs j
          JOIN institutions i ON i.id = j.institution_id
          JOIN subjects s ON s.id = j.subject_id
          WHERE j.institution_id = ?1
          ORDER BY j.published_at DESC, j.created_at DESC
          ''',
          variables: [Variable<String>(institutionId)],
          readsFrom: {
            _db.jobs,
            _db.institutions,
            _db.subjects,
            _db.applications,
          },
        )
        .watch()
        .asyncMap((rows) async {
          final levelLookup = await _levelLookup();
          return [for (final row in rows) _mapJob(row, levelLookup)];
        });
  }

  /// Recherche d'enseignants dans la base (§21) avec classement (§22).
  Future<List<RankedCandidate>> searchTeachers(
    TeacherSearchFilters filters, {
    String? jobId,
  }) async {
    final conditions = <String>[];
    final variables = <Variable>[];

    if (filters.subjectId != null) {
      conditions.add(
        'EXISTS (SELECT 1 FROM teacher_subjects ts '
        'WHERE ts.teacher_id = t.id AND ts.subject_id = ?${variables.length + 1})',
      );
      variables.add(Variable<String>(filters.subjectId!));
    }
    if (filters.levelId != null) {
      conditions.add(
        'EXISTS (SELECT 1 FROM teacher_levels tl '
        'WHERE tl.teacher_id = t.id AND tl.level_id = ?${variables.length + 1})',
      );
      variables.add(Variable<String>(filters.levelId!));
    }
    if (filters.city != null) {
      conditions.add('t.city = ?${variables.length + 1}');
      variables.add(Variable<String>(filters.city!));
    }
    if (filters.availability != null) {
      conditions.add('t.availability = ?${variables.length + 1}');
      variables.add(Variable<String>(filters.availability!.code));
    }
    if (filters.minExperience != null) {
      conditions.add('t.years_experience >= ?${variables.length + 1}');
      variables.add(Variable<int>(filters.minExperience!));
    }
    if (filters.identityVerifiedOnly) {
      conditions.add("t.identity_status = 'VERIFIED'");
    }
    if (filters.diplomaVerifiedOnly) {
      conditions.add("t.diploma_status = 'VERIFIED'");
    }
    if (filters.certifiedOnly || filters.minScore != null) {
      final scoreClause = filters.minScore == null
          ? ''
          : ' AND tc.score >= ?${variables.length + 1}';
      conditions.add(
        'EXISTS (SELECT 1 FROM teacher_certifications tc '
        'WHERE tc.teacher_id = t.id$scoreClause)',
      );
      if (filters.minScore != null) {
        variables.add(Variable<int>(filters.minScore!));
      }
    }
    if (filters.institutionType != null) {
      conditions.add(
        "t.preferred_institution_types LIKE ?${variables.length + 1}",
      );
      variables.add(Variable<String>('%${filters.institutionType!.code}%'));
    }
    if (filters.query != null && filters.query!.trim().isNotEmpty) {
      conditions.add(
        '(u.first_name LIKE ?${variables.length + 1} '
        'OR u.last_name LIKE ?${variables.length + 1} '
        'OR t.headline LIKE ?${variables.length + 1})',
      );
      variables.add(Variable<String>('%${filters.query!.trim()}%'));
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await _db
        .customSelect(
          'SELECT t.id AS teacher_id FROM teachers t '
          'JOIN users u ON u.id = t.user_id $where '
          // Visibilité+ remonte le profil a pertinence comparable (§35).
          'ORDER BY (t.boosted_until IS NOT NULL AND t.boosted_until > ?${variables.length + 1}) DESC',
          variables: [...variables, Variable<DateTime>(DateTime.now())],
          readsFrom: {
            _db.teachers,
            _db.users,
            _db.teacherSubjects,
            _db.teacherLevels,
            _db.teacherCertifications,
          },
        )
        .get();

    final requirement = filters.toRequirement();
    final results = <RankedCandidate>[];

    for (final row in rows) {
      final teacherId = row.read<String>('teacher_id');
      final profile = await _teachers.profile(teacherId);
      if (profile == null) continue;

      final application = jobId == null
          ? null
          : await (_db.select(_db.applications)..where(
                  (t) => t.jobId.equals(jobId) & t.teacherId.equals(teacherId),
                ))
                .getSingleOrNull();

      results.add(
        RankedCandidate(
          profile: profile,
          match: MatchingEngine.score(requirement, _toCandidate(profile)),
          applicationId: application?.id,
          applicationStatus: application == null
              ? null
              : ApplicationStatus.fromCode(application.status),
          shortlisted: application?.shortlisted ?? false,
        ),
      );
    }

    results.sort((a, b) => b.match.value.compareTo(a.match.value));
    return results;
  }

  /// Candidatures reçues sur une offre, classees par pertinence (§22).
  Future<List<RankedCandidate>> applicantsFor(String jobId) async {
    final offer = await job(jobId);
    if (offer == null) return const [];

    final rows =
        await (_db.select(_db.applications)
              ..where((t) => t.jobId.equals(jobId))
              ..orderBy([(t) => OrderingTerm.desc(t.appliedAt)]))
            .get();

    final results = <RankedCandidate>[];
    for (final application in rows) {
      final profile = await _teachers.profile(application.teacherId);
      if (profile == null) continue;
      results.add(
        RankedCandidate(
          profile: profile,
          match: MatchingEngine.score(offer.requirement, _toCandidate(profile)),
          applicationId: application.id,
          applicationStatus: ApplicationStatus.fromCode(application.status),
          shortlisted: application.shortlisted,
        ),
      );
    }

    results.sort((a, b) => b.match.value.compareTo(a.match.value));
    return results;
  }

  Future<void> markApplicationViewed(String applicationId) async {
    final row = await (_db.select(
      _db.applications,
    )..where((t) => t.id.equals(applicationId))).getSingleOrNull();
    if (row == null) return;
    if (ApplicationStatus.fromCode(row.status) != ApplicationStatus.sent) {
      return;
    }
    await _setApplicationStatus(applicationId, ApplicationStatus.viewed);
  }

  Future<void> setShortlisted(String applicationId, bool shortlisted) async {
    await (_db.update(
      _db.applications,
    )..where((t) => t.id.equals(applicationId))).write(
      ApplicationsCompanion(
        shortlisted: Value(shortlisted),
        status: Value(
          shortlisted
              ? ApplicationStatus.shortlisted.code
              : ApplicationStatus.viewed.code,
        ),
        statusChangedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'application',
      entityId: applicationId,
      operation: SyncOperation.update,
      payload: {'shortlisted': shortlisted},
    );
  }

  Future<void> rejectApplication(String applicationId) =>
      _setApplicationStatus(applicationId, ApplicationStatus.rejected);

  // --- Helpers.

  Future<JobOffer?> _jobById(
    String jobId,
    Map<String, RefItem> levelLookup,
  ) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT j.*, i.name AS inst_name, i.type AS inst_type,
                 i.city AS inst_city, i.logo_path AS inst_logo,
                 i.verification_status AS inst_status,
                 i.description AS inst_description, i.address AS inst_address,
                 i.manager_name AS inst_manager,
                 s.name AS subject_name, s.code AS subject_code,
                 NULL AS application_id,
                 (SELECT COUNT(*) FROM applications WHERE job_id = j.id)
                   AS application_count
          FROM jobs j
          JOIN institutions i ON i.id = j.institution_id
          JOIN subjects s ON s.id = j.subject_id
          WHERE j.id = ?1
          ''',
          variables: [Variable<String>(jobId)],
          readsFrom: {_db.jobs, _db.institutions, _db.subjects},
        )
        .get();
    return rows.isEmpty ? null : _mapJob(rows.first, levelLookup);
  }

  Future<Map<String, RefItem>> _levelLookup() async {
    final rows = await _db.select(_db.levels).get();
    return {
      for (final r in rows) r.id: RefItem(id: r.id, name: r.name, code: r.code),
    };
  }

  JobOffer _mapJob(QueryRow row, Map<String, RefItem> levelLookup) {
    final levelIds = row
        .read<String>('level_ids')
        .split(',')
        .where((e) => e.isNotEmpty);

    return JobOffer(
      id: row.read<String>('id'),
      institution: InstitutionSummary(
        id: row.read<String>('institution_id'),
        name: row.read<String>('inst_name'),
        type: InstitutionType.fromCode(row.read<String>('inst_type')),
        city: row.read<String>('inst_city'),
        logoPath: row.read<String?>('inst_logo'),
        description: row.read<String?>('inst_description'),
        address: row.read<String?>('inst_address'),
        managerName: row.read<String?>('inst_manager'),
        verificationStatus: VerificationStatus.fromCode(
          row.read<String>('inst_status'),
        ),
      ),
      title: row.read<String>('title'),
      subject: RefItem(
        id: row.read<String>('subject_id'),
        name: row.read<String>('subject_name'),
        code: row.read<String?>('subject_code'),
      ),
      levels: [for (final id in levelIds) ?levelLookup[id]],
      city: row.read<String>('city'),
      contractType: ContractType.fromCode(row.read<String>('contract_type')),
      visibility: JobVisibility.fromCode(row.read<String>('visibility')),
      status: JobStatus.fromCode(row.read<String>('status')),
      publishedAt:
          row.read<DateTime?>('published_at') ??
          row.read<DateTime>('created_at'),
      description: row.read<String?>('description'),
      salaryMin: row.read<int?>('salary_min'),
      salaryMax: row.read<int?>('salary_max'),
      salaryPublished: row.read<bool>('salary_published'),
      minExperience: row.read<int>('min_experience'),
      requiresCertification: row.read<bool>('requires_certification'),
      startDate: row.read<DateTime?>('start_date'),
      closesAt: row.read<DateTime?>('closes_at'),
      applicationCount: row.read<int>('application_count'),
      hasApplied: row.read<String?>('application_id') != null,
    );
  }

  JobOffer _withMatch(JobOffer offer, MatchScore score) => JobOffer(
    id: offer.id,
    institution: offer.institution,
    title: offer.title,
    subject: offer.subject,
    levels: offer.levels,
    city: offer.city,
    contractType: offer.contractType,
    visibility: offer.visibility,
    status: offer.status,
    publishedAt: offer.publishedAt,
    description: offer.description,
    salaryMin: offer.salaryMin,
    salaryMax: offer.salaryMax,
    salaryPublished: offer.salaryPublished,
    minExperience: offer.minExperience,
    requiresCertification: offer.requiresCertification,
    startDate: offer.startDate,
    closesAt: offer.closesAt,
    applicationCount: offer.applicationCount,
    matchScore: score,
    hasApplied: offer.hasApplied,
  );

  Future<MatchCandidate?> _candidateFor(String teacherId) async {
    final profile = await _teachers.profile(teacherId);
    return profile == null ? null : _toCandidate(profile);
  }

  MatchCandidate _toCandidate(TeacherProfile profile) => MatchCandidate(
    teacherId: profile.teacherId,
    subjectIds: [for (final c in profile.capabilities) c.subject.id],
    levelPairs: [
      for (final c in profile.capabilities)
        for (final l in c.levels) '${c.subject.id}:${l.id}',
    ],
    certifications: profile.certificationMap,
    yearsExperience: profile.yearsExperience,
    city: profile.city,
    availability: profile.availability,
    preferredInstitutionTypes: [
      for (final t in profile.preferredInstitutionTypes) t.code,
    ],
    identityVerified: profile.identityStatus.isVerified,
    diplomaVerified: profile.diplomaStatus.isVerified,
    highestDiploma: _highestDiploma(profile),
  );

  /// Le plus haut diplome declare, normalise pour le bareme du 21/09.
  ///
  /// Un professeur qui declare une licence **et** un master doit etre
  /// classe sur le master : prendre le premier de la liste dependrait de
  /// l'ordre de saisie.
  static String _highestDiploma(TeacherProfile profile) {
    const ranks = {'DOCTORAT': 3, 'MASTER': 2, 'LICENCE': 1};
    var best = '';
    var bestRank = 0;
    for (final diploma in profile.diplomas) {
      final code = diploma.diplomaType.trim().toUpperCase();
      final rank = ranks[code] ?? 0;
      if (rank > bestRank) {
        bestRank = rank;
        best = code;
      }
    }
    return best;
  }
}
