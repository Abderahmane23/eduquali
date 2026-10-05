import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../core/security/identity_checks.dart';
import '../../core/storage/document_pipeline.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// État du parcours de vérification d'identité (§6).
class IdentityVerificationState {
  const IdentityVerificationState({
    required this.status,
    this.selfieDocumentId,
    this.idFrontDocumentId,
    this.idBackDocumentId,
    this.extracted,
    this.rejectionReason,
  });

  final VerificationStatus status;
  final String? selfieDocumentId;
  final String? idFrontDocumentId;
  final String? idBackDocumentId;
  final IdCardData? extracted;
  final String? rejectionReason;

  bool get hasSelfie => selfieDocumentId != null;
  bool get hasIdCard => idFrontDocumentId != null;
  bool get isComplete => hasSelfie && hasIdCard;
}

/// Document local, tel qu'affiche dans le suivi des envois (§46).
class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.type,
    required this.uploadStatus,
    required this.verificationStatus,
    required this.createdAt,
    this.localPath,
    this.sizeBytes = 0,
    this.rejectionReason,
  });

  final String id;
  final DocumentType type;
  final DocumentUploadStatus uploadStatus;
  final VerificationStatus verificationStatus;
  final DateTime createdAt;
  final String? localPath;
  final int sizeBytes;
  final String? rejectionReason;
}

/// Vérification d'identité et des diplômes (§6, §7, §46).
class VerificationRepository {
  VerificationRepository(this._db, this._sync, this._pipeline, this._checks);

  final AppDatabase _db;
  final SyncEngine _sync;
  final DocumentPipeline _pipeline;
  final IdentityCheckService _checks;
  static const _uuid = Uuid();

  /// Enregistre un document capture et l'inscrit dans la file d'envoi (§46).
  Future<String> storeDocument({
    required String teacherId,
    required CapturedDocument captured,
    Map<String, dynamic>? extracted,
  }) async {
    final id = _uuid.v4();

    await _db
        .into(_db.teacherDocuments)
        .insert(
          TeacherDocumentsCompanion.insert(
            id: id,
            teacherId: teacherId,
            type: captured.type.code,
            localPath: Value(captured.path),
            checksum: Value(captured.checksum),
            sizeBytes: Value(captured.sizeBytes),
            uploadStatus: Value(DocumentUploadStatus.pendingUpload.code),
            verificationStatus: Value(VerificationStatus.pending.code),
            extractedJson: Value(
              extracted == null ? null : jsonEncode(extracted),
            ),
            dirty: const Value(true),
          ),
        );

    // Le fichier lui-même est televerse par la file de synchronisation ; seul
    // le chemin local circule ici, jamais le contenu du document (§51).
    await _sync.enqueue(
      entity: 'document',
      entityId: id,
      operation: SyncOperation.upload,
      payload: {
        'teacherId': teacherId,
        'type': captured.type.code,
        'checksum': captured.checksum,
        'sizeBytes': captured.sizeBytes,
      },
    );

    await _db.audit(
      action: 'DOCUMENT_CAPTURED',
      actorId: teacherId,
      entity: 'document',
      entityId: id,
      // Aucune donnée issue de la piece d'identité n'est journalisee (§51).
      metadata: captured.type.code,
    );

    return id;
  }

  /// Étape 1 — selfie, avec controles de qualite (§6).
  Future<FaceCheckResult> submitSelfie({
    required String teacherId,
    required CapturedDocument captured,
  }) async {
    final check = await _checks.checkSelfie(captured.path);
    if (!check.passed) {
      await _pipeline.deleteLocal(captured.path);
      return check;
    }

    await _replaceDocument(teacherId, DocumentType.selfie);
    await storeDocument(teacherId: teacherId, captured: captured);
    await _refreshIdentityStatus(teacherId);
    return check;
  }

