import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

/// Les points de fidélité et les concours, côté serveur uniquement.
///
/// --- Pourquoi rien n'est calculé ici -------------------------------------
///
/// Le reste de l'application lit la base locale et se synchronise. Les points,
/// non : **le solde est la somme d'un journal que le serveur seul écrit.**
///
/// Le calculer ici, même « pour l'affichage », créerait deux chiffres pour la
/// même question — celui du téléphone et celui de la base — et c'est toujours
/// celui du téléphone qu'on croirait, puisque c'est celui qu'on voit. Le jour
/// où un gain arrive pendant qu'on est hors ligne, l'élève verrait un solde
/// faux et conclurait qu'on lui a pris des points.
///
/// Même raison pour le classement : un rang se calcule sur les copies de tous
/// les autres, que le téléphone ne voit pas et ne doit pas voir.
///
/// Conséquence assumée : **ces écrans ne fonctionnent pas hors ligne.** Ils le
/// disent, au lieu de montrer un zéro qui ressemble à une réponse.
class PointsApi {
  PointsApi(this._dio);

  final Dio _dio;

  /// Le solde, tel que le serveur le somme.
  Future<PointsBalance> balance() async =>
      PointsBalance.fromJson(await _objet('/points/balance'));

  /// L'historique : chaque ligne dit pourquoi elle existe.
  Future<List<PointEntry>> ledger() async =>
      PointEntry.listFromJson(await _objet('/points/ledger'));

  Future<List<Contest>> contests() async =>
      Contest.listFromJson(await _objet('/contests'));

  Future<Leaderboard> leaderboard(String contestId) async =>
      Leaderboard.fromJson(await _objet('/contests/$contestId/leaderboard'));

  /// Le catalogue, le solde et la distance au lot suivant, en un seul appel.
  ///
  /// Trois appels pour peindre un ecran, sur une connexion guineenne, ce sont
  /// trois occasions de l'afficher a moitie.
  Future<Shop> shop() async => Shop.fromJson(await _objet('/shop/items'));

  /// Echange des points contre un lot.
  ///
  /// Rend l'identifiant de la demande. Leve une [PointsApiException] portant le
  /// message du serveur quand c'est refuse — « Il vous manque des points pour
  /// ce lot. » est deja ecrit pour l'eleve, on le relaie tel quel.
  Future<String> redeem(String itemId) async {
    final corps = await _poster('/shop/items/$itemId/redeem');
    return (corps['redemptionId'] ?? '').toString();
  }

