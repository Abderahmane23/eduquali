import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/usecases/profile_completion.dart';
import '../../domain/usecases/trust_score.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Depot du profil enseignant (§15) — lecture agrégée et ecritures locales.
///
/// Toute écriture suit le principe « local first » (§41) : la base locale est
/// mise a jour immediatement, puis l'operation est empilee dans la file de
/// synchronisation (§43).
class TeacherRepository {
  TeacherRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  /// Le compte derriere une fiche professeur.
  ///
  /// Les notifications visent `users.id`, pas `teachers.id` : les deux
  /// identifiants se ressemblent et ne designent pas la meme chose. Pousser
  /// une notification sur l'identifiant de fiche l'envoie a personne, et
  /// personne ne s'en plaint — elle n'apparait simplement jamais.
  Future<String?> userIdOf(String teacherId) async {
    final row = await (_db.select(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).getSingleOrNull();
    return row?.userId;
  }

  /// Profil complet, avec completion, trust score et badges calcules.
  Future<TeacherProfile?> profile(String teacherId) async {
    final teacher = await (_db.select(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).getSingleOrNull();
    if (teacher == null) return null;

    final user = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(teacher.userId))).getSingleOrNull();
    if (user == null) return null;

    final capabilities = await _capabilities(teacherId);
    final certifications = await this.certifications(teacherId);
    final experiences = await this.experiences(teacherId);
    final diplomas = await this.diplomas(teacherId);
    final reputation = await _reputation(teacherId, teacher.yearsExperience);

    final identityStatus = VerificationStatus.fromCode(teacher.identityStatus);
    final diplomaStatus = VerificationStatus.fromCode(teacher.diplomaStatus);
    final certificationMap = {
      for (final c in certifications) '${c.subject.id}:${c.level.id}': c.score,
    };

    final completion = ProfileCompletionCalculator.compute(
      CompletionInput(
        hasPersonalInfo:
            (user.firstName?.isNotEmpty ?? false) &&
            (user.lastName?.isNotEmpty ?? false) &&
            (teacher.city?.isNotEmpty ?? false),
        hasPhoto: user.photoPath != null && user.photoPath!.isNotEmpty,
        identityStatus: identityStatus,
        diplomaStatus: diplomaStatus,
        subjectCount: capabilities.length,
        levelCount: capabilities.fold(0, (sum, c) => sum + c.levels.length),
        experienceCount: experiences.length,
        // « Indiquer votre disponibilité » était coché en dur : la barre de
        // complétion annonçait l'étape faite pour tout le monde, y compris
        // ceux qui n'avaient jamais ouvert l'écran, et la liste des actions
        // restantes ne la proposait donc jamais.
        //
        // Les créneaux à domicile ou ceux pour un poste : l'un ou l'autre
        // répond à la question, un professeur ne cherchant pas forcément les
        // deux.
        hasAvailability:
            teacher.tutoringDays.isNotEmpty ||
            teacher.tutoringHours != '{}' ||
            teacher.workHours != '{}',
        certificationCount: certifications.length,
      ),
    );

    final trustInput = TrustInput(
      identityStatus: identityStatus,
      diplomaStatus: diplomaStatus,
      certifications: certificationMap,
      verifiedExperienceCount: experiences
          .where((e) => e.verificationStatus.isVerified)
          .length,
      yearsExperience: teacher.yearsExperience,
      reviewAverage: reputation.satisfaction,
      reviewCount: reputation.reviewCount,
      completedRecruitments: reputation.platformRecruitments,
    );

    return TeacherProfile(
      teacherId: teacher.id,
      userId: user.id,
      firstName: user.firstName ?? '',
      lastName: user.lastName ?? '',
      phone: user.phone,
      email: user.email,
      city: teacher.city ?? user.city,
      photoPath: user.photoPath,
      headline: teacher.headline,
      bio: teacher.bio,
      availability: Availability.fromCode(teacher.availability),
      identityStatus: identityStatus,
      diplomaStatus: diplomaStatus,
      yearsExperience: teacher.yearsExperience,
      capabilities: capabilities,
      certifications: certifications,
      experiences: experiences,
      diplomas: diplomas,
      completion: completion,
      trust: TrustScoreCalculator.compute(trustInput),
      badges: TrustScoreCalculator.badges(trustInput),
      reputation: reputation,
      preferredInstitutionTypes: [
        for (final code in teacher.preferredInstitutionTypes.split(','))
          if (code.isNotEmpty) InstitutionType.fromCode(code),
      ],
      boostedUntil: teacher.boostedUntil,
    );
  }