  /// Étape 2 — piece d'identité recto et verso (§6).
  Future<IdCardData> submitIdCard({
    required String teacherId,
    required CapturedDocument front,
    CapturedDocument? back,
  }) async {
    final extracted = await _checks.extractIdCard(
      front.path,
      backPath: back?.path,
    );

    await _replaceDocument(teacherId, DocumentType.idFront);
    await storeDocument(
      teacherId: teacherId,
      captured: front,
      extracted: extracted.toJson(),
    );

    if (back != null) {
      await _replaceDocument(teacherId, DocumentType.idBack);
      await storeDocument(teacherId: teacherId, captured: back);
    }

    await _refreshIdentityStatus(teacherId);
    return extracted;
  }

  /// Un nouveau document du même type remplace le precedent.
  Future<void> _replaceDocument(String teacherId, DocumentType type) async {
    final previous =
        await (_db.select(_db.teacherDocuments)..where(
              (t) => t.teacherId.equals(teacherId) & t.type.equals(type.code),
            ))
            .get();

    for (final doc in previous) {
      await _pipeline.deleteLocal(doc.localPath);
    }
    await (_db.delete(_db.teacherDocuments)..where(
          (t) => t.teacherId.equals(teacherId) & t.type.equals(type.code),
        ))
        .go();
  }

  /// Fait passer l'identité en vérification une fois les pieces reunies (§6).
  Future<void> _refreshIdentityStatus(String teacherId) async {
    final state = await identityState(teacherId);
    if (!state.isComplete) return;

    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        identityStatus: Value(VerificationStatus.inReview.code),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    await _sync.enqueue(
      entity: 'identity_verification',
      entityId: teacherId,
      operation: SyncOperation.create,
      payload: {'teacherId': teacherId},
    );
  }

