import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/presentation/controllers/onboarding_flow_controller.dart';

/// La carte « Élève ou étudiant » mène quelque part, des deux côtés.
///
/// --- Le défaut que ce fichier empêche ----------------------------------
///
/// « Parent d'élève » et « Universitaire » ont fusionné en une seule carte
/// le 18/10. Sa valeur, `FAMILY`, n'est pas un rôle : c'est la question
/// « Êtes-vous parent ? », posée juste après, qui la traduit en `PARENT` ou
/// `STUDENT`.
///
/// Le client web a été adapté le jour même. Le client mobile ne l'était
/// pas : `forRole('FAMILY')` rendait `null`, l'écran retournait en silence,
/// et le bouton « Continuer » ne faisait **rien**. Pas d'erreur, pas de
/// message — un parcours d'inscription qui s'arrête à la première page.
///
/// C'est la forme que prennent les pannes de ce projet, et c'est pourquoi
/// ce contrôle lit le JSON partagé plutôt qu'une liste écrite ici : une
/// cinquième carte ajoutée dans `shared/onboarding/intro.json` doit faire
/// échouer ce test, pas disparaître.
void main() {
  final intro =
      jsonDecode(
            File('assets/onboarding/intro.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map<String, dynamic>> etapes() => [
    for (final section in intro['sections'] as List)
      for (final etape in (section as Map<String, dynamic>)['steps'] as List)
        etape as Map<String, dynamic>,
  ];

  test('chaque carte proposée mène à un parcours', () {
    final cartes = [
      for (final etape in etapes())
        if (etape['type'] == 'role_select')
          for (final option in (etape['options'] as List? ?? const []))
            (option as Map<String, dynamic>)['value'] as String,
    ];

    expect(cartes, isNotEmpty, reason: 'aucune carte dans intro.json');

    for (final carte in cartes) {
      // On passe par `roleReel`, exactement comme l'écran.
      final reel = OnboardingAudience.roleReel({
        'role': carte,
        'is_parent': 'no',
      });
      expect(
        OnboardingAudience.forRole(reel),
        isNotNull,
        reason: '« $carte » est proposée mais ne mène à aucun parcours',
      );
    }
  });

  test('les deux réponses de « Êtes-vous parent ? » mènent quelque part', () {
    for (final reponse in ['yes', 'no']) {
      final reel = OnboardingAudience.roleReel({
        'role': 'FAMILY',
        'is_parent': reponse,
      });
      expect(
        OnboardingAudience.forRole(reel),
        isNotNull,
        reason: '« $reponse » ne mène à aucun parcours',
      );
    }

    expect(
      OnboardingAudience.roleReel({'role': 'FAMILY', 'is_parent': 'yes'}),
      'PARENT',
    );
    expect(
      OnboardingAudience.roleReel({'role': 'FAMILY', 'is_parent': 'no'}),
      'STUDENT',
    );
  });

  test('la question qui départage existe, et n’est posée qu’à la famille', () {
    final question = etapes().firstWhere(
      (e) => e['id'] == 'is_parent',
      orElse: () => <String, dynamic>{},
    );
    expect(
      question,
      isNotEmpty,
      reason: 'sans cette étape, la carte FAMILY ne se traduit jamais',
    );

    // Un professeur ne doit pas se voir demander s'il est parent.
    final condition = question['showIf'] as Map<String, dynamic>?;
    expect(condition?['field'], 'role');
    expect(condition?['equals'], contains('FAMILY'));
  });

  /// Les écrans de promesse ont été retirés le 18/10 : on vérifie qu'ils ne
  /// reviennent pas par une resynchronisation.
  test('le parcours commence par une question, pas par une promesse', () {
    final promesses = [
      for (final etape in etapes())
        if (etape['type'] == 'statement') etape['id'] as String,
    ];
    expect(
      promesses,
      isEmpty,
      reason:
          'écrans de promesse revenus dans intro.json : '
          '${promesses.join(', ')}',
    );
  });
}