  /// Flux du profil : l'interface se reactualise a chaque écriture locale.
  Stream<TeacherProfile?> watchProfile(String teacherId) {
    // Les tables ci-dessous alimentent l'agregat : toute modification de l'une
    // d'elles doit rafraichir le profil affiche.
    final trigger = _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM teacher_subjects WHERE teacher_id = ?1) '
          '+ (SELECT COUNT(*) FROM teacher_levels WHERE teacher_id = ?1) '
          '+ (SELECT COUNT(*) FROM teacher_certifications WHERE teacher_id = ?1) '
          '+ (SELECT COUNT(*) FROM teacher_experiences WHERE teacher_id = ?1) '
          '+ (SELECT COUNT(*) FROM teacher_diplomas WHERE teacher_id = ?1) '
          'AS total',
          variables: [Variable<String>(teacherId)],
          readsFrom: {
            _db.teachers,
            _db.users,
            _db.teacherSubjects,
            _db.teacherLevels,
            _db.teacherCertifications,
            _db.teacherExperiences,
            _db.teacherDiplomas,
            _db.recruitments,
            _db.teacherReviews,
          },
        )
        .watch();

    return trigger.asyncMap((_) => profile(teacherId));
  }

  /// Matières et niveaux declares, avec les scores obtenus (§8, §13).
  Future<List<TeachingCapability>> _capabilities(String teacherId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT ts.subject_id AS subject_id, s.name AS subject_name,
                 s.code AS subject_code, tl.level_id AS level_id,
                 l.name AS level_name, l.code AS level_code,
                 -- Le cycle du niveau, sans quoi `RefItem.cycles` reste vide et
                 -- tout filtre par palier retient silencieusement TOUT LE MONDE.
                 l.cycle AS level_cycle,
                 l.sort_order AS level_order, tc.score AS score
          FROM teacher_subjects ts
          JOIN subjects s ON s.id = ts.subject_id
          LEFT JOIN teacher_levels tl
            ON tl.teacher_id = ts.teacher_id AND tl.subject_id = ts.subject_id
          LEFT JOIN levels l ON l.id = tl.level_id
          LEFT JOIN teacher_certifications tc
            ON tc.teacher_id = ts.teacher_id
           AND tc.subject_id = ts.subject_id
           AND tc.level_id = tl.level_id
          WHERE ts.teacher_id = ?1
          ORDER BY s.sort_order, l.sort_order
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {
            _db.teacherSubjects,
            _db.teacherLevels,
            _db.subjects,
            _db.levels,
            _db.teacherCertifications,
          },
        )
        .get();

    final bySubject =
        <
          String,
          ({RefItem subject, List<RefItem> levels, Map<String, int> scores})
        >{};

    for (final row in rows) {
      final subjectId = row.read<String>('subject_id');
      final entry = bySubject.putIfAbsent(
        subjectId,
        () => (
          subject: RefItem(
            id: subjectId,
            name: row.read<String>('subject_name'),
            code: row.read<String?>('subject_code'),
          ),
          levels: <RefItem>[],
          scores: <String, int>{},
        ),
      );

      final levelId = row.read<String?>('level_id');
      if (levelId == null) continue;

      if (!entry.levels.any((l) => l.id == levelId)) {
        final cycle = row.read<String?>('level_cycle') ?? '';
        entry.levels.add(
          RefItem(
            id: levelId,
            name: row.read<String>('level_name'),
            code: row.read<String?>('level_code'),
            cycles: cycle.isEmpty ? const [] : [cycle],
          ),
        );
      }
      final score = row.read<int?>('score');
      if (score != null) entry.scores[levelId] = score;
    }

    return [
      for (final entry in bySubject.values)
        TeachingCapability(
          subject: entry.subject,
          levels: entry.levels,
          certifiedScores: entry.scores,
        ),
    ];
  }

  Future<List<CertificationItem>> certifications(String teacherId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT tc.*, s.name AS subject_name, s.code AS subject_code,
                 l.name AS level_name, l.code AS level_code
          FROM teacher_certifications tc
          JOIN subjects s ON s.id = tc.subject_id
          JOIN levels l ON l.id = tc.level_id
          WHERE tc.teacher_id = ?1
          ORDER BY tc.score DESC
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {_db.teacherCertifications, _db.subjects, _db.levels},
        )
        .get();

    return [
      for (final row in rows)
        CertificationItem(
          id: row.read<String>('id'),
          subject: RefItem(
            id: row.read<String>('subject_id'),
            name: row.read<String>('subject_name'),
            code: row.read<String?>('subject_code'),
          ),
          level: RefItem(
            id: row.read<String>('level_id'),
            name: row.read<String>('level_name'),
            code: row.read<String?>('level_code'),
          ),
          score: row.read<int>('score'),
          issuedAt: row.read<DateTime>('issued_at'),
          domainScoresJson: row.read<String?>('domain_scores_json'),
        ),
    ];
  }

  Future<List<ExperienceItem>> experiences(String teacherId) async {
    final rows =
        await (_db.select(_db.teacherExperiences)
              ..where((t) => t.teacherId.equals(teacherId))
              ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
            .get();

    return [
      for (final r in rows)
        ExperienceItem(
          id: r.id,
          institutionName: r.institutionName,
          position: r.position,
          startDate: r.startDate,
          endDate: r.endDate,
          city: r.city,
          description: r.description,
          verificationStatus: VerificationStatus.fromCode(r.verificationStatus),
        ),
    ];
  }

  Future<List<DiplomaItem>> diplomas(String teacherId) async {
    final rows =
        await (_db.select(_db.teacherDiplomas)
              ..where((t) => t.teacherId.equals(teacherId))
              ..orderBy([(t) => OrderingTerm.desc(t.graduationYear)]))
            .get();

    return [
      for (final r in rows)
        DiplomaItem(
          id: r.id,
          diplomaType: r.diplomaType,
          institutionName: r.institutionName,
          graduationYear: r.graduationYear,
          status: VerificationStatus.fromCode(r.verificationStatus),
          field: r.field,
          speciality: r.speciality,
          documentId: r.documentId,
          rejectionReason: r.rejectionReason,
        ),
    ];
  }

  /// Indicateurs de reputation vérifiés (§33).
  Future<ReputationStats> _reputation(String teacherId, int years) async {
    final row = await _db
        .customSelect(
          '''
          SELECT
            (SELECT COUNT(DISTINCT institution_name) FROM teacher_experiences
              WHERE teacher_id = ?1) AS institutions,
            (SELECT COUNT(*) FROM recruitments WHERE teacher_id = ?1) AS hires,
            (SELECT AVG(overall) FROM teacher_reviews WHERE teacher_id = ?1)
              AS satisfaction,
            (SELECT COUNT(*) FROM teacher_reviews WHERE teacher_id = ?1)
              AS reviews
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {
            _db.teacherExperiences,
            _db.recruitments,
            _db.teacherReviews,
          },
        )
        .getSingle();

    return ReputationStats(
      institutionCount: row.read<int>('institutions'),
      yearsExperience: years,
      platformRecruitments: row.read<int>('hires'),
      satisfaction: row.read<double?>('satisfaction'),
      reviewCount: row.read<int>('reviews'),
    );
  }

  // --- Ecritures.

  Future<void> updatePersonalInfo({
    required String teacherId,
    required String userId,
    required String firstName,
    required String lastName,
    String? email,
    String? city,
    String? headline,
    String? bio,
    String? photoPath,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(
          firstName: Value(firstName),
          lastName: Value(lastName),
          email: Value(email),
          city: Value(city),
          photoPath: photoPath == null
              ? const Value.absent()
              : Value(photoPath),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
      await (_db.update(
        _db.teachers,
      )..where((t) => t.id.equals(teacherId))).write(
        TeachersCompanion(
          city: Value(city),
          headline: Value(headline),
          bio: Value(bio),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
    });

    await _sync.enqueue(
      entity: 'teacher',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'city': city,
        'headline': headline,
        'bio': bio,
      },
    );
  }

  Future<void> setAvailability(
    String teacherId,
    Availability availability, {
    DateTime? availableFrom,
    int? yearsExperience,
  }) async {
    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        availability: Value(availability.code),
        availableFrom: Value(availableFrom),
        yearsExperience: yearsExperience == null
            ? const Value.absent()
            : Value(yearsExperience),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    await _sync.enqueue(
      entity: 'teacher',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {
        'availability': availability.code,
        'available_from': availableFrom?.toIso8601String(),
        'years_experience': ?yearsExperience,
      },
    );
  }

  /// Enregistre ce que le professeur a déclaré pendant son inscription.
  ///
  /// --- Le défaut que ceci corrige -----------------------------------------
  ///
  /// `registerTeacher` ne retenait que l'identité et l'adresse. Les sept
  /// écrans du parcours — ce qu'il cherche, à quels cycles, quelles matières,
  /// quels niveaux, quels jours, s'il peut déménager — n'étaient lus par
  /// personne : `SignupCompletion` exploitait 7 réponses sur 15.
  ///
  /// Le professeur arrivait donc sur un compte qui n'en savait rien. Sa fiche
  /// s'affichait **sans aucune matière** dans la liste des familles, et le
  /// filtre par palier laissait passer qui n'a déclaré aucun cycle : il était
  /// proposé à un élève de CE2 comme à un étudiant. Pour exister vraiment, il
  /// devait ressaisir les mêmes faits dans `/teacher/subjects`,
  /// `/teacher/levels`, puis une troisième fois dans son offre.
  ///
  /// --- Pourquoi les niveaux sont posés sur chaque matière ------------------
  ///
  /// `teacher_levels` est clé par (professeur, matière, niveau) : les niveaux
  /// s'y déclarent **par matière**. Le parcours, lui, pose les deux questions
  /// séparément — « quelles matières » puis « quels niveaux ». La lecture
  /// fidèle de ces deux réponses est donc le produit des deux : il enseigne
  /// ces matières à ces niveaux. Il affinera matière par matière depuis son
  /// profil, et cet écran existe déjà.
  Future<void> setDeclaredProfile({
    required String teacherId,
    required List<String> subjectIds,
    required List<String> levelIds,
    required List<String> serviceTypes,
    String? mobility,
    Map<String, dynamic> tutoringHours = const {},
    Map<String, dynamic> workHours = const {},
  }) async {
    if (subjectIds.isNotEmpty) {
      await setSubjects(teacherId, subjectIds);
      if (levelIds.isNotEmpty) {
        for (final subjectId in subjectIds) {
          await setLevelsForSubject(teacherId, subjectId, levelIds);
        }
      }
    }

    // Les deux colonnes à plat restent dérivées du détail par jour : l'écran
    // de disponibilité et les offres les lisent déjà, et elles répondent à
    // « quels jours » sans ouvrir le JSON.
    final jours = tutoringHours.keys.toList();
    final creneaux = <String>{
      for (final valeur in tutoringHours.values)
        if (valeur is List)
          for (final creneau in valeur) creneau.toString(),
    }.toList();

    final aQuelqueChose =
        serviceTypes.isNotEmpty ||
        mobility != null ||
        tutoringHours.isNotEmpty ||
        workHours.isNotEmpty;
    if (!aQuelqueChose) return;

    final tutoringJson = jsonEncode(tutoringHours);
    final workJson = jsonEncode(workHours);

    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        serviceTypes: Value(serviceTypes.join(',')),
        mobility: Value(mobility),
        tutoringHours: Value(tutoringJson),
        workHours: Value(workJson),
        tutoringDays: Value(jours.join(',')),
        tutoringSlots: Value(creneaux.join(',')),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    await _sync.enqueue(
      entity: 'teacher',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {
        'service_types': serviceTypes.join(','),
        'mobility': ?mobility,
        'tutoring_hours': tutoringJson,
        'work_hours': workJson,
        'tutoring_days': jours.join(','),
        'tutoring_slots': creneaux.join(','),
      },
    );
  }

  Future<void> setPreferredInstitutionTypes(
    String teacherId,
    List<InstitutionType> types,
  ) async {
    final codes = types.map((t) => t.code).join(',');
    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        preferredInstitutionTypes: Value(codes),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    // Le nom exact de la colonne : le serveur n'accepte d'une charge utile que
    // les clés qui correspondent à une colonne autorisée, et refuse celle dont
    // il ne reste rien. En `preferredInstitutionTypes` cet envoi était écarté.
    await _sync.enqueue(
      entity: 'teacher',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {'preferred_institution_types': codes},
    );
  }

  /// Remplace la selection de matières (§8).
  Future<void> setSubjects(String teacherId, List<String> subjectIds) async {
    await _db.transaction(() async {
      // Les niveaux rattaches a une matière retiree disparaissent avec elle.
      await (_db.delete(_db.teacherLevels)..where(
            (t) =>
                t.teacherId.equals(teacherId) & t.subjectId.isNotIn(subjectIds),
          ))
          .go();
      await (_db.delete(
        _db.teacherSubjects,
      )..where((t) => t.teacherId.equals(teacherId))).go();

      await _db.batch((batch) {
        batch.insertAll(_db.teacherSubjects, [
          for (final subjectId in subjectIds)
            TeacherSubjectsCompanion.insert(
              id: '${teacherId}_$subjectId',
              teacherId: teacherId,
              subjectId: subjectId,
              dirty: const Value(true),
            ),
        ], mode: InsertMode.insertOrReplace);
      });
    });

    await _sync.enqueue(
      entity: 'teacher_subjects',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {'subjectIds': subjectIds},
    );
  }

  /// Remplace les niveaux declares pour une matière (§9).
  Future<void> setLevelsForSubject(
    String teacherId,
    String subjectId,
    List<String> levelIds,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.teacherLevels)..where(
            (t) =>
                t.teacherId.equals(teacherId) & t.subjectId.equals(subjectId),
          ))
          .go();
      await _db.batch((batch) {
        batch.insertAll(_db.teacherLevels, [
          for (final levelId in levelIds)
            TeacherLevelsCompanion.insert(
              id: '${teacherId}_${subjectId}_$levelId',
              teacherId: teacherId,
              subjectId: subjectId,
              levelId: levelId,
              dirty: const Value(true),
            ),
        ], mode: InsertMode.insertOrReplace);
      });
    });

    await _sync.enqueue(
      entity: 'teacher_levels',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {'subjectId': subjectId, 'levelIds': levelIds},
    );
  }

  Future<String> addExperience({
    required String teacherId,
    required String institutionName,
    required String position,
    required DateTime startDate,
    DateTime? endDate,
    String? city,
    String? description,
    String? documentId,
    String? contactPhone,
    String? contactEmail,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.teacherExperiences)
        .insert(
          TeacherExperiencesCompanion.insert(
            id: id,
            teacherId: teacherId,
            institutionName: institutionName,
            position: position,
            startDate: startDate,
            endDate: Value(endDate),
            current: Value(endDate == null),
            city: Value(city),
            description: Value(description),
            documentId: Value(documentId),
            contactPhone: Value(contactPhone),
            contactEmail: Value(contactEmail),
            // Une experience n'est « vérifiée » qu'avec justificatif (§14).
            verificationStatus: Value(
              documentId == null
                  ? VerificationStatus.none.code
                  : VerificationStatus.pending.code,
            ),
            dirty: const Value(true),
          ),
        );

    await _recomputeYearsOfExperience(teacherId);
    await _sync.enqueue(
      entity: 'experience',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'teacherId': teacherId,
        'institutionName': institutionName,
        'position': position,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'city': city,
        // Le contact part avec l'experience : c'est au serveur de l'appeler,
        // pas au telephone.
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
      },
    );
    return id;
  }

  Future<void> deleteExperience(String teacherId, String experienceId) async {
    await (_db.delete(
      _db.teacherExperiences,
    )..where((t) => t.id.equals(experienceId))).go();
    await _recomputeYearsOfExperience(teacherId);
    await _sync.enqueue(
      entity: 'experience',
      entityId: experienceId,
      operation: SyncOperation.delete,
      payload: {'teacherId': teacherId},
    );
  }

  /// Recalcule l'anciennete a partir des experiences declarees.
  Future<void> _recomputeYearsOfExperience(String teacherId) async {
    final rows = await (_db.select(
      _db.teacherExperiences,
    )..where((t) => t.teacherId.equals(teacherId))).get();

    var totalMonths = 0;
    for (final r in rows) {
      final end = r.endDate ?? DateTime.now();
      totalMonths += math.max(
        0,
        (end.year - r.startDate.year) * 12 + (end.month - r.startDate.month),
      );
    }

    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        yearsExperience: Value(totalMonths ~/ 12),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Active l'option Visibilité+ (§35).
  Future<void> activateBoost(String teacherId, int days) async {
    final until = DateTime.now().add(Duration(days: days));
    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        boostedUntil: Value(until),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'teacher_boost',
      entityId: teacherId,
      operation: SyncOperation.create,
      payload: {'days': days, 'until': until.toIso8601String()},
    );
  }
}
