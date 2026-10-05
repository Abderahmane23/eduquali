import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/presentation/widgets/common.dart';
import 'package:veriprof/presentation/widgets/dashboard.dart';

/// Les tuiles de chiffres, posées dans la liste d'un tableau de bord.
///
/// Signalé sur l'APK du 23/09 : les trois tableaux de bord ne s'affichaient
/// plus, débordaient de l'écran, et un clic dans le vide en haut de page
/// ouvrait « Paiements ». Une seule cause aux trois : dans une liste, la
/// hauteur disponible est infinie, et une `Row` en `stretch` impose cette
/// hauteur infinie à ses enfants. Les tuiles étaient donc dessinées hors de
/// l'écran, en gardant leur zone de clic.
void main() {
  /// Le tableau de bord tel qu'il est vraiment : des tuiles dans une liste.
  Future<void> poser(WidgetTester tester, StatRow row) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ListView(children: [row])),
    ),
  );

  testWidgets('deux tuiles tiennent dans la liste, sans hauteur infinie', (
    tester,
  ) async {
    await poser(
      tester,
      const StatRow(
        tiles: [
          StatTile(value: '1 500 000 GNF', label: 'Encaissé ce mois'),
          StatTile(value: '42', label: 'Vues de mon profil'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);

    final hauteur = tester.getSize(find.byType(StatRow)).height;
    expect(hauteur.isFinite, isTrue);
    expect(hauteur, lessThan(600));
  });

  testWidgets('les deux tuiles ont la même hauteur', (tester) async {
    await poser(
      tester,
      const StatRow(
        tiles: [
          // La première porte une précision, la seconde non : sans mise à
          // la même hauteur, la paire est visiblement bancale.
          StatTile(
            value: '450 000 GNF',
            label: 'Coût mensuel',
            hint: '12 j pour recruter',
          ),
          StatTile(value: '3', label: 'Postes pourvus'),
        ],
      ),
    );

    final tuiles = tester
        .widgetList<StatTile>(find.byType(StatTile))
        .map((t) => tester.getSize(find.byWidget(t)).height)
        .toList();
    expect(tuiles, hasLength(2));
    expect(tuiles.first, tuiles.last);
  });

  testWidgets('un montant long rétrécit au lieu de déborder', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await poser(
      tester,
      const StatRow(
        tiles: [
          // Un vrai montant guinéen : les salaires s'écrivent en millions.
          StatTile(value: '12 500 000 GNF', label: 'Encaissé ce mois'),
          StatTile(value: '128', label: 'Vues de mon profil'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);

    // Le `FittedBox` reduit a la peinture, pas a la mise en page : le `Text`
    // garde sa largeur naturelle et c'est la boite qui l'ecrase. Comparer les
    // deux prouve donc a la fois que la reduction etait necessaire et qu'elle
    // a bien eu lieu.
    final boite = find.ancestor(
      of: find.text('12 500 000 GNF'),
      matching: find.byType(FittedBox),
    );
    final place = tester.getSize(boite).width;
    final naturelle = tester.getSize(find.text('12 500 000 GNF')).width;

    expect(naturelle, greaterThan(place), reason: 'le montant devait rétrécir');
    expect(
      place,
      lessThanOrEqualTo(tester.getSize(find.byType(StatTile).first).width),
    );
  });
}
