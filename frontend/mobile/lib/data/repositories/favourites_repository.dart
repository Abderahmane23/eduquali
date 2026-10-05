import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Les professeurs mis de côté.
///
/// Une famille en compare trois ou quatre avant de choisir, un établissement
/// en retient une poignée avant d'ouvrir un poste. Sans cette liste, il faut
/// refaire la recherche à chaque fois et espérer retrouver la bonne fiche.
class FavouritesRepository {
  FavouritesRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  /// Les identifiants mis en favori par ce compte.
  ///
  /// Un ensemble plutôt qu'une liste : l'écran demande « celui-ci y est-il »,
  /// jamais « lequel est le troisième ».
  Future<Set<String>> of(String ownerId) async {
    final rows = await (_db.select(
      _db.favourites,
    )..where((t) => t.ownerId.equals(ownerId))).get();
    return {for (final r in rows) r.teacherId};
  }

  /// Met en favori, ou retire si c'était déjà le cas. Rend l'état final.
  ///
  /// Une seule méthode pour les deux sens : deux méthodes laisseraient
  /// l'écran décider laquelle appeler à partir d'un état qu'il croit connaître
  /// — et un double appui suffirait à les désynchroniser.
  Future<bool> toggle({
    required String ownerId,
    required String teacherId,
  }) async {
    final existing =
        await (_db.select(_db.favourites)..where(
              (t) => t.ownerId.equals(ownerId) & t.teacherId.equals(teacherId),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(
        _db.favourites,
      )..where((t) => t.id.equals(existing.id))).go();
      await _sync.enqueue(
        entity: 'favourite',
        entityId: existing.id,
        operation: SyncOperation.delete,
        payload: const {},
      );
      return false;
    }

    final id = _uuid.v4();
    await _db
        .into(_db.favourites)
        .insert(
          FavouritesCompanion.insert(
            id: id,
            ownerId: ownerId,
            teacherId: teacherId,
            dirty: const Value(true),
          ),
        );
    await _sync.enqueue(
      entity: 'favourite',
      entityId: id,
      operation: SyncOperation.create,
      // Le nom exact de la colonne : le serveur ne retient que les clés qui
      // portent celui d'une colonne autorisée, et refuse la charge dont il ne
      // reste rien. `teacherId` n'en était pas une.
      payload: {'teacher_id': teacherId},
    );
    return true;
  }

  /// Combien de comptes ont mis ce professeur de côté.
  ///
  /// Le chiffre lui est montré sur son propre profil : c'est le seul signal
  /// qui lui dise que sa fiche intéresse avant qu'on le contacte.
  Future<int> countFor(String teacherId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM favourites WHERE teacher_id = ?1',
          variables: [Variable<String>(teacherId)],
          readsFrom: {_db.favourites},
        )
        .getSingle();
    return row.read<int>('n');
  }
}
