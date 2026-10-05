/// Les cinq paliers d'études, lus depuis le référentiel partagé.
///
/// --- Pourquoi un fichier et non une table Drift ---------------------------
///
/// Cinq lignes, closes, qui ne changent pas à l'exécution. Une table aurait
/// demandé une version de schéma Drift de plus — avec sa migration et ses tests
/// de migration — pour des données que le référentiel déclare déjà. Les créneaux
/// horaires suivent la même règle (`core/scheduling/slots.dart`), et pour la
/// même raison.
///
/// --- Pourquoi ils ne sont pas écrits dans les parcours --------------------
///
/// Ils l'étaient, et c'était le défaut : le parcours enseignant les recopiait en
/// dur à quatre valeurs — sans « diplômé » — tandis que les parcours parent et
/// étudiant proposaient les seize classes à plat. Un parent d'élève de CE2
/// faisait défiler jusqu'à « Master 2 ».
///
/// L'identifiant d'un palier **est** la valeur de `cycle` d'un niveau. C'est ce
/// qui permet à `optionsFilter` d'apparier le palier choisi et les classes
/// proposées ensuite, sans table de correspondance à tenir à jour.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

const String catalogAssetPath = 'assets/seed/catalog.json';

class Stage {
  const Stage({
    required this.id,
    required this.name,
    required this.order,
    required this.hasClasses,
    this.groupingLevelId,
    this.note,
  });

  /// `PRIMAIRE` | `COLLEGE` | `LYCEE` | `SUPERIEUR` | `DIPLOME`.
  final String id;
  final String name;
  final int order;

  /// Le niveau d'en-tête du cycle — `lvl_primaire`, `lvl_college`…
  ///
  /// C'est le niveau à retenir quand [hasClasses] est faux : le primaire et
  /// « diplômé » ne demandent pas de classe, et sans lui l'apprenant serait
  /// enregistré sans aucun niveau. Nul pour `SUPERIEUR` : « université » n'est
  /// pas une classe, et le palier y est toujours suivi d'un choix.
  final String? groupingLevelId;

  /// Faux pour le primaire et pour « diplômé » : il n'y a pas de classe à
  /// choisir ensuite. Le référentiel ne détaille pas les six années du primaire,
  /// et un diplômé n'est dans aucune classe — poser la question obligerait à
  /// inventer une réponse.
  final bool hasClasses;

  final String? note;

  factory Stage.fromJson(Map<String, dynamic> json) => Stage(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    order: switch (json['order']) {
      final int i => i,
      final num n => n.round(),
      _ => 99,
    },
    hasClasses: json['hasClasses'] == true,
    groupingLevelId: switch (json['groupingLevelId']) {
      final String s when s.trim().isNotEmpty => s,
      _ => null,
    },
    note: switch (json['note']) {
      final String s when s.trim().isNotEmpty => s,
      _ => null,
    },
  );
}

List<Stage>? _cache;

/// Charge les paliers depuis les ressources embarquées.
Future<List<Stage>> loadStages({AssetBundle? bundle}) async {
  final dejaLu = _cache;
  if (dejaLu != null) return dejaLu;

  final brut = await (bundle ?? rootBundle).loadString(catalogAssetPath);
  final donnees = jsonDecode(brut) as Map<String, dynamic>;
  final liste =
      (donnees['stages'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Stage.fromJson)
          .where((s) => s.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  _cache = liste;
  return liste;
}

/// Vide le cache. Réservé aux tests.
void resetStagesCacheForTests() => _cache = null;
