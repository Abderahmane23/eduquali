import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Où en est un contrat.
enum WorkContractStatus {
  pending('PENDING', 'En attente'),
  active('ACTIVE', 'En cours'),
  ended('ENDED', 'Résilié');

  const WorkContractStatus(this.code, this.label);
  final String code;
  final String label;

  static WorkContractStatus fromCode(String? code) => WorkContractStatus.values
      .firstWhere((s) => s.code == code, orElse: () => pending);
}

/// Où en est une échéance.
enum ContractPaymentStatus {
  due('DUE', 'À venir'),
  paid('PAID', 'Réglé'),
  late('LATE', 'En retard');

  const ContractPaymentStatus(this.code, this.label);
  final String code;
  final String label;

  static ContractPaymentStatus fromCode(String? code) => ContractPaymentStatus
      .values
      .firstWhere((s) => s.code == code, orElse: () => due);
}

class WorkContractException implements Exception {
  const WorkContractException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Un contrat prêt à afficher, avec le nom d'en face déjà résolu.
class WorkContractItem {
  const WorkContractItem({
    required this.row,
    required this.counterpartName,
    this.subjectName,
    this.childName,
  });

  final WorkContractRow row;

  /// Qui est en face : l'établissement pour un professeur, le professeur
  /// pour une famille.
  final String counterpartName;
  final String? subjectName;
  final String? childName;

  String get id => row.id;
  String get label => row.label;
  WorkContractStatus get status => WorkContractStatus.fromCode(row.status);
  bool get isActive => status == WorkContractStatus.active;
}

/// Une échéance prête à afficher.
class ContractPaymentItem {
  const ContractPaymentItem({required this.row, required this.contractLabel});

  final ContractPaymentRow row;
  final String contractLabel;

  DateTime get dueOn => row.dueOn;
  int get amount => row.amount;
  ContractPaymentStatus get status =>
      ContractPaymentStatus.fromCode(row.status);
}

/// Les contrats et leurs échéances.
///
/// Un seul objet pour deux situations — un établissement qui embauche, une
/// famille qui prend un répétiteur — parce que les trois tableaux de bord
/// posent la même question : qui travaille avec qui, et qui paie quoi.
class ContractsRepository {
  ContractsRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  // --- Lectures ---------------------------------------------------------

  Future<List<WorkContractItem>> ofTeacher(String teacherId) =>
      _read('c.teacher_id = ?1', teacherId);

  Future<List<WorkContractItem>> ofInstitution(String institutionId) =>
      _read('c.institution_id = ?1', institutionId);

  Future<List<WorkContractItem>> ofParent(String parentId) =>
      _read('c.parent_id = ?1', parentId);

  Future<List<WorkContractItem>> _read(String where, String value) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT c.*,
             i.name  AS institution_name,
             tu.first_name AS teacher_first, tu.last_name AS teacher_last,
             s.name  AS subject_name,
             ch.first_name AS child_name
      FROM work_contracts c
      LEFT JOIN institutions i ON i.id = c.institution_id
      LEFT JOIN teachers t     ON t.id = c.teacher_id
      LEFT JOIN users tu       ON tu.id = t.user_id
      LEFT JOIN subjects s     ON s.id = c.subject_id
      LEFT JOIN children ch    ON ch.id = c.child_id
      WHERE $where AND c.status != 'ENDED'
      ORDER BY CASE c.status WHEN 'ACTIVE' THEN 0 ELSE 1 END,
               c.created_at DESC
      ''',
          variables: [Variable<String>(value)],
          readsFrom: {
            _db.workContracts,
            _db.institutions,
            _db.teachers,
            _db.users,
            _db.subjects,
            _db.children,
          },
        )
        .get();

    return [
      for (final row in rows)
        WorkContractItem(
          row: _contract(row),
          counterpartName:
              row.read<String?>('institution_name') ??
              [
                row.read<String?>('teacher_first') ?? '',
                row.read<String?>('teacher_last') ?? '',
              ].where((p) => p.isNotEmpty).join(' '),
          subjectName: row.read<String?>('subject_name'),
          childName: row.read<String?>('child_name'),
        ),
    ];
  }

  /// Les échéances visibles par un professeur : celles de ses contrats.
  Future<List<ContractPaymentItem>> paymentsOfTeacher(String teacherId) =>
      _payments('c.teacher_id = ?1', teacherId);

  /// Les échéances dues par un parent.
  Future<List<ContractPaymentItem>> paymentsOfParent(String parentId) =>
      _payments('c.parent_id = ?1', parentId);

  Future<List<ContractPaymentItem>> _payments(
    String where,
    String value,
  ) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT p.*, c.label AS contract_label
      FROM contract_payments p
      JOIN work_contracts c ON c.id = p.contract_id
      WHERE $where
      ORDER BY CASE p.status WHEN 'PAID' THEN 1 ELSE 0 END, p.due_on ASC
      ''',
          variables: [Variable<String>(value)],
          readsFrom: {_db.contractPayments, _db.workContracts},
        )
        .get();

    return [
      for (final row in rows)
        ContractPaymentItem(
          row: ContractPaymentRow(
            id: row.read<String>('id'),
            contractId: row.read<String>('contract_id'),
            dueOn: row.read<DateTime>('due_on'),
            amount: row.read<int>('amount'),
            status: row.read<String>('status'),
            paidAt: row.read<DateTime?>('paid_at'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            version: row.read<int>('version'),
            deviceId: row.read<String?>('device_id'),
            dirty: row.read<bool>('dirty'),
          ),
          contractLabel: row.read<String>('contract_label'),
        ),
    ];
  }

