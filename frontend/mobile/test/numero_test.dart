import 'dart:convert';
import 'dart:io';

import 'package:veriprof/data/remote/supabase_auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le numero qui identifie un compte.
///
/// Le tableau des formes vient de `shared/identite/numeros.json`, et pas de ce
/// fichier. L'epreuve jumelle du web (`src/api/numero.test.ts`) lit le meme
/// fichier : c'est la seule facon de garantir que les deux formules disent la
/// meme chose. Deux formules qui divergent feraient deux comptes pour une
/// personne, et ce serait invisible jusqu'au jour ou elle change d'appareil.
void main() {
  final table =
      jsonDecode(
            File('../../shared/identite/numeros.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  final domaine = table['_domaine'] as String;
  final memePersonne = table['meme_personne'] as Map<String, dynamic>;
  final national = memePersonne['national'] as String;
  final saisies = (memePersonne['saisies'] as List).cast<String>();

  test('toutes les facons de taper un numero donnent la meme adresse', () {
    final attendue = '$national@$domaine';
    final obtenues = saisies.map(SupabaseAuthApi.emailFor).toSet();

    expect(obtenues, {attendue});
    expect(saisies.length, greaterThan(5));
  });

  /// L'epreuve qui aurait attrape le defaut. On la garde nommee d'apres lui,
  /// pour qu'une regression se lise comme le retour de ce bug precis.
  test('un numero colle avec son indicatif ne cree pas un second compte', () {
    expect(
      SupabaseAuthApi.emailFor('+224620000101'),
      SupabaseAuthApi.emailFor('620000101'),
    );
    expect(
      SupabaseAuthApi.emailFor('0620000101'),
      SupabaseAuthApi.emailFor('620000101'),
    );
  });

  test('un numero de neuf chiffres n est jamais rogne', () {
    for (final cas in (table['intouchables']
        as Map<String, dynamic>)['cas'] as List) {
      final c = cas as Map<String, dynamic>;
      expect(
        SupabaseAuthApi.numeroNational(c['saisi'] as String),
        c['national'] as String,
        reason: 'saisie ${c['saisi']}',
      );
    }
  });
}
