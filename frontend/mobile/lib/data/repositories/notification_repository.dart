import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';

/// Notification affichee dans l'application (§53).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.route,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? route;
}

/// Notifications locales (§53).
///
/// Les notifications distantes seront poussees par le serveur ; celles-ci
/// sont generees a partir de l'état local afin de rester utiles hors ligne.
class NotificationRepository {
  NotificationRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<NotificationItem>> watch(String userId) =>
      (_db.select(_db.notifications)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                NotificationItem(
                  id: r.id,
                  kind: NotificationKind.fromCode(r.kind),
                  title: r.title,
                  body: r.body,
                  createdAt: r.createdAt,
                  read: r.read,
                  route: r.route,
                ),
            ],
          );

  Future<void> push({
    required String userId,
    required NotificationKind kind,
    required String title,
    required String body,
    String? route,
  }) => _db
      .into(_db.notifications)
      .insert(
        NotificationsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          kind: kind.code,
          title: title,
          body: body,
          route: Value(route),
        ),
      );

  Future<void> markRead(String id) =>
      (_db.update(_db.notifications)..where((t) => t.id.equals(id))).write(
        const NotificationsCompanion(read: Value(true)),
      );

  Future<void> markAllRead(String userId) =>
      (_db.update(_db.notifications)..where((t) => t.userId.equals(userId)))
          .write(const NotificationsCompanion(read: Value(true)));

  Future<int> unreadCount(String userId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM notifications '
          'WHERE user_id = ?1 AND read = 0',
          variables: [Variable<String>(userId)],
          readsFrom: {_db.notifications},
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Genere les rappels deductibles de l'état local (§53).
  ///
  /// Le serveur reste maître des notifications transactionnelles ; celles-ci
  /// evitent que l'utilisateur hors ligne perde le fil de son parcours.
  Future<void> refreshLocalReminders({
    required String userId,
    required String? teacherId,
  }) async {
    if (teacherId == null) return;

    final existing = await (_db.select(
      _db.notifications,
    )..where((t) => t.userId.equals(userId))).get();
    bool alreadySent(String key) => existing.any((n) => n.id.endsWith(key));

    final teacher = await (_db.select(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).getSingleOrNull();
    if (teacher == null) return;

    // Profil incomplet : identité non vérifiée.
    if (!VerificationStatus.fromCode(teacher.identityStatus).isVerified &&
        !alreadySent('_identity_reminder')) {
      await _insertFixed(
        id: '${userId}_identity_reminder',
        userId: userId,
        kind: NotificationKind.profileIncomplete,
        title: 'Vérifiez votre identité',
        body:
            'Le badge « Identité vérifiée » est le premier critère consulte '
            'par les établissements.',
        route: '/teacher/identity',
      );
    }

    // Tests disponibles non encore passes.
    final pendingTests = await _db
        .customSelect(
          '''
          SELECT COUNT(*) AS c
          FROM teacher_levels tl
          JOIN tests t ON t.subject_id = tl.subject_id AND t.level_id = tl.level_id
          LEFT JOIN teacher_certifications tc
            ON tc.teacher_id = tl.teacher_id AND tc.subject_id = t.subject_id
           AND tc.level_id = t.level_id
          WHERE tl.teacher_id = ?1 AND tc.id IS NULL
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {_db.teacherLevels, _db.tests, _db.teacherCertifications},
        )
        .getSingle();

    final count = pendingTests.read<int>('c');
    if (count > 0 && !alreadySent('_test_reminder')) {
      await _insertFixed(
        id: '${userId}_test_reminder',
        userId: userId,
        kind: NotificationKind.testAvailable,
        title: '$count test(s) disponible(s)',
        body:
            'Passez vos évaluations pour obtenir des certifications par '
            'matière et niveau.',
        route: '/teacher/tests',
      );
    }
  }

  /// Insere une notification a identifiant stable, sans doublon.
  Future<void> _insertFixed({
    required String id,
    required String userId,
    required NotificationKind kind,
    required String title,
    required String body,
    String? route,
  }) => _db
      .into(_db.notifications)
      .insertOnConflictUpdate(
        NotificationsCompanion.insert(
          id: id,
          userId: userId,
          kind: kind.code,
          title: title,
          body: body,
          route: Value(route),
        ),
      );
}
