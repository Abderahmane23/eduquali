import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../domain/usecases/subscription_rules.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Où en est une promotion.
enum PromotionStatus {
  draft('DRAFT', 'Brouillon'),
  active('ACTIVE', 'En ligne'),
  ended('ENDED', 'Terminée');

  const PromotionStatus(this.code, this.label);
  final String code;
  final String label;

  static PromotionStatus fromCode(String? code) => PromotionStatus.values
      .firstWhere((s) => s.code == code, orElse: () => draft);
}

class PromotionException implements Exception {
  const PromotionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// La formule en cours n'ouvre pas la mise en avant.
///
/// Distincte d'un refus ordinaire : celui-ci se rattrape en s'abonnant, et
/// l'ecran doit pouvoir proposer la formule plutot que d'afficher une phrase
/// et s'arreter la. Reconnaitre le cas au texte du message aurait tenu
/// jusqu'a la premiere reformulation.
class PromotionNeedsPlan extends PromotionException {
  const PromotionNeedsPlan(this.required)
    : super('La mise en avant fait partie de la formule Master.');

  /// La formule minimale qui l'ouvre.
  final SubscriptionPlan required;
}

/// Une promotion prête à afficher.
class PromotionItem {
  const PromotionItem({required this.row, required this.institutionName});

  final PromotionRow row;
  final String institutionName;

  String get id => row.id;
  String get title => row.title;
  PromotionStatus get status => PromotionStatus.fromCode(row.status);
  bool get isActive => status == PromotionStatus.active;

  List<String> get media => [
    for (final p in row.mediaPaths.split(','))
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

/// Les promotions d'établissement.
///
/// Un établissement est montré aux familles qui cherchent une école. C'était
/// facturé en crédits jusqu'au 25/09 ; c'est désormais ouvert par la formule
/// Master, comme le reste du produit.
class PromotionsRepository {
  PromotionsRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  Future<List<PromotionItem>> ofInstitution(String institutionId) =>
      _read('p.institution_id = ?1', institutionId);

  /// Les promotions visibles par une famille.
  Future<List<PromotionItem>> active() => _read("p.status = 'ACTIVE'", null);

  /// [value] est nul quand la condition ne porte aucun parametre : lier une
  /// variable qu'aucun `?1` n'attend fait echouer la requete.
  Future<List<PromotionItem>> _read(String where, String? value) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT p.*, i.name AS institution_name
      FROM promotions p
      JOIN institutions i ON i.id = p.institution_id
      WHERE $where
      ORDER BY p.created_at DESC
      ''',
          variables: [if (value != null) Variable<String>(value)],
          readsFrom: {_db.promotions, _db.institutions},
        )
        .get();

    return [
      for (final row in rows)
        PromotionItem(
          row: PromotionRow(
            id: row.read<String>('id'),
            institutionId: row.read<String>('institution_id'),
            title: row.read<String>('title'),
            message: row.read<String?>('message'),
            mediaPaths: row.read<String>('media_paths'),
            status: row.read<String>('status'),
            startsAt: row.read<DateTime?>('starts_at'),
            endsAt: row.read<DateTime?>('ends_at'),
            views: row.read<int>('views'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            version: row.read<int>('version'),
            deviceId: row.read<String?>('device_id'),
            dirty: row.read<bool>('dirty'),
          ),
          institutionName: row.read<String>('institution_name'),
        ),
    ];
  }

  /// Crée la promotion et la met en ligne.
  ///
  /// La formule est vérifiée ici, et pas seulement par l'écran : un contrôle
  /// qui ne vit que dans un bouton se contourne dès qu'un second appelant
  /// arrive, et c'est la règle qui décide de ce qui se vend.
  Future<String> publish({
    required String institutionId,
    required String ownerId,
    required String title,
    String? message,
    List<String> mediaPaths = const [],
    int durationDays = 30,
  }) async {
    if (title.trim().isEmpty) {
      throw const PromotionException('Donnez un titre à votre promotion.');
    }
    // Sans image ni vidéo, il n'y a rien à montrer : la promotion coûterait
    // une mise en avant pour une ligne de texte.
    if (mediaPaths.isEmpty) {
      throw const PromotionException('Ajoutez au moins une image ou vidéo.');
    }

    final requis = PaidFeature.promotion.requires;
    if (!(await _planOf(ownerId)).covers(requis)) {
      throw PromotionNeedsPlan(requis);
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    await _db
        .into(_db.promotions)
        .insert(
          PromotionsCompanion.insert(
            id: id,
            institutionId: institutionId,
            title: title.trim(),
            message: Value(message?.trim()),
            mediaPaths: Value(mediaPaths.join(',')),
            status: Value(PromotionStatus.active.code),
            startsAt: Value(now),
            endsAt: Value(now.add(Duration(days: durationDays))),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'promotion',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'institutionId': institutionId,
        'title': title.trim(),
        'mediaPaths': mediaPaths,
      },
    );
    return id;
  }

  Future<void> end(String promotionId) async {
    await (_db.update(
      _db.promotions,
    )..where((t) => t.id.equals(promotionId))).write(
      PromotionsCompanion(
        status: Value(PromotionStatus.ended.code),
        endsAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'promotion',
      entityId: promotionId,
      operation: SyncOperation.update,
      payload: {'status': PromotionStatus.ended.code},
    );
  }

  /// Un affichage de plus. C'est ce que l'établissement a acheté.
  Future<void> countView(String promotionId) async {
    await _db.customStatement(
      'UPDATE promotions SET views = views + 1 WHERE id = ?1',
      [promotionId],
    );
  }

  /// La formule du compte, expiration comprise : un abonnement échu ne doit
  /// pas continuer d'ouvrir ce qu'il ouvrait.
  Future<SubscriptionPlan> _planOf(String ownerId) async {
    final row = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(ownerId))).getSingleOrNull();
    if (row == null) return SubscriptionPlan.free;
    return effectivePlan(
      SubscriptionPlan.fromCode(row.plan),
      row.planRenewsAt,
      DateTime.now(),
    );
  }
}