  /// La prochaine échéance non réglée. C'est la seule que le parent regarde.
  Future<ContractPaymentItem?> nextPaymentOfParent(String parentId) async {
    final all = await paymentsOfParent(parentId);
    for (final p in all) {
      if (p.status != ContractPaymentStatus.paid) return p;
    }
    return null;
  }

  // --- Écritures --------------------------------------------------------

  Future<String> create({
    required String teacherId,
    required String label,
    String? institutionId,
    String? parentId,
    String? childId,
    String? subjectId,
    int monthlyAmount = 0,
    WorkContractStatus status = WorkContractStatus.pending,
  }) async {
    if (label.trim().isEmpty) {
      throw const WorkContractException('Donnez un nom au contrat.');
    }
    // Sans payeur, le contrat n'engage personne et aucune échéance ne peut
    // s'y rattacher.
    if (institutionId == null && parentId == null) {
      throw const WorkContractException(
        'Un contrat lie un professeur à un établissement ou à une famille.',
      );
    }

    final id = _uuid.v4();
    await _db
        .into(_db.workContracts)
        .insert(
          WorkContractsCompanion.insert(
            id: id,
            teacherId: teacherId,
            label: label.trim(),
            institutionId: Value(institutionId),
            parentId: Value(parentId),
            childId: Value(childId),
            subjectId: Value(subjectId),
            monthlyAmount: Value(monthlyAmount),
            status: Value(status.code),
            startedAt: Value(
              status == WorkContractStatus.active ? DateTime.now() : null,
            ),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'contract',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'teacherId': teacherId,
        'institutionId': institutionId,
        'parentId': parentId,
        'childId': childId,
        'label': label.trim(),
        'monthlyAmount': monthlyAmount,
        'status': status.code,
      },
    );
    return id;
  }

  /// Le contrat démarre : les échéances mensuelles suivent.
  Future<void> activate(String contractId, {int months = 3}) async {
    final now = DateTime.now();
    await (_db.update(
      _db.workContracts,
    )..where((t) => t.id.equals(contractId))).write(
      WorkContractsCompanion(
        status: Value(WorkContractStatus.active.code),
        startedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    await _schedulePayments(contractId, months: months);
    await _sync.enqueue(
      entity: 'contract',
      entityId: contractId,
      operation: SyncOperation.update,
      payload: {'status': WorkContractStatus.active.code},
    );
  }

  /// Résiliation. Le motif est obligatoire : sans lui, les deux parties se
  /// quittent sans rien à se dire, et le litige remonte plus tard.
  Future<void> terminate(String contractId, {required String reason}) async {
    if (reason.trim().isEmpty) {
      throw const WorkContractException(
        'Indiquez la raison de la résiliation.',
      );
    }
    final now = DateTime.now();
    await (_db.update(
      _db.workContracts,
    )..where((t) => t.id.equals(contractId))).write(
      WorkContractsCompanion(
        status: Value(WorkContractStatus.ended.code),
        endedAt: Value(now),
        endReason: Value(reason.trim()),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );

    // Les échéances à venir tombent avec le contrat ; celles déjà réglées
    // restent, elles font foi.
    await (_db.delete(_db.contractPayments)..where(
          (t) => t.contractId.equals(contractId) & t.status.equals('DUE'),
        ))
        .go();

    await _sync.enqueue(
      entity: 'contract',
      entityId: contractId,
      operation: SyncOperation.update,
      payload: {
        'status': WorkContractStatus.ended.code,
        'reason': reason.trim(),
      },
    );
  }

  Future<void> markPaid(String paymentId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.contractPayments,
    )..where((t) => t.id.equals(paymentId))).write(
      ContractPaymentsCompanion(
        status: Value(ContractPaymentStatus.paid.code),
        paidAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'contract_payment',
      entityId: paymentId,
      operation: SyncOperation.update,
      payload: {'status': ContractPaymentStatus.paid.code},
    );
  }

  Future<int> _schedulePayments(
    String contractId, {
    required int months,
  }) async {
    final existing = await (_db.select(
      _db.contractPayments,
    )..where((t) => t.contractId.equals(contractId))).get();
    if (existing.isNotEmpty) return 0;

    final contract = await (_db.select(
      _db.workContracts,
    )..where((t) => t.id.equals(contractId))).getSingleOrNull();
    if (contract == null || contract.monthlyAmount <= 0) return 0;

    final now = DateTime.now();
    await _db.batch((batch) {
      batch.insertAll(_db.contractPayments, [
        for (var i = 1; i <= months; i++)
          ContractPaymentsCompanion.insert(
            id: _uuid.v4(),
            contractId: contractId,
            dueOn: DateTime(now.year, now.month + i, 5),
            amount: contract.monthlyAmount,
            dirty: const Value(true),
          ),
      ]);
    });
    return months;
  }

  WorkContractRow _contract(QueryRow row) => WorkContractRow(
    id: row.read<String>('id'),
    teacherId: row.read<String>('teacher_id'),
    institutionId: row.read<String?>('institution_id'),
    parentId: row.read<String?>('parent_id'),
    childId: row.read<String?>('child_id'),
    subjectId: row.read<String?>('subject_id'),
    label: row.read<String>('label'),
    status: row.read<String>('status'),
    monthlyAmount: row.read<int>('monthly_amount'),
    startedAt: row.read<DateTime?>('started_at'),
    endedAt: row.read<DateTime?>('ended_at'),
    endReason: row.read<String?>('end_reason'),
    createdAt: row.read<DateTime>('created_at'),
    updatedAt: row.read<DateTime>('updated_at'),
    version: row.read<int>('version'),
    deviceId: row.read<String?>('device_id'),
    dirty: row.read<bool>('dirty'),
  );
}
