import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Où en est un cours vidéo.
enum VideoCourseStatus {
  draft('DRAFT', 'Brouillon'),
  published('PUBLISHED', 'En vente'),
  hidden('HIDDEN', 'Retiré');

  const VideoCourseStatus(this.code, this.label);
  final String code;
  final String label;

  static VideoCourseStatus fromCode(String? code) => VideoCourseStatus.values
      .firstWhere((s) => s.code == code, orElse: () => draft);
}

class VideoCourseException implements Exception {
  const VideoCourseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Un cours vidéo prêt à afficher.
class VideoCourseItem {
  const VideoCourseItem({
    required this.row,
    required this.teacherName,
    this.subjectName,
    this.purchased = false,
  });

  final VideoCourseRow row;
  final String teacherName;
  final String? subjectName;

  /// Vrai quand l'élève qui regarde l'a déjà acheté.
  final bool purchased;

  String get id => row.id;
  String get title => row.title;
  int get price => row.price;
  VideoCourseStatus get status => VideoCourseStatus.fromCode(row.status);

  /// Ce que touche le professeur, commission déduite.
  int get net => AppConstants.videoCourseNet(row.price);

  List<String> get videos => [
    for (final p in row.videoPaths.split(','))
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

/// Le catalogue de cours vidéo.
///
/// Un cours vidéo se vend une fois et se regarde autant de fois qu'on veut,
/// sans que le professeur se déplace : c'est ce qui permet à un professeur de
/// Conakry d'atteindre un élève de Nzérékoré.
class VideoCoursesRepository {
  VideoCoursesRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  /// Les cours d'un professeur, brouillons compris — c'est son atelier.
  Future<List<VideoCourseItem>> ofTeacher(String teacherId) =>
      _read('c.teacher_id = ?1', teacherId);

  /// Le catalogue vu par une famille : uniquement ce qui est en vente.
  Future<List<VideoCourseItem>> published({String? parentId}) =>
      _read("c.status = 'PUBLISHED'", null, parentId: parentId);

  Future<List<VideoCourseItem>> _read(
    String where,
    String? value, {
    String? parentId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT c.*,
             u.first_name AS teacher_first, u.last_name AS teacher_last,
             s.name AS subject_name,
             (SELECT COUNT(*) FROM course_purchases p
               WHERE p.course_id = c.id AND p.parent_id = ?2) AS bought
      FROM video_courses c
      JOIN teachers t ON t.id = c.teacher_id
      JOIN users u    ON u.id = t.user_id
      LEFT JOIN subjects s ON s.id = c.subject_id
      WHERE $where
      ORDER BY c.created_at DESC
      ''',
          variables: [
            Variable<String>(value ?? ''),
            Variable<String>(parentId ?? ''),
          ],
          readsFrom: {
            _db.videoCourses,
            _db.teachers,
            _db.users,
            _db.subjects,
            _db.coursePurchases,
          },
        )
        .get();

    return [
      for (final row in rows)
        VideoCourseItem(
          row: VideoCourseRow(
            id: row.read<String>('id'),
            teacherId: row.read<String>('teacher_id'),
            title: row.read<String>('title'),
            description: row.read<String?>('description'),
            subjectId: row.read<String?>('subject_id'),
            levelIds: row.read<String>('level_ids'),
            price: row.read<int>('price'),
            videoPaths: row.read<String>('video_paths'),
            coverPath: row.read<String?>('cover_path'),
            status: row.read<String>('status'),
            purchaseCount: row.read<int>('purchase_count'),
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
          subjectName: row.read<String?>('subject_name'),
          purchased: row.read<int>('bought') > 0,
        ),
    ];
  }

  Future<String> create({
    required String teacherId,
    required String title,
    required int price,
    String? description,
    String? subjectId,
    List<String> levelIds = const [],
    List<String> videoPaths = const [],
  }) async {
    if (title.trim().isEmpty) {
      throw const VideoCourseException('Donnez un titre à votre cours.');
    }
    if (price <= 0) {
      throw const VideoCourseException('Indiquez le prix de votre cours.');
    }
    // Un cours sans vidéo n'est pas un cours : le publier ferait payer un
    // élève pour une page vide.
    if (videoPaths.isEmpty) {
      throw const VideoCourseException('Ajoutez au moins une vidéo.');
    }

    final id = _uuid.v4();
    await _db
        .into(_db.videoCourses)
        .insert(
          VideoCoursesCompanion.insert(
            id: id,
            teacherId: teacherId,
            title: title.trim(),
            description: Value(description?.trim()),
            subjectId: Value(subjectId),
            levelIds: Value(levelIds.join(',')),
            price: Value(price),
            videoPaths: Value(videoPaths.join(',')),
            status: Value(VideoCourseStatus.published.code),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'video_course',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'teacherId': teacherId,
        'title': title.trim(),
        'price': price,
        'subjectId': subjectId,
        'levelIds': levelIds,
      },
    );
    return id;
  }

  Future<void> setStatus(String courseId, VideoCourseStatus status) async {
    await (_db.update(
      _db.videoCourses,
    )..where((t) => t.id.equals(courseId))).write(
      VideoCoursesCompanion(
        status: Value(status.code),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'video_course',
      entityId: courseId,
      operation: SyncOperation.update,
      payload: {'status': status.code},
    );
  }

  /// Achat d'un cours. La commission est figée à cet instant.
  ///
  /// Le prix aussi : changer le tarif plus tard ne doit pas réécrire ce
  /// qu'un élève a déjà réglé.
  Future<String> purchase({
    required String courseId,
    required String parentId,
  }) async {
    final course = await (_db.select(
      _db.videoCourses,
    )..where((t) => t.id.equals(courseId))).getSingleOrNull();
    if (course == null) {
      throw const VideoCourseException('Ce cours n’existe plus.');
    }
    if (VideoCourseStatus.fromCode(course.status) !=
        VideoCourseStatus.published) {
      throw const VideoCourseException('Ce cours n’est plus en vente.');
    }

    final already =
        await (_db.select(_db.coursePurchases)..where(
              (t) => t.courseId.equals(courseId) & t.parentId.equals(parentId),
            ))
            .getSingleOrNull();
    if (already != null) {
      throw const VideoCourseException('Vous avez déjà ce cours.');
    }

    final id = _uuid.v4();
    final commission = course.price - AppConstants.videoCourseNet(course.price);

    await _db.transaction(() async {
      await _db
          .into(_db.coursePurchases)
          .insert(
            CoursePurchasesCompanion.insert(
              id: id,
              courseId: courseId,
              parentId: parentId,
              amount: course.price,
              commission: Value(commission),
              dirty: const Value(true),
            ),
          );
      await (_db.update(
        _db.videoCourses,
      )..where((t) => t.id.equals(courseId))).write(
        VideoCoursesCompanion(
          purchaseCount: Value(course.purchaseCount + 1),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
    });

    await _sync.enqueue(
      entity: 'course_purchase',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'courseId': courseId,
        'parentId': parentId,
        'amount': course.price,
        'commission': commission,
      },
    );
    return id;
  }

  /// Ce qu'un professeur a gagné, commission déduite.
  Future<int> earningsOf(String teacherId) async {
    final row = await _db
        .customSelect(
          '''
      SELECT COALESCE(SUM(p.amount - p.commission), 0) AS net
      FROM course_purchases p
      JOIN video_courses c ON c.id = p.course_id
      WHERE c.teacher_id = ?1
      ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {_db.coursePurchases, _db.videoCourses},
        )
        .getSingle();
    return row.read<int>('net');
  }
}
