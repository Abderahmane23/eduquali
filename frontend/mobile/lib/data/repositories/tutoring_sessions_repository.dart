import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/usecases/tutoring_rules.dart';
import '../local/database/app_database.dart';

/// Une séance, avec de quoi l'afficher sans rien recalculer.
class TutoringSessionItem {
  const TutoringSessionItem({
    required this.session,
    required this.teacherName,
    required this.subjectName,
    this.childName,
  });

  final TutoringSessionRow session;
  final String teacherName;
  final String subjectName;
  final String? childName;

  DateTime get startsAt => session.startsAt;
  bool get isPast => session.status == 'DONE';
  bool get isCancelled => session.status == 'CANCELLED';
}

/// Les séances de cours à domicile.
///
/// La demande dit « ce parent veut ce professeur » ; la séance dit « mardi à
/// 16 h ». C'est la séance que le parent regarde en ouvrant l'application —
/// ce qui vient de se passer, et ce qui arrive.
class TutoringSessionsRepository {
  TutoringSessionsRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Les séances d'un professeur, la plus proche en premier.
  Future<List<TutoringSessionItem>> ofTeacher(String teacherId) =>
      _read('sv.teacher_id = ?1', teacherId);

  /// Les séances d'un parent, la plus proche en premier.
  Future<List<TutoringSessionItem>> ofParent(String parentId) =>
      _read('r.parent_id = ?1', parentId);

  Future<List<TutoringSessionItem>> _read(String where, String value) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT s.*,
             u.first_name AS teacher_first, u.last_name AS teacher_last,
             sub.name AS subject_name,
             c.first_name AS child_name
      FROM tutoring_sessions s
      JOIN tutoring_requests r ON r.id = s.request_id
      JOIN tutoring_services sv ON sv.id = r.service_id
      JOIN teachers t ON t.id = sv.teacher_id
      JOIN users u ON u.id = t.user_id
      JOIN subjects sub ON sub.id = sv.subject_id
      LEFT JOIN children c ON c.id = r.child_id
      WHERE $where
      ORDER BY s.starts_at ASC
      ''',
          variables: [Variable<String>(value)],
          readsFrom: {
            _db.tutoringSessions,
            _db.tutoringRequests,
            _db.tutoringServices,
            _db.teachers,
            _db.users,
            _db.subjects,
            _db.children,
          },
        )
        .get();

    return [
      for (final row in rows)
        TutoringSessionItem(
          session: TutoringSessionRow(
            id: row.read<String>('id'),
            requestId: row.read<String>('request_id'),
            startsAt: row.read<DateTime>('starts_at'),
            durationMinutes: row.read<int>('duration_minutes'),
            status: row.read<String>('status'),
            topic: row.read<String?>('topic'),
            notes: row.read<String?>('notes'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            version: row.read<int>('version'),
            deviceId: row.read<String?>('device_id'),
            dirty: row.read<bool>('dirty'),
          ),
          teacherName: [
            row.read<String?>('teacher_first') ?? '',
            row.read<String?>('teacher_last') ?? '',
          ].where((p) => p.isNotEmpty).join(' '),
          subjectName: row.read<String>('subject_name'),
          childName: row.read<String?>('child_name'),
        ),
    ];
  }

  /// Programme les prochaines séances d'une demande acceptée.
  ///
  /// Les créneaux viennent des disponibilités déclarées par le professeur :
  /// proposer une heure qu'il n'a pas annoncée reviendrait à promettre à la
  /// place de quelqu'un d'autre.
  Future<int> planFor(String requestId, {int count = 4, DateTime? from}) async {
    final existing = await (_db.select(
      _db.tutoringSessions,
    )..where((t) => t.requestId.equals(requestId))).get();
    if (existing.isNotEmpty) return 0;

    final request = await (_db.select(
      _db.tutoringRequests,
    )..where((t) => t.id.equals(requestId))).getSingleOrNull();
    if (request == null) return 0;

    final service = await (_db.select(
      _db.tutoringServices,
    )..where((t) => t.id.equals(request.serviceId))).getSingleOrNull();
    if (service == null) return 0;

    final teacher = await (_db.select(
      _db.teachers,
    )..where((t) => t.id.equals(service.teacherId))).getSingleOrNull();
    if (teacher == null) return 0;

    final days = _weekdays(teacher.tutoringDays);
    final slot = _firstSlot(teacher.tutoringSlots);
    if (days.isEmpty) return 0;

    final start = from ?? DateTime.now();
    final dates = <DateTime>[];
    for (var i = 1; dates.length < count && i <= 60; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (!days.contains(day.weekday)) continue;
      dates.add(DateTime(day.year, day.month, day.day, slot));
    }

    await _db.batch((batch) {
      batch.insertAll(_db.tutoringSessions, [
        for (final date in dates)
          TutoringSessionsCompanion.insert(
            id: _uuid.v4(),
            requestId: requestId,
            startsAt: date,
            dirty: const Value(true),
          ),
      ]);
    });
    return dates.length;
  }

  Future<void> markDone(String sessionId, {String? topic}) =>
      (_db.update(
        _db.tutoringSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        TutoringSessionsCompanion(
          status: const Value('DONE'),
          topic: Value(topic),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );

  /// Annule une seance, et rend le statut qu'elle avait.
  ///
  /// Ce statut rendu est ce qui permet de revenir en arriere. Le deviner
  /// remettrait « prevue » sur une seance deja faite : l'heure se rattrape,
  /// pas le cours qui a eu lieu.
  Future<String?> cancel(String sessionId) async {
    final before = await (_db.select(
      _db.tutoringSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (before == null) return null;
    await _setStatus(sessionId, 'CANCELLED');
    return before.status;
  }

  /// Remet la seance dans l'etat ou l'annulation l'a trouvee.
  Future<void> restore(String sessionId, String status) =>
      _setStatus(sessionId, status);

  Future<void> _setStatus(String sessionId, String status) =>
      (_db.update(
        _db.tutoringSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        TutoringSessionsCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );

  /// Les jours déclarés, en numéros `DateTime` (lundi = 1).
  static Set<int> _weekdays(String raw) => {
    for (final code in raw.split(','))
      if (code.trim().isNotEmpty)
        ...Weekday.values
            .where((d) => d.code == code.trim())
            .map((d) => d.index + 1),
  };

  /// L'heure de début du premier créneau déclaré. Par défaut 16 h : c'est
  /// l'heure où un élève rentre de classe.
  static int _firstSlot(String raw) {
    for (final slot in DaySlot.values) {
      if (raw.split(',').contains(slot.code)) {
        return switch (slot) {
          DaySlot.morning => 9,
          DaySlot.afternoon => 15,
          DaySlot.evening => 18,
        };
      }
    }
    return 16;
  }
}
