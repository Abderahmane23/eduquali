import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Ce avec quoi on paie, en Guinée.
///
/// L'argent mobile d'abord : c'est ce que les gens ont. La carte bancaire
/// vient après, et l'espèce reste, parce qu'une part des règlements se fait
/// encore de la main à la main.
enum PaymentKind {
  orangeMoney('ORANGE_MONEY', 'Orange Money'),
  mtnMomo('MTN_MOMO', 'MTN MoMo'),
  card('CARD', 'Carte bancaire'),
  cash('CASH', 'Espèces');

  const PaymentKind(this.code, this.label);
  final String code;
  final String label;

  /// Ce que l'application propose d'ajouter aujourd'hui : l'Orange Money, seul.
  ///
  /// L'inscription ne demande qu'un numéro Orange Money. Proposer quatre moyens
  /// ici contredisait cet écran-là : on donnait son numéro à l'inscription, puis
  /// son profil offrait une carte bancaire que rien n'encaisse.
  ///
  /// Les trois autres codes **restent** dans l'énumération : une ligne peut déjà
  /// les porter — un moyen enregistré avant cette simplification, ou créé depuis
  /// le site — et [fromCode] doit continuer à les lire. Les supprimer
  /// afficherait « Orange Money » au-dessus d'un numéro de carte.
  static const List<PaymentKind> offered = [orangeMoney];

  /// Vrai pour les moyens rattachés à un numéro de téléphone.
  bool get isMobileMoney =>
      this == PaymentKind.orangeMoney || this == PaymentKind.mtnMomo;

  static PaymentKind fromCode(String? code) => PaymentKind.values.firstWhere(
    (k) => k.code == code,
    orElse: () => orangeMoney,
  );
}

class PaymentMethodException implements Exception {
  const PaymentMethodException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Un moyen de paiement, prêt à afficher.
class PaymentMethodItem {
  const PaymentMethodItem(this.row);

  final PaymentMethodRow row;

  String get id => row.id;
  PaymentKind get kind => PaymentKind.fromCode(row.kind);
  bool get isDefault => row.isDefault;

  /// « Orange Money · •••• 4321 »
  String get display =>
      row.last4.isEmpty ? kind.label : '${kind.label} · •••• ${row.last4}';
}

/// Les moyens de paiement enregistrés.
///
/// **Aucun secret n'est stocké** : ni code, ni numéro complet. Seulement de
/// quoi reconnaître le moyen. L'encaissement réel passera par le serveur,
/// qui parle au fournisseur — un code de paiement dans une base locale que
/// l'APK transporte se lirait en quelques minutes.
class PaymentMethodsRepository {
  PaymentMethodsRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  Future<List<PaymentMethodItem>> of(String userId) async {
    final rows =
        await (_db.select(_db.paymentMethods)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.isDefault),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    return [for (final row in rows) PaymentMethodItem(row)];
  }

  /// Ajoute un moyen de paiement.
  ///
  /// [reference] est le numéro de téléphone ou de carte tel que saisi. Seuls
  /// ses quatre derniers chiffres sont conservés ; le reste n'est jamais
  /// écrit.
  Future<String> add({
    required String userId,
    required PaymentKind kind,
    String? holder,
    String reference = '',
    bool makeDefault = false,
  }) async {
    final digits = reference.replaceAll(RegExp(r'\D'), '');
    if (kind != PaymentKind.cash && digits.length < 4) {
      throw const PaymentMethodException(
        'Indiquez le numéro rattaché à ce moyen de paiement.',
      );
    }

    final id = _uuid.v4();
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : '';
    final first = (await of(userId)).isEmpty;

    await _db.transaction(() async {
      // Un seul moyen par défaut : deux se disputeraient l'écran de
      // paiement.
      if (makeDefault || first) {
        await (_db.update(_db.paymentMethods)
              ..where((t) => t.userId.equals(userId)))
            .write(const PaymentMethodsCompanion(isDefault: Value(false)));
      }
      await _db
          .into(_db.paymentMethods)
          .insert(
            PaymentMethodsCompanion.insert(
              id: id,
              userId: userId,
              kind: kind.code,
              holder: Value(holder?.trim()),
              last4: Value(last4),
              isDefault: Value(makeDefault || first),
              dirty: const Value(true),
            ),
          );
    });

    await _sync.enqueue(
      entity: 'payment_method',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'userId': userId,
        'kind': kind.code,
        'holder': holder,
        // Le numéro complet ne quitte jamais l'appareil.
        'last4': last4,
      },
    );
    return id;
  }

  Future<void> makeDefault({
    required String userId,
    required String methodId,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.paymentMethods)
            ..where((t) => t.userId.equals(userId)))
          .write(const PaymentMethodsCompanion(isDefault: Value(false)));
      await (_db.update(
        _db.paymentMethods,
      )..where((t) => t.id.equals(methodId))).write(
        PaymentMethodsCompanion(
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
    });
  }

  Future<void> remove({
    required String userId,
    required String methodId,
  }) async {
    final removed = await (_db.select(
      _db.paymentMethods,
    )..where((t) => t.id.equals(methodId))).getSingleOrNull();

    await (_db.delete(
      _db.paymentMethods,
    )..where((t) => t.id.equals(methodId))).go();

    // Retirer le moyen par défaut ne doit pas laisser le compte sans aucun :
    // le suivant prend la place.
    if (removed?.isDefault ?? false) {
      final rest = await of(userId);
      if (rest.isNotEmpty) {
        await makeDefault(userId: userId, methodId: rest.first.id);
      }
    }

    await _sync.enqueue(
      entity: 'payment_method',
      entityId: methodId,
      operation: SyncOperation.delete,
      payload: const {},
    );
  }
}
