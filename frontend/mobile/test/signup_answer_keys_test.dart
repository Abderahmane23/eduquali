import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chaque clé lue à la fin d'une inscription est une clé qu'un parcours écrit.
///
/// --- Le défaut que ce fichier fige --------------------------------------
///
/// `SignupCompletion.attachLearner` lisait `child_level_id`, `child_filiere_id`
/// et `child_subject_ids`. Aucune des trois n'était jamais écrite : les étapes
/// s'appellent `child_level_class`, `child_filiere` et `child_subjects`, et une
/// réponse est indexée par l'identifiant de son étape.
///
/// Conséquence : chaque enfant naissait sans niveau, sans profil et sans
/// matière. Un parent répondait à quatre questions dont les réponses étaient
/// jetées, et aucun écran ne pouvait ensuite filtrer les professeurs par cycle —
/// il n'y avait pas de cycle enregistré.
///
/// --- Pourquoi rien ne le signalait --------------------------------------
///
/// Les deux côtés étaient cohérents avec eux-mêmes. Le parcours savait poser ses
/// questions, le code savait lire une réponse absente — `as String?` rend `null`
/// sans se plaindre — et rien ne vérifiait que les deux parlaient des mêmes
/// clés. C'est le même raisonnement que « chaque variable lue est posée » pour
/// `userId`, et « chaque entité poussée est connue » pour `/sync/push`,
/// appliqué aux réponses d'inscription.
void main() {
  /// Les clés que le code lit dans les réponses.
  Set<String> luesParLeCode() {
    final source = File(
      'lib/presentation/screens/onboarding/signup_completion.dart',
    ).readAsStringSync();

    final vues = <String>{};
    // `answers['ma_cle']` et le raccourci `text('ma_cle')`.
    for (final motif in [
      RegExp(r"""answers\[\s*'([a-z_]+)'\s*\]"""),
      RegExp(r"""\btext\(\s*'([a-z_]+)'"""),
    ]) {
      for (final trouve in motif.allMatches(source)) {
        vues.add(trouve.group(1)!);
      }
    }

    // Les clés construites par préfixe — `answers['${prefixe}level_class']` —
    // se lisent sous leurs deux formes, celle du parent et celle de la personne
    // qui s'inscrit pour elle-même. Les deux doivent exister.
    for (final motif in [
      RegExp(r"""answers\[\s*'\$\{prefixe\}([a-z_]+)'\s*\]"""),
    ]) {
      for (final trouve in motif.allMatches(source)) {
        vues.add(trouve.group(1)!);
        vues.add('child_${trouve.group(1)!}');
      }
    }
    return vues;
  }

  /// Les clés qu'au moins un parcours produit.
  ///
  /// Trois sources, et il faut les trois : l'`id` d'un champ de formulaire, le
  /// `fieldId` d'une étape de choix quand elle en déclare un — `child_level_class`
  /// range sa réponse sous `child_level_id` — et l'`id` de l'étape sinon.
  ///
  /// Ne lire que les deux dernières était le défaut de la première version de ce
  /// fichier : elle signalait comme orphelines des clés parfaitement écrites, ce
  /// qui est la pire sorte de contrôle — il accuse du code juste.
  Set<String> ecritesParLesParcours() {
    final produites = <String>{};
    for (final fichier in Directory('assets/onboarding').listSync()) {
      if (!fichier.path.endsWith('.json')) continue;
      final json =
          jsonDecode(File(fichier.path).readAsStringSync())
              as Map<String, dynamic>;

      for (final section in (json['sections'] as List? ?? const [])) {
        for (final etape in ((section as Map)['steps'] as List? ?? const [])) {
          final map = etape as Map;
          final declare = (map['fieldId'] ?? '').toString();
          produites.add(
            declare.isEmpty ? (map['id'] ?? '').toString() : declare,
          );
          for (final champ in (map['fields'] as List? ?? const [])) {
            produites.add(((champ as Map)['id'] ?? '').toString());
          }
        }
      }
    }
    produites.remove('');
    return produites;
  }

  /// Ce qu'on lit en sachant qu'aucun parcours ne le demande — avec la raison.
  ///
  /// Une liste, pas une exception silencieuse : chaque entrée est une question
  /// qu'on a choisi de ne pas poser, et le jour où on la pose, la ligne part.
  // Vide depuis le 04/10 : `institution_type` en était la seule entrée, et la
  // question est désormais posée — une liste déroulante juste après le nom de
  // l'établissement. Tant qu'elle manquait, toute université était enregistrée
  // « école ».
  //
  // La carte reste là, et avec elle le contrôle du dessous : c'est elle qui
  // force à écrire la raison le jour où l'on choisira de lire une clé sans la
  // demander.
  const toleres = <String, String>{};

  test('aucune clé n’est lue sans qu’un parcours l’écrive', () {
    final lues = luesParLeCode();
    final ecrites = ecritesParLesParcours();

    // Le contrôle ne vaut que s'il a vraiment trouvé des clés des deux côtés :
    // deux ensembles vides passeraient sans rien prouver.
    expect(lues.length, greaterThan(8), reason: 'clés lues non détectées');
    expect(ecrites.length, greaterThan(20), reason: 'parcours non lus');

    final orphelines =
        lues.difference(ecrites).where((c) => !toleres.containsKey(c)).toList()
          ..sort();
    expect(
      orphelines,
      isEmpty,
      reason:
          'ces clés sont lues à la fin de l’inscription et aucun parcours ne '
          'les écrit : ${orphelines.join(', ')}. La réponse vaudra toujours '
          'null, sans erreur. Corriger le nom, ajouter l’étape, ou inscrire la '
          'clé dans « toleres » avec sa raison.',
    );
  });

  test('chaque tolérance porte encore sur une clé réellement absente', () {
    // Sinon la liste survit à sa raison d'être : une étape finit par poser la
    // question, la clé devient lisible, et la tolérance continue d'excuser un
    // problème qui n'existe plus.
    final ecrites = ecritesParLesParcours();
    for (final cle in toleres.keys) {
      expect(
        ecrites,
        isNot(contains(cle)),
        reason:
            '« $cle » est maintenant écrite par un parcours : retirer sa ligne '
            'de « toleres ».',
      );
    }
  });

  test('le niveau de l’apprenant est bien parmi elles', () {
    // Les trois clés précises dont l'absence a coûté le niveau de chaque
    // enfant. Le contrôle général ci-dessus les couvre, celui-ci les nomme —
    // pour qu'un renommage dise lequel.
    final ecrites = ecritesParLesParcours();
    // Les noms sous lesquels les réponses sont RANGÉES (`fieldId`), et non les
    // identifiants d'étape : c'est la confusion exacte qui a coûté l'apprenant
    // du compte universitaire.
    for (final cle in [
      'child_level_stage',
      'child_level_id',
      'child_subject_ids',
      'level_stage',
      'level_id',
      'subject_ids',
    ]) {
      expect(ecrites, contains(cle), reason: '« $cle » a disparu des parcours');
    }
  });
}
