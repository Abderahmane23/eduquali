/// Ce qui s'est mal passé pendant le démarrage.
///
/// Signalé le 25/09 : « l'apk ne se lance pas, il montre le logo ». Ce logo
/// est celui du lanceur Android — `main()` attendait trois opérations avant
/// `runApp`, sans délai maximal et sans rattrapage. Une seule qui ne rend
/// pas la main, et l'application entière reste sur l'écran de lancement du
/// système : pas de message, pas de bouton, rien à raconter au support.
///
/// Un téléphone n'est pas un poste de développement : le magasin de clés
/// peut être cassé par une restauration de sauvegarde, la mémoire peut
/// manquer au milieu d'une transaction, un dossier de données peut être
/// illisible. Aucune de ces pannes ne doit empêcher l'application de
/// s'ouvrir et de dire ce qu'elle a.
library;

import 'dart:async';

/// Une étape de démarrage qui a échoué.
class StartupIssue {
  const StartupIssue({
    required this.step,
    required this.message,
    required this.fatal,
  });

  /// Le nom lisible de l'étape : « base de données », « stockage sécurisé ».
  final String step;

  /// Le message de l'erreur, tel quel. Il est montré à l'écran parce que
  /// c'est la seule chose qu'un utilisateur puisse nous rapporter, et qu'une
  /// phrase rassurante à la place ne se diagnostique pas.
  final String message;

  /// Vrai quand l'application ne peut pas fonctionner sans cette étape.
  ///
  /// La base en fait partie : sans elle, il n'y a ni référentiel, ni compte,
  /// ni offre. Le stockage sécurisé, non : il ne porte qu'un identifiant
  /// d'appareil, qu'on sait remplacer pour la session.
  final bool fatal;

  @override
  String toString() => '$step : $message';
}

/// L'état du démarrage, passé à l'application.
class StartupReport {
  const StartupReport(this.issues);

  const StartupReport.ok() : issues = const [];

  final List<StartupIssue> issues;

  bool get isClean => issues.isEmpty;

  /// Vrai si une étape indispensable a échoué : l'application s'ouvre, mais
  /// sur un écran qui explique, pas sur un accueil vide qui laisserait
  /// croire qu'il n'y a simplement aucun professeur.
  bool get isBroken => issues.any((i) => i.fatal);
}

/// Exécute une étape de démarrage sans jamais laisser l'application coincée.
///
/// Trois issues et trois seulement : l'étape réussit, elle échoue, ou elle
/// dépasse son délai. Dans les trois cas la fonction rend la main et le
/// démarrage continue — c'est tout l'intérêt.
///
/// Le délai dépasse n'annule pas l'opération : rien ne permet d'interrompre
/// une écriture SQLite ou un appel au magasin de clés depuis Dart. Elle
/// continue dans son coin et son résultat est ignoré. Ce qui compte est que
/// l'écran, lui, ne l'attende plus.
Future<void> runStartupStep(
  String nom,
  List<StartupIssue> problemes, {
  required bool fatal,
  required Duration delai,
  required Future<void> Function() action,
}) async {
  try {
    await action().timeout(delai);
  } on TimeoutException {
    problemes.add(
      StartupIssue(
        step: nom,
        message: 'Pas de réponse après ${delai.inSeconds} secondes.',
        fatal: fatal,
      ),
    );
  } catch (erreur) {
    // Le message part tel quel vers l'écran : reformulé, il ne se
    // diagnostique plus.
    problemes.add(StartupIssue(step: nom, message: '$erreur', fatal: fatal));
  }
}
