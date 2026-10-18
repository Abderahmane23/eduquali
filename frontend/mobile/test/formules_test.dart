import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/usecases/subscription_rules.dart';

/// Les formules vendues, et ce qu'elles ouvrent.
///
/// Les valeurs viennent de `shared/formules/formules.json`, que lit aussi
/// l'epreuve jumelle du serveur (`backend/api/_lib/formules.test.ts`). Un
/// prix change d'un seul cote fait echouer l'autre : un ecran qui annonce
/// 100 000 GNF pendant que le serveur en demande 50 000 est pire qu'un
/// ecran sans prix — la personne decouvre l'ecart au moment de payer.
void main() {
  final partage =
      jsonDecode(
            File('../../shared/formules/formules.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  final formules = (partage['formules'] as List).cast<Map<String, dynamic>>();

  SubscriptionPlan parCode(String code) =>
      SubscriptionPlan.values.firstWhere((p) => p.code == code);

  Periode periodeDe(String nom) => switch (nom) {
    'jour' => Periode.jour,
    'quinzaine' => Periode.quinzaine,
    'mois' => Periode.mois,
    _ => Periode.jamais,
  };

  Ressource ressourceDe(String nom) => switch (nom) {
    'assistant' => Ressource.assistant,
    'direct' => Ressource.direct,
    _ => Ressource.cours,
  };

  test('les prix et les noms sont ceux du fichier partage', () {
    for (final attendue in formules) {
      final plan = parCode(attendue['code'] as String);
      // Le telephone peut porter un libelle a lui, et un seul le fait :
      // « Basic » pour le gratuit, parce que « Gratuit » a cote du titre de
      // l'assistant se lisait comme la promesse que l'assistant l'etait. La
      // difference est consignee dans le fichier partage, et elle ne porte
      // que sur un mot affiche — jamais sur un prix ni sur un quota.
      final attenduNom = attendue['nomMobile'] ?? attendue['nom'];
      expect(plan.label, attenduNom, reason: attendue['code'] as String);
      expect(
        plan.monthlyPriceGnf,
        attendue['prixGnf'],
        reason: attendue['code'] as String,
      );
    }
  });

  test('les quotas sont ceux du fichier partage', () {
    for (final attendue in formules) {
      final plan = parCode(attendue['code'] as String);
      final quotas = quotasDe(plan);
      final voulus = (attendue['quotas'] as Map).cast<String, dynamic>();

      for (final entree in voulus.entries) {
        final quota = quotas[ressourceDe(entree.key)]!;
        final voulu = (entree.value as Map).cast<String, dynamic>();
        expect(
          quota.max,
          voulu['max'],
          reason: '${attendue['code']}.${entree.key}.max',
        );
        expect(
          quota.periode,
          periodeDe(voulu['periode'] as String),
          reason: '${attendue['code']}.${entree.key}.periode',
        );
      }
    }
  });

  test('l’essai dure sept jours, et garde le plafond de l’assistant', () {
    expect(joursEssai, partage['joursEssai']);
    expect(assistantParJour, partage['assistantParJour']);
    expect(quotasEssai[Ressource.assistant]!.max, partage['assistantParJour']);
    // Tout le reste est ouvert pendant l'essai.
    expect(quotasEssai[Ressource.direct]!.max, isNull);
    expect(quotasEssai[Ressource.cours]!.max, isNull);
  });

  group('L’essai', () {
    final inscription = DateTime.utc(2026, 10, 1, 10);

    test('dure sept jours pleins', () {
      expect(dansLEssai(inscription, DateTime.utc(2026, 10, 7, 23)), isTrue);
      expect(dansLEssai(inscription, DateTime.utc(2026, 10, 8, 11)), isFalse);
    });

    test('un jour entame compte pour un jour entier', () {
      // Vingt-cinq heures restantes : deux jours, pas un.
      expect(
        joursDEssaiRestants(inscription, DateTime.utc(2026, 10, 7, 9)),
        2,
      );
      expect(
        joursDEssaiRestants(inscription, DateTime.utc(2026, 10, 7, 11)),
        1,
      );
      expect(joursDEssaiRestants(inscription, DateTime.utc(2026, 10, 20)), 0);
    });

    test('s’applique a un compte neuf, et cede ensuite au gratuit', () {
      final pendant = quotasEffectifs(
        plan: SubscriptionPlan.free,
        renouvelleLe: null,
        creeLe: inscription,
        maintenant: DateTime.utc(2026, 10, 3),
      );
      expect(pendant[Ressource.direct]!.max, isNull);

      final apres = quotasEffectifs(
        plan: SubscriptionPlan.free,
        renouvelleLe: null,
        creeLe: inscription,
        maintenant: DateTime.utc(2026, 10, 20),
      );
      expect(apres[Ressource.direct]!.max, 1);
      expect(apres[Ressource.cours]!.max, 1);
    });

    test('une formule payante sans echeance ne vaut rien', () {
      // Sinon il suffirait d'ecrire le plan dans la base locale du
      // telephone — qui est modifiable par qui tient l'appareil.
      final quotas = quotasEffectifs(
        plan: SubscriptionPlan.master,
        renouvelleLe: null,
        creeLe: DateTime.utc(2026, 1, 1),
        maintenant: DateTime.utc(2026, 10, 15),
      );
      expect(quotas[Ressource.direct]!.max, 1);
    });
  });

  test('un compteur absurde ne donne pas de quota en plus', () {
    expect(restantSur(const Quota(4, Periode.mois), -5), 4);
    expect(restantSur(const Quota(4, Periode.mois), 9), 0);
    expect(restantSur(const Quota(null, Periode.jamais), 9), isNull);
  });
}
