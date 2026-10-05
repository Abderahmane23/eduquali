import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

class ChildException implements Exception {
  const ChildException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Les enfants d'un parent.
///
/// Seul point d'écriture de la table `children` : l'inscription et le profil
/// passent tous deux par ici, sinon la fiche créée à l'inscription et celle
/// modifiée plus tard finiraient par ne pas avoir la même forme.
class ChildrenRepository {
  ChildrenRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  Future<List<ChildRow>> of(String parentId) =>
      (_db.select(_db.children)
            ..where((t) => t.parentId.equals(parentId))
            ..orderBy([(t) => OrderingTerm.asc(t.firstName)]))
          .get();

  Future<String> add({
    required String parentId,
    required String firstName,
    String? lastName,
    String? levelId,
    String? filiereId,
    String? schoolName,
    List<String> subjectIds = const [],
  }) async {
    final name = firstName.trim();
    if (name.isEmpty) {
      throw const ChildException('Indiquez le prénom de l’enfant.');
    }

    final id = _uuid.v4();
    await _db
        .into(_db.children)
        .insert(
          ChildrenCompanion.insert(
            id: id,
            parentId: parentId,
            firstName: name,
            lastName: Value(_clean(lastName)),
            levelId: Value(levelId),
            filiereId: Value(filiereId),
            schoolName: Value(_clean(schoolName)),
            subjectIds: Value(subjectIds.join(',')),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'child',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'parentId': parentId,
        'firstName': name,
        'lastName': lastName,
        'levelId': levelId,
        'filiereId': filiereId,
        'schoolName': schoolName,
        'subjectIds': subjectIds,
      },
    );
    return id;
  }

  Future<void> update({
    required String childId,
    required String firstName,
    String? lastName,
    String? levelId,
    String? filiereId,
    String? schoolName,
    List<String> subjectIds = const [],
  }) async {
    final name = firstName.trim();
    if (name.isEmpty) {
      throw const ChildException('Indiquez le prénom de l’enfant.');
    }

    await (_db.update(_db.children)..where((t) => t.id.equals(childId))).write(
      ChildrenCompanion(
        firstName: Value(name),
        lastName: Value(_clean(lastName)),
        levelId: Value(levelId),
        filiereId: Value(filiereId),
        schoolName: Value(_clean(schoolName)),
        subjectIds: Value(subjectIds.join(',')),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    await _sync.enqueue(
      entity: 'child',
      entityId: childId,
      operation: SyncOperation.update,
      payload: {
        'firstName': name,
        'lastName': lastName,
        'levelId': levelId,
        'filiereId': filiereId,
        'schoolName': schoolName,
        'subjectIds': subjectIds,
      },
    );
  }

  /// Retire un enfant.
  ///
  /// Refusé s'il reste des demandes en cours : le professeur ou
  /// l'établissement les verrait pointer vers un enfant disparu.
  Future<ChildRow> remove(String childId) async {
    final pending = await _db
        .customSelect(
          '''
      SELECT COUNT(*) AS n FROM tutoring_requests
      WHERE child_id = ?1 AND status IN ('SENT', 'ACCEPTED')
      ''',
          variables: [Variable<String>(childId)],
          readsFrom: {_db.tutoringRequests},
        )
        .getSingle();

    if (pending.read<int>('n') > 0) {
      throw const ChildException(
        'Annulez d’abord les demandes de cours en cours pour cet enfant.',
      );
    }

    final row = await (_db.select(
      _db.children,
    )..where((t) => t.id.equals(childId))).getSingle();

    await (_db.delete(_db.children)..where((t) => t.id.equals(childId))).go();
    await _sync.enqueue(
      entity: 'child',
      entityId: childId,
      operation: SyncOperation.delete,
      payload: const {},
    );
    return row;
  }

  /// Remet une fiche retiree, telle qu'elle etait.
  ///
  /// La meme ligne, le meme identifiant : les demandes passees qui la
  /// designent la retrouvent. Une fiche recreee a la main porterait un
  /// nouvel identifiant et les laisserait pointer dans le vide.
  Future<void> restore(ChildRow child) async {
    await _db
        .into(_db.children)
        .insert(child, mode: InsertMode.insertOrReplace);
    await _sync.enqueue(
      entity: 'child',
      entityId: child.id,
      operation: SyncOperation.create,
      payload: {
        'parentId': child.parentId,
        'firstName': child.firstName,
        'lastName': child.lastName,
        'levelId': child.levelId,
        'filiereId': child.filiereId,
        'schoolName': child.schoolName,
        'subjectIds': split(child.subjectIds),
      },
    );
  }

  static List<String> split(String raw) => [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
