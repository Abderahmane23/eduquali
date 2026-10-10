import 'package:dio/dio.dart';

/// Les promotions d'établissement, vues du côté de qui les regarde.
///
/// --- Pourquoi le serveur choisit ----------------------------------------
///
/// Deux règles vivent là-bas, et aucune ne doit se recopier ici :
///
///   * **la formule décide.** Une promotion ne s'affiche qu'aux comptes
///     `FREE` — payer, c'est ne plus voir de publicité, et c'est ce qui donne
///     une raison de passer à une formule payante. Lire la formule dans le
///     client la rendrait contournable ;
///   * **l'ordre est une règle produit** : la moins vue d'abord, pour qu'une
///     promotion achetée ne reste pas derrière une autre indéfiniment.
class PromotionsApi {
  PromotionsApi(this._dio);

  final Dio _dio;

  /// Ce qu'il y a à montrer. Vide pour un compte payant — et c'est normal.
  Future<List<PromotionAd>> feed() async {
    try {
      final reponse = await _dio.get<Map<String, dynamic>>('/promotions/feed');
      final data = reponse.data ?? const {};
      return [
        for (final ligne
            in (data['promotions'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>())
          PromotionAd.fromJson(ligne),
      ];
    } on DioException {
      // Sans serveur ou sans réseau, il n'y a pas de publicité : ce n'est pas
      // une panne à signaler, c'est une absence de contenu.
      return const [];
    }
  }

  /// Annonce un affichage.
  ///
  /// Le serveur compte **une vue par personne et par jour** : rouvrir l'onglet
  /// ne gonfle rien. L'échec est avalé — un compteur manqué n'est pas une
  /// raison de déranger quelqu'un, et « Affichages » reste un ordre de
  /// grandeur, pas une facture.
  Future<void> recordView(String promotionId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/promotions/$promotionId/view');
    } on DioException {
      // Silencieux, à dessein.
    }
  }
}

/// Une promotion prête à afficher.
class PromotionAd {
  const PromotionAd({
    required this.id,
    required this.title,
    required this.institutionName,
    this.message,
    this.image,
    this.institutionCity,
    this.institutionType,
  });

  factory PromotionAd.fromJson(Map<String, dynamic> json) => PromotionAd(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    institutionName: (json['institutionName'] ?? 'Établissement').toString(),
    message: json['message']?.toString(),
    image: json['image']?.toString(),
    institutionCity: json['institutionCity']?.toString(),
    institutionType: json['institutionType']?.toString(),
  );

  final String id;
  final String title;
  final String institutionName;
  final String? message;

  /// Le premier média seulement : une carte n'affiche qu'une image, et
  /// télécharger le reste coûterait pour rien sur une connexion lente.
  final String? image;
  final String? institutionCity;

  /// `SCHOOL`, `HIGH_SCHOOL`, `UNIVERSITY`… Sert au ciblage, pas à l'affichage.
  final String? institutionType;
}
