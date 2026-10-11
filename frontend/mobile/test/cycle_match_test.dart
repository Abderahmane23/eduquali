import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/usecases/cycle_match.dart';

/// « Pas de professeur d'université pour un élève de 7ème » (note du 02/10).
///
/// La règle tient en une ligne, mais ses trois cas limites décident de ce qu'une
/// famille voit — et deux d'entre eux décident de ce qu'elle ne voit PAS, ce qui
/// ne se remarque jamais à l'usage. D'où un test par cas.
void main() {
  /// Un professeur réduit à ce dont la règle a besoin.
  ({String nom, Set<String> cycles}) prof(String nom, Set<String> cycles) =>
      (nom: nom, cycles: cycles);

  List<({String nom, Set<String> cycles})> filtre(
    List<({String nom, Set<String> cycles})> profs,
    String? palier,
  ) => teachersForCycle(profs, learnerCycle: palier, cyclesOf: (p) => p.cycles);

  final universitaire = prof('Diallo', {'SUPERIEUR'});
  final college = prof('Camara', {'COLLEGE'});
  final polyvalent = prof('Barry', {'COLLEGE', 'LYCEE'});
  final sansCycle = prof('Sow', const {});

  test('un collégien ne voit pas le professeur d’université', () {
    final vus = filtre([universitaire, college, polyvalent], 'COLLEGE');
    expect(vus.map((p) => p.nom), ['Camara', 'Barry']);
  });

  test('un universitaire ne voit pas le professeur de collège', () {
    // La règle marche dans les deux sens : l'inverse était tout aussi faux,
    // simplement moins visible — un étudiant de L2 à qui l'on propose un
    // professeur de 8ème.
    final vus = filtre([universitaire, college], 'SUPERIEUR');
    expect(vus.map((p) => p.nom), ['Diallo']);
  });

  test('un professeur sans cycle déclaré est écarté', () {
    /*
     * La règle disait l'inverse jusqu'au 11/10, et sa raison était bonne :
     * l'écarter le faisait disparaître de toutes les familles sans que rien ne
     * le lui signale.
     *
     * Elle tenait parce que l'inscription **jetait** les niveaux déclarés — un
     * professeur avait un profil vide sans y être pour rien. Ce n'est plus le
     * cas : l'inscription les enregistre et `POST /teacher/competences` les
     * pousse. Un profil vide veut maintenant dire que l'étape a été sautée, et
     * la barre de complétion du profil le dit.
     *
     * Le garder coûtait plus cher : un parent de CE2 voyait un chargé de cours
     * de L3 dans la première liste du produit.
     */
    expect(filtre([sansCycle], 'COLLEGE'), isEmpty);
  });

  test('sans palier connu, rien n’est filtré', () {
    // Un apprenant dont le niveau n'est pas enregistré verrait sinon une liste
    // vide et conclurait qu'il n'y a aucun professeur dans sa ville.
    for (final palier in [null, '', '  ']) {
      expect(
        filtre([universitaire, college, sansCycle], palier),
        hasLength(3),
        reason: 'palier « $palier » ne doit rien écarter',
      );
    }
  });

  test('la liste garde son ordre', () {
    // Le classement par compatibilité est calculé en amont ; un filtre qui
    // réordonne le détruirait sans que personne ne s'en aperçoive.
    final vus = filtre([polyvalent, sansCycle, college], 'LYCEE');
    // « Sow » ne déclare aucun cycle : il est désormais écarté, et le
    // contrôle porte sur ce qui reste — l'ordre d'origine.
    expect(vus.map((p) => p.nom), ['Barry']);
  });

  group('faut-il annoncer le filtre', () {
    test('oui quand il écarte quelqu’un', () {
      expect(
        cycleFilterBites(
          [universitaire, college],
          learnerCycle: 'COLLEGE',
          cyclesOf: (p) => p.cycles,
        ),
        isTrue,
      );
    });

    test('non quand il n’écarte personne', () {
      // Annoncer un filtre qui ne retire rien apprend à l'ignorer, et la fois
      // où il compte, il ne se lit plus.
      expect(
        cycleFilterBites(
          [college, polyvalent],
          learnerCycle: 'COLLEGE',
          cyclesOf: (p) => p.cycles,
        ),
        isFalse,
      );
    });
  });
}
