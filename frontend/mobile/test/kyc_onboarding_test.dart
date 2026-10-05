import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/security/capture_analyzer.dart';

void main() {
  group('Controles de capture (§6)', () {
    test('le selfie exige une confirmation de presence', () {
      expect(CaptureTarget.selfie.requiresLiveness, isTrue);
      expect(CaptureTarget.idFront.requiresLiveness, isFalse);
    });

    test('les criteres se valident dans l’ordre attendu', () async {
      final analyzer = SimulatedCaptureAnalyzer(
        stepDuration: const Duration(milliseconds: 10),
      );
      addTearDown(analyzer.dispose);

      final states = await analyzer
          .watch(CaptureTarget.selfie)
          .take(5)
          .toList();

      // Premier etat : aucun critere satisfait.
      expect(states.first.satisfiedCount, 0);
      expect(states.first.ready, isFalse);

      // Chaque etat satisfait un critere de plus que le precedent.
      for (var i = 1; i < states.length; i++) {
        expect(
          states[i].satisfiedCount,
          states[i - 1].satisfiedCount + 1,
          reason: 'la progression doit etre monotone, sans clignotement',
        );
      }

      expect(states.last.ready, isTrue);
      expect(states.last.hint, 'Ne bougez plus…');
    });

    test(
      'un document est juge sur sa nettete, pas sur un clignement',
      () async {
        final analyzer = SimulatedCaptureAnalyzer(
          stepDuration: const Duration(milliseconds: 10),
        );
        addTearDown(analyzer.dispose);

        // Etat initial, puis un evenement par critere satisfait.
        final last = await analyzer.watch(CaptureTarget.idFront).take(5).last;
        final labels = last.checks.map((c) => c.label).toList();

        expect(labels, contains('Nettete suffisante'));
        expect(labels, isNot(contains('Presence confirmee')));
        expect(last.ready, isTrue);
      },
    );

    test('la consigne affichee est celle du premier critere manquant', () {
      const readiness = CaptureReadiness(
        target: CaptureTarget.selfie,
        checks: [
          CaptureCheck(label: 'Visage detecte', satisfied: true, hint: 'a'),
          CaptureCheck(label: 'Eclairage', satisfied: false, hint: 'b'),
          CaptureCheck(label: 'Cadrage', satisfied: false, hint: 'c'),
        ],
      );

      expect(readiness.hint, 'b');
      expect(readiness.ready, isFalse);
      expect(readiness.progress, closeTo(1 / 3, 0.001));
    });
  });
}