  Future<IdentityVerificationState> identityState(String teacherId) async {
    final teacher = await (_db.select(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).getSingleOrNull();

    final documents = await (_db.select(
      _db.teacherDocuments,
    )..where((t) => t.teacherId.equals(teacherId))).get();

    String? idFor(DocumentType type) =>
        documents.where((d) => d.type == type.code).firstOrNull?.id;

    final front = documents
        .where((d) => d.type == DocumentType.idFront.code)
        .firstOrNull;

    return IdentityVerificationState(
      status: VerificationStatus.fromCode(teacher?.identityStatus),
      selfieDocumentId: idFor(DocumentType.selfie),
      idFrontDocumentId: idFor(DocumentType.idFront),
      idBackDocumentId: idFor(DocumentType.idBack),
      extracted: front?.extractedJson == null
          ? null
          : _decodeIdCard(front!.extractedJson!),
      rejectionReason: front?.rejectionReason,
    );
  }

  IdCardData _decodeIdCard(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return IdCardData(
      lastName: json['lastName'] as String?,
      firstName: json['firstName'] as String?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.tryParse(json['birthDate'] as String),
      documentNumber: json['documentNumber'] as String?,
      nationality: json['nationality'] as String?,
      sex: json['sex'] as String?,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.tryParse(json['expiryDate'] as String),
      confidence: json['confidence'] as int? ?? 0,
    );
  }

  Stream<IdentityVerificationState> watchIdentityState(String teacherId) => _db
      .customSelect(
        'SELECT COUNT(*) AS c FROM teacher_documents WHERE teacher_id = ?1',
        variables: [Variable<String>(teacherId)],
        readsFrom: {_db.teacherDocuments, _db.teachers},
      )
      .watch()
      .asyncMap((_) => identityState(teacherId));

  /// Declaration d'un diplôme (§7).
  Future<String> addDiploma({
    required String teacherId,
    required String diplomaType,
    required String institutionName,
    required int graduationYear,
    String? field,
    String? speciality,
    String? academicLevelId,
    CapturedDocument? document,
  }) async {
    String? documentId;
    if (document != null) {
      documentId = await storeDocument(
        teacherId: teacherId,
        captured: document,
      );
    }

    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.teacherDiplomas)
          .insert(
            TeacherDiplomasCompanion.insert(
              id: id,
              teacherId: teacherId,
              diplomaType: diplomaType,
              institutionName: institutionName,
              graduationYear: graduationYear,
              field: Value(field),
              speciality: Value(speciality),
              academicLevelId: Value(academicLevelId),
              documentId: Value(documentId),
              verificationStatus: Value(
                documentId == null
                    ? VerificationStatus.needsFix.code
                    : VerificationStatus.inReview.code,
              ),
              dirty: const Value(true),
            ),
          );

      // Le statut global reflete le diplôme le plus avance.
      await _syncDiplomaStatus(teacherId);
    });

    await _sync.enqueue(
      entity: 'diploma',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'teacherId': teacherId,
        'diplomaType': diplomaType,
        'institutionName': institutionName,
        'graduationYear': graduationYear,
        'field': field,
        'speciality': speciality,
        'documentId': documentId,
      },
    );
    return id;
  }

  Future<void> deleteDiploma(String teacherId, String diplomaId) async {
    final diploma = await (_db.select(
      _db.teacherDiplomas,
    )..where((t) => t.id.equals(diplomaId))).getSingleOrNull();

    if (diploma?.documentId != null) {
      final doc = await (_db.select(
        _db.teacherDocuments,
      )..where((t) => t.id.equals(diploma!.documentId!))).getSingleOrNull();
      await _pipeline.deleteLocal(doc?.localPath);
      await (_db.delete(
        _db.teacherDocuments,
      )..where((t) => t.id.equals(diploma!.documentId!))).go();
    }

    await (_db.delete(
      _db.teacherDiplomas,
    )..where((t) => t.id.equals(diplomaId))).go();
    await _syncDiplomaStatus(teacherId);

    await _sync.enqueue(
      entity: 'diploma',
      entityId: diplomaId,
      operation: SyncOperation.delete,
      payload: {'teacherId': teacherId},
    );
  }

  /// Aligne `teachers.diploma_status` sur le meilleur statut disponible.
  Future<void> _syncDiplomaStatus(String teacherId) async {
    final diplomas = await (_db.select(
      _db.teacherDiplomas,
    )..where((t) => t.teacherId.equals(teacherId))).get();

    final status = diplomas.isEmpty
        ? VerificationStatus.none
        : diplomas.any(
            (d) => VerificationStatus.fromCode(d.verificationStatus).isVerified,
          )
        ? VerificationStatus.verified
        : diplomas.any(
            (d) =>
                VerificationStatus.fromCode(d.verificationStatus).isInProgress,
          )
        ? VerificationStatus.inReview
        : VerificationStatus.needsFix;

    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        diplomaStatus: Value(status.code),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<List<DocumentItem>> documents(String teacherId) async {
    final rows =
        await (_db.select(_db.teacherDocuments)
              ..where((t) => t.teacherId.equals(teacherId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return [
      for (final r in rows)
        DocumentItem(
          id: r.id,
          type: DocumentType.fromCode(r.type),
          uploadStatus: DocumentUploadStatus.fromCode(r.uploadStatus),
          verificationStatus: VerificationStatus.fromCode(r.verificationStatus),
          createdAt: r.createdAt,
          localPath: r.localPath,
          sizeBytes: r.sizeBytes,
          rejectionReason: r.rejectionReason,
        ),
    ];
  }

  Future<String?> documentPath(String documentId) async {
    final row = await (_db.select(
      _db.teacherDocuments,
    )..where((t) => t.id.equals(documentId))).getSingleOrNull();
    return row?.localPath;
  }

  /// Appliqué une decision de vérification reçue du serveur ou du back-office.
  Future<void> applyDecision({
    required String teacherId,
    required DocumentType type,
    required VerificationStatus status,
    String? reason,
  }) async {
    await (_db.update(_db.teacherDocuments)..where(
          (t) => t.teacherId.equals(teacherId) & t.type.equals(type.code),
        ))
        .write(
          TeacherDocumentsCompanion(
            verificationStatus: Value(status.code),
            rejectionReason: Value(reason),
            updatedAt: Value(DateTime.now()),
          ),
        );

    if (type == DocumentType.selfie || type == DocumentType.idFront) {
      await (_db.update(
        _db.teachers,
      )..where((t) => t.id.equals(teacherId))).write(
        TeachersCompanion(
          identityStatus: Value(status.code),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
