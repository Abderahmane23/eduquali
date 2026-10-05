import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/presentation/widgets/common.dart';
import 'package:veriprof/presentation/widgets/interactions.dart';

/// Les micro-interactions.
///
/// Elles ne doivent surtout pas coûter une correction : un appui qui compte
/// double, une carte qui reste enfoncée, un téléphone qui vibre pendant un
/// défilement.
void main() {
  /// Les vibrations demandées au système pendant un test.
  List<String> captureHaptics(WidgetTester tester) {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add('${call.arguments}');
        }
        return null;
      },
    );
    return calls;
  }

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('L’appui', () {
    testWidgets('part exactement une fois', (tester) async {
      // Une carte portait un `Pressable` **et** un `InkWell`, chacun avec
      // son détecteur de tap : deux concurrents dans l'arène des gestes.
      var taps = 0;
      await tester.pumpWidget(
        host(AppCard(onTap: () => taps++, child: const Text('Carte'))),
      );

      await tester.tap(find.text('Carte'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('la carte s’enfonce puis se relève', (tester) async {
      await tester.pumpWidget(
        host(AppCard(onTap: () {}, child: const Text('Carte'))),
      );

      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale;

      expect(scale(), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Carte')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(scale(), lessThan(1), reason: 'la carte ne s’enfonce pas');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(), 1, reason: 'la carte reste enfoncée');
    });

    testWidgets('un geste annulé relève la carte', (tester) async {
      // Commencer un appui puis faire défiler ne doit pas laisser la carte
      // écrasée derrière soi.
      var taps = 0;
      await tester.pumpWidget(
        host(AppCard(onTap: () => taps++, child: const Text('Carte'))),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Carte')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
        1,
      );
      expect(taps, 0, reason: 'un défilement a compté comme un appui');
    });

    testWidgets('une carte sans action ne bouge pas', (tester) async {
      await tester.pumpWidget(host(const AppCard(child: Text('Carte'))));
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });

  group('Le retour haptique', () {
    testWidgets('accompagne la sélection', (tester) async {
      final haptics = captureHaptics(tester);
      await tester.pumpWidget(
        host(
          Pressable(onTap: () {}, haptic: true, child: const Text('Choisir')),
        ),
      );

      await tester.tap(find.text('Choisir'));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
    });

    testWidgets('se tait quand on ne le demande pas', (tester) async {
      // Faire vibrer le téléphone à chaque geste fatigue, et l'utilisateur
      // finit par couper le vibreur — perdant les vibrations utiles.
      final haptics = captureHaptics(tester);
      await tester.pumpWidget(
        host(Pressable(onTap: () {}, child: const Text('Ouvrir'))),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('ne part pas sur un geste annulé', (tester) async {
      final haptics = captureHaptics(tester);
      await tester.pumpWidget(
        host(
          Pressable(onTap: () {}, haptic: true, child: const Text('Choisir')),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Choisir')),
      );
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(haptics, isEmpty, reason: 'le défilement fait vibrer');
    });
  });

  group('Le squelette de chargement', () {
    testWidgets('il respire, et s’arrête proprement', (tester) async {
      await tester.pumpWidget(host(const SkeletonBox(width: 100)));

      // `MaterialApp` pose ses propres transitions : on vise celle du
      // squelette, la plus profonde.
      final fade = find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(FadeTransition),
      );
      final before = tester.widget<FadeTransition>(fade).opacity.value;
      await tester.pump(const Duration(milliseconds: 550));
      final after = tester.widget<FadeTransition>(fade).opacity.value;
      expect(after, isNot(before), reason: 'le squelette ne bouge pas');

      // Retirer le widget doit libérer le contrôleur : une animation qui
      // tourne dans le vide vide la batterie.
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpAndSettle();
    });
  });

  group('Le mouvement réduit', () {
    /// L'application, avec le réglage système « supprimer les animations ».
    Widget sansMouvement(Widget child) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('la carte ne se met plus à l’échelle', (tester) async {
      // Les vertiges d'origine vestibulaire ne sont pas une préférence
      // esthétique.
      await tester.pumpWidget(
        sansMouvement(AppCard(onTap: () {}, child: const Text('Carte'))),
      );
      expect(find.byType(AnimatedScale), findsNothing);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('mais elle répond encore au doigt', (tester) async {
      // On n'éteint pas tout : le retour reste nécessaire. L'opacité n'est
      // pas du mouvement au sens de la WCAG.
      await tester.pumpWidget(
        sansMouvement(AppCard(onTap: () {}, child: const Text('Carte'))),
      );

      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(opacity(), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Carte')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(opacity(), lessThan(1), reason: 'la carte ne répond plus');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('l’haptique survit', (tester) async {
      final haptics = captureHaptics(tester);
      await tester.pumpWidget(
        sansMouvement(
          Pressable(onTap: () {}, haptic: true, child: const Text('Choisir')),
        ),
      );
      await tester.tap(find.text('Choisir'));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
    });

    testWidgets('le squelette cesse de pulser', (tester) async {
      // Une pulsation sans fin est exactement la « décoration en boucle »
      // qu'on déconseille.
      await tester.pumpWidget(sansMouvement(const SkeletonBox(width: 100)));
      expect(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      // `pumpAndSettle` n'aboutirait jamais si une animation tournait.
      await tester.pumpAndSettle();
    });
  });

  group('Le chargement ne clignote pas', () {
    Widget gate({required bool loading}) => MaterialApp(
      home: Scaffold(
        body: LoadingGate(
          loading: loading,
          placeholder: const Text('squelette'),
          child: const Text('contenu'),
        ),
      ),
    );

    testWidgets('rien pendant les 300 premières millisecondes', (tester) async {
      // Une lecture de la base locale prend souvent moins que ça : montrer
      // puis retirer un squelette donne l'impression que quelque chose a
      // raté.
      await tester.pumpWidget(gate(loading: true));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('squelette'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('squelette'), findsOneWidget);
      await tester.pumpWidget(gate(loading: false));
      await tester.pumpAndSettle();
    });

    testWidgets('un chargement bref ne montre jamais de squelette', (
      tester,
    ) async {
      await tester.pumpWidget(gate(loading: true));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(gate(loading: false));
      await tester.pump();

      expect(find.text('squelette'), findsNothing);
      expect(find.text('contenu'), findsOneWidget);
    });

    testWidgets('une fois affiché, il reste le temps d’être lu', (
      tester,
    ) async {
      await tester.pumpWidget(gate(loading: true));
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.text('squelette'), findsOneWidget);

      // Les données arrivent tout de suite après : le squelette ne doit pas
      // disparaître dans le même souffle.
      await tester.pumpWidget(gate(loading: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('squelette'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('contenu'), findsOneWidget);
    });
  });

  group('Les squelettes épousent leur écran', () {
    testWidgets('celui d’un tableau de bord a le bon nombre de lignes', (
      tester,
    ) async {
      // Un modèle générique annonce une forme qui n'arrivera pas, et
      // l'écran saute au moment des données.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: const SkeletonDashboard(cards: [2, 4])),
        ),
      );
      // Deux titres de carte, plus deux lignes puis quatre, chacune faite
      // de deux barres.
      expect(find.byType(SkeletonBox), findsNWidgets(2 + (2 + 4) * 2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('celui du calendrier montre ses jours', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonCalendar())),
      );
      expect(find.byType(SkeletonBox), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('La coche de validation', () {
    testWidgets('elle n’accuse pas un champ encore vide', (tester) async {
      await tester.pumpWidget(
        host(const ValidatedSuffix(valid: false, visible: false)),
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('elle apparaît quand la saisie devient valable', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ValidatedSuffix(valid: true)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
