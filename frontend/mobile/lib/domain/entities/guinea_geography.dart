/// Le découpage administratif de la Guinée, tel que le décrit
/// `shared/geography/guinea.json`.
///
/// La liste n'est pas écrite dans le code : elle bouge (Siguiri et Beyla sont
/// des régions récentes, plusieurs préfectures ont été créées), et deux copies
/// finiraient par ne plus dire la même chose. Le fichier partagé est recopié
/// dans les deux clients par `shared/onboarding/sync.mjs`.
class GuineaGeography {
  const GuineaGeography(this.regions);

  final List<GeoRegion> regions;

  static const asset = 'assets/geography/guinea.json';

  factory GuineaGeography.fromJson(Map<String, dynamic> json) =>
      GuineaGeography([
        for (final region in (json['regions'] as List<dynamic>? ?? const []))
          GeoRegion.fromJson(region as Map<String, dynamic>),
      ]);

  /// Toutes les subdivisions, région d'origine comprise.
  List<GeoDivision> get divisions => [
    for (final region in regions) ...region.divisions,
  ];

  GeoRegion? region(String? code) =>
      regions.where((r) => r.code == code).firstOrNull;

  /// « Ratoma, Conakry » — ce qu'on affiche sur une fiche.
  String? describe({String? regionCode, String? divisionName}) {
    final name = region(regionCode)?.name;
    final parts = [
      if (divisionName != null && divisionName.trim().isNotEmpty)
        divisionName.trim(),
      if (name != null && name != divisionName) name,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// Une région administrative. Conakry en est une à part : elle se découpe en
/// communes, pas en préfectures.
class GeoRegion {
  const GeoRegion({
    required this.code,
    required this.name,
    required this.kind,
    required this.divisionKind,
    required this.divisions,
  });

  final String code;
  final String name;

  /// `REGION`, ou `SPECIALE` pour Conakry.
  final String kind;

  /// `PREFECTURE`, ou `COMMUNE` pour Conakry.
  final String divisionKind;

  final List<GeoDivision> divisions;

  bool get isSpecial => kind == 'SPECIALE';

  /// « communes » ou « préfectures », pour l'écrire dans une phrase.
  String get divisionLabel =>
      divisionKind == 'COMMUNE' ? 'Commune' : 'Préfecture';

  factory GeoRegion.fromJson(Map<String, dynamic> json) => GeoRegion(
    code: json['code'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String? ?? 'REGION',
    divisionKind: json['divisionKind'] as String? ?? 'PREFECTURE',
    divisions: [
      for (final division in (json['divisions'] as List<dynamic>? ?? const []))
        GeoDivision.fromJson(
          division as Map<String, dynamic>,
          regionCode: json['code'] as String,
        ),
    ],
  );
}

/// Une préfecture, ou une commune pour Conakry.
class GeoDivision {
  const GeoDivision({
    required this.code,
    required this.name,
    required this.regionCode,
    this.recent = false,
  });

  final String code;
  final String name;
  final String regionCode;

  /// Préfecture créée récemment. L'écran le signale : beaucoup de gens la
  /// rattachent encore à son ancienne préfecture et la cherchent ailleurs.
  final bool recent;

  factory GeoDivision.fromJson(
    Map<String, dynamic> json, {
    required String regionCode,
  }) => GeoDivision(
    code: json['code'] as String,
    name: json['name'] as String,
    regionCode: regionCode,
    recent: json['recent'] as bool? ?? false,
  );
}