  /// Les lots mis de cote, avec leur fiche.
  Future<List<ShopItem>> favorites() async {
    final corps = await _objet('/shop/favorites');
    return [
      for (final lot
          in (corps['items'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        // Le serveur rend la fiche du lot sans `favorite` : par construction,
        // tout ce qui sort d'ici en est un.
        ShopItem.fromJson({...lot, 'favorite': true}),
    ];
  }

  /// Met un lot de cote, ou l'en retire.
  ///
  /// Deux verbes plutot qu'une bascule : un telephone qui reessaie apres une
  /// coupure ne doit pas eteindre le coeur qu'il venait d'allumer.
  Future<bool> setFavorite(String itemId, {required bool on}) async {
    final corps = on
        ? await _appel(
            () =>
                _dio.put<Map<String, dynamic>>('/shop/items/$itemId/favorite'),
          )
        : await _appel(
            () => _dio.delete<Map<String, dynamic>>(
              '/shop/items/$itemId/favorite',
            ),
          );
    return corps['favorite'] == true;
  }

  Future<Map<String, dynamic>> _poster(String chemin) =>
      _appel(() => _dio.post<Map<String, dynamic>>(chemin));

  Future<Map<String, dynamic>> _objet(String chemin) =>
      _appel(() => _dio.get<Map<String, dynamic>>(chemin));

  Future<Map<String, dynamic>> _appel(
    Future<Response<Map<String, dynamic>>> Function() requete,
  ) async {
    try {
      final reponse = await requete();
      final corps = reponse.data;
      if (corps == null) {
        throw const PointsApiException('Le serveur a répondu sans contenu.');
      }
      return corps;
    } on DioException catch (erreur) {
      if (erreur.error is BackendUnavailable) {
        throw const PointsApiException(
          'Les points et le classement ont besoin du serveur, qui n’est pas '
          'encore en ligne.',
          offline: true,
        );
      }
      final corps = erreur.response?.data;
      if (corps is Map && corps['error'] is String) {
        throw PointsApiException(corps['error'] as String);
      }
      throw PointsApiException(
        switch (erreur.type) {
          DioExceptionType.connectionError =>
            'Serveur injoignable. Vérifiez votre connexion.',
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout => 'Délai dépassé. Réessayez.',
          _ => 'Le serveur n’a pas pu traiter la demande.',
        },
        offline:
            erreur.type == DioExceptionType.connectionError ||
            erreur.type == DioExceptionType.connectionTimeout,
      );
    }
  }
}

class PointsApiException implements Exception {
  const PointsApiException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  @override
  String toString() => message;
}

/// Lecture tolerante : une cle absente vaut zero.
///
/// Le serveur peut gagner un champ avant que l'APK ne soit remplace — et l'APK
/// circule par Bluetooth, donc une version ancienne tourne forcement quelque
/// part. Une lecture stricte ferait planter l'ecran sur un champ nouveau.
int _entier(Object? v) => (v as num?)?.toInt() ?? 0;

class PointsBalance {
  const PointsBalance({required this.balance, required this.entries});

  factory PointsBalance.fromJson(Map<String, dynamic> json) => PointsBalance(
    balance: _entier(json['balance']),
    entries: _entier(json['entries']),
  );

  final int balance;
  final int entries;
}

class PointEntry {
  const PointEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.createdAt,
  });

  factory PointEntry.fromJson(Map<String, dynamic> json) => PointEntry(
    id: (json['id'] ?? '').toString(),
    delta: _entier(json['delta']),
    reason: (json['reason'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.now(),
  );

  static List<PointEntry> listFromJson(Map<String, dynamic> json) => [
    for (final ligne
        in (json['entries'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>())
      PointEntry.fromJson(ligne),
  ];

  final String id;

  /// Positif pour un gain, négatif pour une dépense. Jamais nul — la base le
  /// refuse.
  final int delta;

  /// Pourquoi, en clair. C'est la seule question que l'élève posera.
  final String reason;

  final DateTime createdAt;
}

class Contest {
  const Contest({
    required this.id,
    required this.title,
    required this.pointsPrize,
    required this.state,
    required this.closesAt,
  });

  factory Contest.fromJson(Map<String, dynamic> json) => Contest(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    pointsPrize: _entier(json['points_prize']),
    // `CLOSED` par defaut : une valeur inconnue ne doit pas ouvrir un concours.
    state: (json['state'] ?? 'CLOSED').toString(),
    closesAt:
        DateTime.tryParse((json['closes_at'] ?? '').toString()) ??
        DateTime.now(),
  );

  static List<Contest> listFromJson(Map<String, dynamic> json) => [
    for (final ligne
        in (json['contests'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>())
      Contest.fromJson(ligne),
  ];

  final String id;
  final String title;
  final int pointsPrize;

  /// `UPCOMING` | `OPEN` | `CLOSED`, décidé par le serveur.
  ///
  /// Pas déduit des dates ici : l'horloge d'un téléphone guinéen d'occasion est
  /// souvent fausse de plusieurs heures, et un concours s'ouvrirait ou se
  /// fermerait au mauvais moment selon l'appareil.
  final String state;

  final DateTime closesAt;

  bool get isOpen => state == 'OPEN';
}

class PodiumPlace {
  const PodiumPlace({
    required this.rank,
    required this.score,
    required this.firstName,
  });

  factory PodiumPlace.fromJson(Map<String, dynamic> json) => PodiumPlace(
    rank: _entier(json['rank']),
    score: _entier(json['score']),
    firstName: (json['firstName'] ?? 'Participant').toString(),
  );

  final int rank;
  final int score;
  final String firstName;
}

class Leaderboard {
  const Leaderboard({
    required this.published,
    required this.participants,
    required this.missing,
    required this.podium,
    this.myRank,
    this.myScore,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    final moi = json['me'] as Map<String, dynamic>?;
    return Leaderboard(
      // `published` strictement vrai : tout le reste laisse le podium ferme.
      // Un podium ouvert par defaut annoncerait un classement national sur
      // trois copies.
      published: json['published'] == true,
      participants: _entier(json['participants']),
      missing: _entier(json['missing']),
      myRank: (moi?['rank'] as num?)?.toInt(),
      myScore: (moi?['score'] as num?)?.toInt(),
      podium: [
        for (final place
            in (json['podium'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>())
          PodiumPlace.fromJson(place),
      ],
    );
  }

  /// Faux tant qu'il n'y a pas assez de copies rendues.
  ///
  /// Un « classement national » à quatre participants n'est pas une
  /// approximation, c'est une affirmation fausse sur le pays.
  final bool published;

  final int participants;

  /// Combien de copies encore avant l'ouverture du podium.
  final int missing;

  final List<PodiumPlace> podium;

  /// Toujours rendu quand on a participé, publié ou non : c'est ce qu'on vient
  /// chercher, et il est honnête quel que soit le nombre de participants.
  final int? myRank;
  final int? myScore;
}

/// Un lot de la boutique.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.image,
    required this.pointsPrice,
    required this.valueGnf,
    required this.stock,
    required this.affordable,
    this.summary,
    this.favorite = false,
    this.kind = 'DIRECT',
    this.entries = 0,
    this.drawsAt,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    summary: json['summary']?.toString(),
    image: (json['image'] ?? '').toString(),
    pointsPrice: _entier(json['points_price']),
    valueGnf: _entier(json['value_gnf']),
    stock: _entier(json['stock']),
    // Jamais deduit du solde ici : c'est le serveur qui tranche, et lui seul
    // connait le solde reel. Le recalculer afficherait « echanger » sur un lot
    // que le serveur refusera.
    affordable: json['affordable'] == true,
    favorite: json['favorite'] == true,
    // `DIRECT` par defaut : un genre inconnu ne doit pas transformer un achat
    // en pari.
    kind: (json['kind'] ?? 'DIRECT').toString(),
    entries: _entier(json['entries']),
    drawsAt: DateTime.tryParse((json['draws_at'] ?? '').toString()),
  );

  final String id;
  final String name;
  final String? summary;

  /// Le nom de base de l'illustration, sans densite ni extension.
  final String image;

  final int pointsPrice;

  /// Ordre de grandeur en francs, affiche a cote du prix en points : « 30 000
  /// points » seul ne veut rien dire.
  final int valueGnf;

  final int stock;

  /// Vrai quand le solde suffit. Vient du serveur.
  final bool affordable;

  /// Mis de cote. Vient du serveur, comme le reste : un favori suit le compte,
  /// pas l'appareil — l'APK se reinstalle souvent.
  final bool favorite;

  /// `DIRECT` : les points achetent l'objet.
  /// `RAFFLE` : ils achetent une chance.
  ///
  /// Un telephone a 8 000 000 GNF ne s'achete pas avec la fidelite d'un seul
  /// eleve ; le tirage change la promesse de « travaillez 1 850 seances » a
  /// « l'un de vous le gagnera », qui est vraie.
  final String kind;

  /// Mes mises en cours sur ce tirage. Miser trois fois donne trois chances.
  final int entries;

  /// Quand le sort tranche. Affichee : une attente devient un rendez-vous.
  final DateTime? drawsAt;

  bool get isRaffle => kind == 'RAFFLE';

  /// Le meme lot, coeur allume ou eteint. Pour peindre le changement avant que
  /// le serveur ne reponde, sans recharger toute la liste.
  ShopItem withFavorite(bool valeur) => ShopItem(
    id: id,
    name: name,
    summary: summary,
    image: image,
    pointsPrice: pointsPrice,
    valueGnf: valueGnf,
    stock: stock,
    affordable: affordable,
    favorite: valeur,
    kind: kind,
    entries: entries,
    drawsAt: drawsAt,
  );

  bool get inStock => stock > 0;

  /// Vrai quand le lot a une photo.
  ///
  /// Tous n'en ont pas, et c'est voulu : un forfait internet ou un mois
  /// d'abonnement n'est pas un objet qu'on photographie. Leur inventer une
  /// image produirait une vignette generique qui n'apprend rien ; une icone dit
  /// mieux de quoi il s'agit.
  bool get hasImage => image.trim().isNotEmpty;

  /// Le chemin de l'illustration embarquee.
  ///
  /// La version dense : les cartes font toute la largeur de l'ecran, et la
  /// version simple y serait floue.
  String get assetPath => 'assets/img/$image@2x.webp';
}

/// Le catalogue, le solde et la marche suivante.
class Shop {
  const Shop({
    required this.balance,
    required this.items,
    required this.missing,
    this.nextId,
  });

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
    balance: _entier(json['balance']),
    missing: _entier(json['missing']),
    nextId: json['nextId']?.toString(),
    items: [
      for (final lot
          in (json['items'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        ShopItem.fromJson(lot),
    ],
  );

  final int balance;
  final List<ShopItem> items;

  /// Le lot abordable suivant, et ce qu'il manque pour l'atteindre.
  ///
  /// « Encore 140 points » dit ce qu'un solde seul ne dit pas : si l'on
  /// progresse.
  final String? nextId;
  final int missing;
}
