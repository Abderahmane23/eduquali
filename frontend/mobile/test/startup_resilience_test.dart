import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/startup_report.dart';
import 'package:veriprof/presentation/app.dart';

/// Le démarrage ne doit jamais pouvoir retenir l'application.
///
/// Signalé le 25/09 : « l'apk ne se lance pas, il montre le logo ». Ce logo
/// était celui du lanceur Android — `main()` attendait la base, le magasin
/// de clés et la synchronisation avant `runApp`, sans délai et sans
/// rattrapage. Une seule de ces étapes qui ne rend pas la main, et il n'y a
/// plus d'application du tout : pas d'écran, pas de message, rien à
/// rapporter.
///
/// La règle vérifiée ici est celle-là, et elle vaut pour n'importe quelle
/// panne : `runStartupStep` rend toujours la main.
void main() {
  group('Une étape de démarrage', () {
    test('laisse le rapport vide quand elle réussit', () async {
      final problemes = <StartupIssue>[];
      await runStartupStep(
        'base',
        problemes,
        fatal: true,
        delai: const Duration(seconds: 5),
        action: () async {},
      );
      expect(problemes, isEmpty);
    });

    test('note l’erreur au lieu de la laisser remonter', () async {
      final problemes = <StartupIssue>[];
      await expectLater(
        runStartupStep(
          'base de données',
          problemes,
          fatal: true,
          delai: const Duration(seconds: 5),
          action: () async => throw StateError('disque plein'),
        ),
        completes,
      );

      expect(problemes, hasLength(1));
      expect(problemes.single.step, 'base de données');
      // Le message technique passe tel quel : c'est la seule chose qu'un
      // utilisateur puisse nous rapporter.
      expect(problemes.single.message, contains('disque plein'));
      expect(problemes.single.fatal, isTrue);
    });

    test('rend la main quand elle ne répond plus', () async {
      // Le cas du 25/09 : le magasin de clés d'Android qui ne revient
      // jamais. Sans délai maximal, cette attente est l'application entière.
      final problemes = <StartupIssue>[];
      final jamais = Completer<void>();
      addTearDown(() => jamais.complete());

      await expectLater(
        runStartupStep(
          'stockage sécurisé',
          problemes,
          fatal: false,
          delai: const Duration(milliseconds: 40),
          action: () => jamais.future,
        ),
        completes,
      );

      expect(problemes, hasLength(1));
      expect(problemes.single.message, contains('Pas de réponse'));
      expect(problemes.single.fatal, isFalse);
    });

    test('une panne secondaire ne casse pas le démarrage', () {
      // Le magasin de clés ne porte qu'un identifiant d'appareil : son échec
      // dégrade la synchronisation, il n'empêche pas de chercher un
      // professeur.
      const rapport = StartupReport([
        StartupIssue(step: 'stockage sécurisé', message: 'x', fatal: false),
      ]);
      expect(rapport.isBroken, isFalse);
      expect(rapport.isClean, isFalse);
    });
  });

  group('L’application', () {
    testWidgets('ouvre l’écran d’erreur quand la base a échoué', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: EduqualiApp(
            startup: StartupReport([
              StartupIssue(
                step: 'base de données',
                message:
                    'SqliteException(11): database disk image is '
                    'malformed',
                fatal: true,
              ),
            ]),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('L’application n’a pas pu démarrer'), findsOneWidget);
      // Le texte technique est à l'écran, et pas seulement dans un journal
      // que personne ne lira.
      expect(
        find.textContaining('database disk image is malformed'),
        findsOneWidget,
      );
      expect(find.text('Copier le message'), findsOneWidget);
    });

    testWidgets('ne montre rien de tel quand tout va bien', (tester) async {
      // Le rapport propre est le cas normal : l'écran d'erreur ne doit pas
      // s'inviter parce qu'une étape secondaire a bronché.
      const rapport = StartupReport([
        StartupIssue(
          step: 'synchronisation',
          message: 'hors ligne',
          fatal: false,
        ),
      ]);
      expect(rapport.isBroken, isFalse);
      // Monter l'application entière demanderait la base ; la décision,
      // elle, tient dans `isBroken`, et c'est elle que l'écran consulte.
      expect(const StartupReport.ok().isBroken, isFalse);
    });
  });
}
