import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/contact_masker.dart';
import '../../domain/entities/job_models.dart';
import '../../domain/entities/recruitment_models.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';
import 'job_repository.dart';
import 'teacher_repository.dart';

/// Espace de recrutement (§24) : messagerie, entretiens, offres, contrats,
/// recrutement et suivi.
class RecruitmentRepository {
  RecruitmentRepository(this._db, this._sync, this._jobs, this._teachers);

  final AppDatabase _db;
  final SyncEngine _sync;
  final JobRepository _jobs;
  final TeacherRepository _teachers;
  static const _uuid = Uuid();

  /// Ouvre (ou recupere) l'espace de recrutement d'une candidature (§24).
  Future<String> openRoom(String applicationId) async {
    final existing = await (_db.select(
      _db.recruitmentRooms,
    )..where((t) => t.applicationId.equals(applicationId))).getSingleOrNull();
    if (existing != null) return existing.id;

    final application = await (_db.select(
      _db.applications,
    )..where((t) => t.id.equals(applicationId))).getSingleOrNull();
    if (application == null) throw StateError('Candidature introuvable');

    final job = await (_db.select(
      _db.jobs,
    )..where((t) => t.id.equals(application.jobId))).getSingle();

    final id = _uuid.v4();
    await _db
        .into(_db.recruitmentRooms)
        .insert(
          RecruitmentRoomsCompanion.insert(
            id: id,
            applicationId: applicationId,
            jobId: application.jobId,
            teacherId: application.teacherId,
            institutionId: job.institutionId,
            stage: Value(RecruitmentStage.application.code),
            dirty: const Value(true),
          ),
        );

    await _logStage(id, null, RecruitmentStage.application);
    await _sync.enqueue(
      entity: 'recruitment_room',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'applicationId': applicationId},
    );
    return id;
  }

  /// Vue complété d'un espace de recrutement.
  Future<RecruitmentRoomView?> room(String roomId) async {
    final row = await (_db.select(
      _db.recruitmentRooms,
    )..where((t) => t.id.equals(roomId))).getSingleOrNull();
    if (row == null) return null;

    final job = await _jobs.job(row.jobId);
    final teacher = await _teachers.profile(row.teacherId);
    if (job == null || teacher == null) return null;

    final stage = RecruitmentStage.fromCode(row.stage);
    final contract = await _contract(roomId);
    final unlocked =
        contract?.fullySigned == true ||
        stage.order >= RecruitmentStage.contractSigned.order;

    return RecruitmentRoomView(
      id: row.id,
      applicationId: row.applicationId,
      stage: stage,
      job: job,
      teacher: teacher,
      createdAt: row.createdAt,
      messages: await _messages(roomId, unlocked: unlocked),
      interviews: await _interviews(roomId),
      offer: await _offer(roomId),
      contract: contract,
      followUp: await _followUp(roomId),
      events: await _events(roomId),
      internalNotes: row.internalNotes,
      unreadCount: await _unreadCount(roomId),
    );
  }

  Stream<RecruitmentRoomView?> watchRoom(String roomId) => _db
      .customSelect(
        'SELECT COUNT(*) AS c FROM messages WHERE room_id = ?1',
        variables: [Variable<String>(roomId)],
        readsFrom: {
          _db.recruitmentRooms,
          _db.messages,
          _db.interviews,
          _db.recruitmentOffers,
          _db.contracts,
          _db.recruitments,
          _db.recruitmentEvents,
        },
      )
      .watch()
      .asyncMap((_) => room(roomId));

  /// Espaces de recrutement d'un établissement ou d'un enseignant.
  Future<List<RecruitmentRoomView>> rooms({
    String? institutionId,
    String? teacherId,
    Set<RecruitmentStage>? stages,
  }) async {
    final query = _db.select(_db.recruitmentRooms);
    if (institutionId != null) {
      query.where((t) => t.institutionId.equals(institutionId));
    }
    if (teacherId != null) {
      query.where((t) => t.teacherId.equals(teacherId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    final rows = await query.get();
    final views = <RecruitmentRoomView>[];
    for (final row in rows) {
      if (stages != null &&
          !stages.contains(RecruitmentStage.fromCode(row.stage))) {
        continue;
      }
      final view = await room(row.id);
      if (view != null) views.add(view);
    }
    return views;
  }

  // --- Messagerie (§23).

  Future<List<MessageItem>> _messages(
    String roomId, {
    required bool unlocked,
  }) async {
    final rows =
        await (_db.select(_db.messages)
              ..where((t) => t.roomId.equals(roomId))
              ..orderBy([(t) => OrderingTerm.asc(t.sentAt)]))
            .get();

    return [
      for (final r in rows)
        MessageItem(
          id: r.id,
          roomId: r.roomId ?? '',
          senderId: r.senderId,
          senderRole: UserRole.fromCode(r.senderRole),
          // Le masquage est reapplique a l'affichage : si le recrutement est
          // conclu, le texte d'origine redevient lisible (§30).
          body: unlocked
              ? r.body
              : ContactMasker.mask(r.body, unlocked: false).text,
          sentAt: r.sentAt,
          attachmentPath: r.attachmentPath,
          attachmentName: r.attachmentName,
          masked: !unlocked && r.masked,
          readByPeer: r.readAt != null,
        ),
    ];
  }

  /// Envoie un message. Le filtrage anti-contournement s'appliqué avant le
  /// recrutement (§30).
  Future<String> sendMessage({
    required String roomId,
    required String senderId,
    required UserRole senderRole,
    required String body,
    String? attachmentPath,
    String? attachmentName,
  }) async {
    final view = await room(roomId);
    final unlocked = view?.contactUnlocked ?? false;
    final result = ContactMasker.mask(body, unlocked: unlocked);

    final id = _uuid.v4();
    await _db
        .into(_db.messages)
        .insert(
          MessagesCompanion.insert(
            id: id,
            roomId: Value(roomId),
            senderId: senderId,
            senderRole: senderRole.code,
            // Le corps d'origine est conserve : le masquage reste une couche
            // d'affichage, revocable une fois le recrutement conclu.
            body: body,
            masked: Value(result.masked),
            attachmentPath: Value(attachmentPath),
            attachmentName: Value(attachmentName),
            dirty: const Value(true),
          ),
        );

    await _touchRoom(roomId);
    await _sync.enqueue(
      entity: 'message',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'roomId': roomId,
        'senderId': senderId,
        'body': body,
        'hasAttachment': attachmentPath != null,
      },
    );
    return id;
  }

  Future<void> markMessagesRead(String roomId, String readerId) async {
    await (_db.update(_db.messages)..where(
          (t) =>
              t.roomId.equals(roomId) &
              t.senderId.equals(readerId).not() &
              t.readAt.isNull(),
        ))
        .write(MessagesCompanion(readAt: Value(DateTime.now())));
  }

  Future<int> _unreadCount(String roomId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM messages '
          'WHERE room_id = ?1 AND read_at IS NULL',
          variables: [Variable<String>(roomId)],
          readsFrom: {_db.messages},
        )
        .getSingle();
    return row.read<int>('c');
  }

  // --- Entretiens (§25).

  Future<List<InterviewItem>> _interviews(String roomId) async {
    final rows =
        await (_db.select(_db.interviews)
              ..where((t) => t.roomId.equals(roomId))
              ..orderBy([(t) => OrderingTerm.desc(t.scheduledAt)]))
            .get();

    return [
      for (final r in rows)
        InterviewItem(
          id: r.id,
          roomId: r.roomId,
          scheduledAt: r.scheduledAt,
          mode: InterviewMode.fromCode(r.mode),
          status: InterviewStatus.fromCode(r.status),
          location: r.location,
          meetingLink: r.meetingLink,
          comment: r.comment,
          feedback: r.feedback,
        ),
    ];
  }

  Future<String> proposeInterview({
    required String roomId,
    required DateTime scheduledAt,
    required InterviewMode mode,
    String? location,
    String? meetingLink,
    String? comment,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.interviews)
        .insert(
          InterviewsCompanion.insert(
            id: id,
            roomId: roomId,
            scheduledAt: scheduledAt,
            mode: Value(mode.code),
            status: Value(InterviewStatus.proposed.code),
            location: Value(location),
            meetingLink: Value(meetingLink),
            comment: Value(comment),
            dirty: const Value(true),
          ),
        );

    await advanceStage(roomId, RecruitmentStage.interview);
    await _sync.enqueue(
      entity: 'interview',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'roomId': roomId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'mode': mode.code,
      },
    );
    return id;
  }

  Future<void> respondToInterview(
    String interviewId,
    InterviewStatus status, {
    String? feedback,
  }) async {
    await (_db.update(
      _db.interviews,
    )..where((t) => t.id.equals(interviewId))).write(
      InterviewsCompanion(
        status: Value(status.code),
        feedback: Value(feedback),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'interview',
      entityId: interviewId,
      operation: SyncOperation.update,
      payload: {'status': status.code, 'feedback': feedback},
    );
  }

  // --- Proposition de recrutement (§26).

  Future<OfferItem?> _offer(String roomId) async {
    final row =
        await (_db.select(_db.recruitmentOffers)
              ..where((t) => t.roomId.equals(roomId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;

    return OfferItem(
      id: row.id,
      roomId: row.roomId,
      position: row.position,
      contractType: ContractType.fromCode(row.contractType),
      monthlySalary: row.monthlySalary,
      startDate: row.startDate,
      status: OfferStatus.fromCode(row.status),
      sentAt: row.sentAt ?? row.createdAt,
      durationMonths: row.durationMonths,
      trialPeriodDays: row.trialPeriodDays,
      schedule: row.schedule,
      extraConditions: row.extraConditions,
      changeRequest: row.changeRequest,
      respondedAt: row.respondedAt,
    );
  }

  Future<String> sendOffer({
    required String roomId,
    required String position,
    required ContractType contractType,
    required int monthlySalary,
    required DateTime startDate,
    int? durationMonths,
    int? trialPeriodDays,
    String? schedule,
    String? extraConditions,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.recruitmentOffers)
        .insert(
          RecruitmentOffersCompanion.insert(
            id: id,
            roomId: roomId,
            position: position,
            contractType: contractType.code,
            monthlySalary: monthlySalary,
            startDate: startDate,
            durationMonths: Value(durationMonths),
            trialPeriodDays: Value(trialPeriodDays),
            schedule: Value(schedule),
            extraConditions: Value(extraConditions),
            status: Value(OfferStatus.sent.code),
            sentAt: Value(DateTime.now()),
            dirty: const Value(true),
          ),
        );

    await advanceStage(roomId, RecruitmentStage.offerSent);
    await _updateApplicationStatus(roomId, ApplicationStatus.offerReceived);

    await _sync.enqueue(
      entity: 'recruitment_offer',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'roomId': roomId,
        'position': position,
        'monthlySalary': monthlySalary,
        'startDate': startDate.toIso8601String(),
      },
    );
    return id;
  }

  /// Réponse de l'enseignant : accepter, demander une modification, refuser.
  Future<void> respondToOffer(
    String offerId,
    OfferStatus status, {
    String? changeRequest,
  }) async {
    final offer = await (_db.select(
      _db.recruitmentOffers,
    )..where((t) => t.id.equals(offerId))).getSingle();

    await (_db.update(
      _db.recruitmentOffers,
    )..where((t) => t.id.equals(offerId))).write(
      RecruitmentOffersCompanion(
        status: Value(status.code),
        changeRequest: Value(changeRequest),
        respondedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    if (status == OfferStatus.accepted) {
      await advanceStage(offer.roomId, RecruitmentStage.offerAccepted);
      await _updateApplicationStatus(offer.roomId, ApplicationStatus.accepted);
    } else if (status == OfferStatus.declined) {
      await _updateApplicationStatus(offer.roomId, ApplicationStatus.rejected);
    }

    await _sync.enqueue(
      entity: 'recruitment_offer',
      entityId: offerId,
      operation: SyncOperation.update,
      payload: {'status': status.code, 'changeRequest': changeRequest},
    );
  }

  // --- Contrat (§27).

  Future<ContractItem?> _contract(String roomId) async {
    final row =
        await (_db.select(_db.contracts)
              ..where((t) => t.roomId.equals(roomId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;

    return ContractItem(
      id: row.id,
      roomId: row.roomId,
      offerId: row.offerId,
      reference: row.reference,
      bodyText: row.bodyText,
      status: ContractStatus.fromCode(row.status),
      createdAt: row.createdAt,
      pdfPath: row.pdfPath,
      teacherSignaturePath: row.teacherSignaturePath,
      teacherSignedAt: row.teacherSignedAt,
      institutionSignaturePath: row.institutionSignaturePath,
      institutionSignedAt: row.institutionSignedAt,
    );
  }

  Future<String> createContract({
    required String roomId,
    required String offerId,
    required String reference,
    required String bodyText,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.contracts)
        .insert(
          ContractsCompanion.insert(
            id: id,
            roomId: roomId,
            offerId: offerId,
            reference: reference,
            bodyText: bodyText,
            status: Value(ContractStatus.pendingSignature.code),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'contract',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'roomId': roomId, 'offerId': offerId, 'référence': reference},
    );
    return id;
  }

  /// Enregistre une signature. La valeur juridique de la signature
  /// electronique doit etre validee au regard du cadre applicable (§27).
  Future<void> signContract({
    required String contractId,
    required UserRole signer,
    required String signaturePath,
  }) async {
    final now = DateTime.now();
    await (_db.update(
      _db.contracts,
    )..where((t) => t.id.equals(contractId))).write(
      signer == UserRole.teacher
          ? ContractsCompanion(
              teacherSignaturePath: Value(signaturePath),
              teacherSignedAt: Value(now),
              updatedAt: Value(now),
              dirty: const Value(true),
            )
          : ContractsCompanion(
              institutionSignaturePath: Value(signaturePath),
              institutionSignedAt: Value(now),
              updatedAt: Value(now),
              dirty: const Value(true),
            ),
    );

    final contract = await (_db.select(
      _db.contracts,
    )..where((t) => t.id.equals(contractId))).getSingle();

    // Le contrat n'est complet qu'une fois les deux signatures apposees.
    if (contract.teacherSignaturePath != null &&
        contract.institutionSignaturePath != null) {
      await (_db.update(_db.contracts)..where((t) => t.id.equals(contractId)))
          .write(ContractsCompanion(status: Value(ContractStatus.signed.code)));
      await advanceStage(contract.roomId, RecruitmentStage.contractSigned);
    }

    await _sync.enqueue(
      entity: 'contract',
      entityId: contractId,
      operation: SyncOperation.update,
      payload: {'signer': signer.code, 'signedAt': now.toIso8601String()},
    );
  }

  Future<void> attachContractPdf(String contractId, String path) async {
    await (_db.update(_db.contracts)..where((t) => t.id.equals(contractId)))
        .write(ContractsCompanion(pdfPath: Value(path)));
  }

  // --- Recrutement et suivi (§32).

  Future<RecruitmentFollowUp?> _followUp(String roomId) async {
    final row = await (_db.select(
      _db.recruitments,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    if (row == null) return null;

    return RecruitmentFollowUp(
      id: row.id,
      startDate: row.startDate,
      active: row.active,
      monthlySalary: row.monthlySalary,
      completedMilestones: [
        for (final part in row.completedMilestones.split(','))
          ?int.tryParse(part),
      ],
      trialPeriodDays: row.trialPeriodDays,
      contractId: row.contractId,
      successFeeAmount: row.successFeeAmount,
      feePaid: row.feePaid,
    );
  }

  /// Confirme le recrutement et ouvre le suivi (§32).
  Future<String> confirmRecruitment(String roomId) async {
    final existing = await (_db.select(
      _db.recruitments,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    if (existing != null) return existing.id;

    final roomRow = await (_db.select(
      _db.recruitmentRooms,
    )..where((t) => t.id.equals(roomId))).getSingle();
    final offer = await _offer(roomId);
    if (offer == null) throw StateError('Aucune proposition acceptée');

    final contract = await _contract(roomId);
    final id = _uuid.v4();

    await _db
        .into(_db.recruitments)
        .insert(
          RecruitmentsCompanion.insert(
            id: id,
            roomId: roomId,
            teacherId: roomRow.teacherId,
            institutionId: roomRow.institutionId,
            contractId: Value(contract?.id),
            startDate: offer.startDate,
            monthlySalary: offer.monthlySalary,
            trialPeriodDays: Value(offer.trialPeriodDays),
            // Frais de recrutement = 1 mois de salaire (§36).
            successFeeAmount: Value(
              (offer.monthlySalary * AppConstants.successFeeMonths).round(),
            ),
            dirty: const Value(true),
          ),
        );

    await advanceStage(roomId, RecruitmentStage.hired);
    await _updateApplicationStatus(roomId, ApplicationStatus.hired);

    await _sync.enqueue(
      entity: 'recruitment',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'roomId': roomId,
        'startDate': offer.startDate.toIso8601String(),
      },
    );
    return id;
  }

  /// Évaluation a un jalon de suivi (§32).
  Future<void> submitReview({
    required String recruitmentId,
    required int milestoneDays,
    required int punctuality,
    required int pedagogy,
    required int subjectMastery,
    required int professionalism,
    required int attendance,
    String? comment,
  }) async {
    final recruitment = await (_db.select(
      _db.recruitments,
    )..where((t) => t.id.equals(recruitmentId))).getSingle();

    final overall =
        (((punctuality +
                        pedagogy +
                        subjectMastery +
                        professionalism +
                        attendance) /
                    25) *
                100)
            .round();

    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.teacherReviews)
          .insert(
            TeacherReviewsCompanion.insert(
              id: id,
              recruitmentId: recruitmentId,
              teacherId: recruitment.teacherId,
              institutionId: recruitment.institutionId,
              milestoneDays: milestoneDays,
              punctuality: punctuality,
              pedagogy: pedagogy,
              subjectMastery: subjectMastery,
              professionalism: professionalism,
              attendance: attendance,
              overall: overall,
              comment: Value(comment),
              dirty: const Value(true),
            ),
          );

      final done = {
        ...recruitment.completedMilestones
            .split(',')
            .where((e) => e.isNotEmpty),
        milestoneDays.toString(),
      };

      await (_db.update(
        _db.recruitments,
      )..where((t) => t.id.equals(recruitmentId))).write(
        RecruitmentsCompanion(
          completedMilestones: Value(done.join(',')),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
    });

    await _sync.enqueue(
      entity: 'teacher_review',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'recruitmentId': recruitmentId,
        'milestoneDays': milestoneDays,
        'overall': overall,
      },
    );
  }

  Future<void> markFeePaid(String recruitmentId) async {
    await (_db.update(
      _db.recruitments,
    )..where((t) => t.id.equals(recruitmentId))).write(
      RecruitmentsCompanion(
        feePaid: const Value(true),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  // --- Workflow (§28).

  /// Fait avancer l'espace de recrutement, sans jamais reculer.
  Future<void> advanceStage(String roomId, RecruitmentStage target) async {
    final row = await (_db.select(
      _db.recruitmentRooms,
    )..where((t) => t.id.equals(roomId))).getSingle();

    final current = RecruitmentStage.fromCode(row.stage);
    if (target.order <= current.order) return;

    await (_db.update(
      _db.recruitmentRooms,
    )..where((t) => t.id.equals(roomId))).write(
      RecruitmentRoomsCompanion(
        stage: Value(target.code),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    await _logStage(roomId, current, target);
    await _sync.enqueue(
      entity: 'recruitment_room',
      entityId: roomId,
      operation: SyncOperation.update,
      payload: {'stage': target.code},
    );
  }

  Future<void> saveInternalNotes(String roomId, String notes) async {
    await (_db.update(
      _db.recruitmentRooms,
    )..where((t) => t.id.equals(roomId))).write(
      RecruitmentRoomsCompanion(
        internalNotes: Value(notes),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Chaque changement de statut est enregistre (§28).
  Future<void> _logStage(
    String roomId,
    RecruitmentStage? from,
    RecruitmentStage to,
  ) async {
    await _db
        .into(_db.recruitmentEvents)
        .insert(
          RecruitmentEventsCompanion.insert(
            id: _uuid.v4(),
            roomId: roomId,
            fromStage: Value(from?.code),
            toStage: to.code,
          ),
        );
  }

  Future<List<RecruitmentEvent>> _events(String roomId) async {
    final rows =
        await (_db.select(_db.recruitmentEvents)
              ..where((t) => t.roomId.equals(roomId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    return [
      for (final r in rows)
        RecruitmentEvent(
          id: r.id,
          toStage: RecruitmentStage.fromCode(r.toStage),
          fromStage: r.fromStage == null
              ? null
              : RecruitmentStage.fromCode(r.fromStage),
          createdAt: r.createdAt,
          note: r.note,
        ),
    ];
  }

  Future<void> _updateApplicationStatus(
    String roomId,
    ApplicationStatus status,
  ) async {
    final row = await (_db.select(
      _db.recruitmentRooms,
    )..where((t) => t.id.equals(roomId))).getSingle();

    await (_db.update(
      _db.applications,
    )..where((t) => t.id.equals(row.applicationId))).write(
      ApplicationsCompanion(
        status: Value(status.code),
        statusChangedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> _touchRoom(String roomId) async {
    await (_db.update(_db.recruitmentRooms)..where((t) => t.id.equals(roomId)))
        .write(RecruitmentRoomsCompanion(updatedAt: Value(DateTime.now())));
  }

  /// Tableau de bord établissement (§20).
  Future<Map<String, int>> institutionStats(String institutionId) async {
    final row = await _db
        .customSelect(
          '''
          SELECT
            (SELECT COUNT(*) FROM jobs
              WHERE institution_id = ?1 AND status = 'PUBLISHED') AS active_jobs,
            (SELECT COUNT(*) FROM applications a
               JOIN jobs j ON j.id = a.job_id
              WHERE j.institution_id = ?1) AS applications,
            (SELECT COUNT(*) FROM applications a
               JOIN jobs j ON j.id = a.job_id
              WHERE j.institution_id = ?1 AND a.shortlisted = 1) AS shortlisted,
            (SELECT COUNT(*) FROM interviews i
               JOIN recruitment_rooms r ON r.id = i.room_id
              WHERE r.institution_id = ?1
                AND i.status IN ('PROPOSED', 'ACCEPTED')) AS interviews,
            (SELECT COUNT(*) FROM recruitment_offers o
               JOIN recruitment_rooms r ON r.id = o.room_id
              WHERE r.institution_id = ?1 AND o.status = 'SENT') AS offers,
            (SELECT COUNT(*) FROM recruitments
              WHERE institution_id = ?1 AND active = 1) AS ongoing,
            (SELECT COUNT(*) FROM recruitments
              WHERE institution_id = ?1 AND active = 0) AS completed
          ''',
          variables: [Variable<String>(institutionId)],
          readsFrom: {
            _db.jobs,
            _db.applications,
            _db.interviews,
            _db.recruitmentOffers,
            _db.recruitments,
            _db.recruitmentRooms,
          },
        )
        .getSingle();

    return {
      'activeJobs': row.read<int>('active_jobs'),
      'applications': row.read<int>('applications'),
      'shortlisted': row.read<int>('shortlisted'),
      'interviews': row.read<int>('interviews'),
      'offers': row.read<int>('offers'),
      'ongoing': row.read<int>('ongoing'),
      'completed': row.read<int>('completed'),
    };
  }

  Stream<Map<String, int>> watchInstitutionStats(String institutionId) => _db
      .customSelect(
        'SELECT COUNT(*) AS c FROM jobs WHERE institution_id = ?1',
        variables: [Variable<String>(institutionId)],
        readsFrom: {
          _db.jobs,
          _db.applications,
          _db.interviews,
          _db.recruitmentOffers,
          _db.recruitments,
        },
      )
      .watch()
      .asyncMap((_) => institutionStats(institutionId));

  /// Recrutements d'un enseignant, pour son historique professionnel (§15).
  Future<List<({RecruitmentFollowUp followUp, JobOffer job})>>
  teacherRecruitments(String teacherId) async {
    final rows =
        await (_db.select(_db.recruitments)
              ..where((t) => t.teacherId.equals(teacherId))
              ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
            .get();

    final items = <({RecruitmentFollowUp followUp, JobOffer job})>[];
    for (final r in rows) {
      final roomRow = await (_db.select(
        _db.recruitmentRooms,
      )..where((t) => t.id.equals(r.roomId))).getSingle();
      final job = await _jobs.job(roomRow.jobId);
      if (job == null) continue;

      final followUp = await _followUp(r.roomId);
      if (followUp != null) items.add((followUp: followUp, job: job));
    }
    return items;
  }
}
