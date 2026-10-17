import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/startup_report.dart';
import 'router/app_router.dart';
import 'screens/shared/startup_failure_screen.dart';
import 'theme/app_theme.dart';

class EduqualiApp extends ConsumerWidget {
  const EduqualiApp({super.key, this.startup = const StartupReport.ok()});

  /// Ce que le demarrage a rencontre. Vide dans le cas normal.
  final StartupReport startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une etape indispensable a echoue : l'application s'ouvre quand meme,
    // sur un ecran qui dit quoi. Router vers l'accueil afficherait des
    // listes vides, et l'on chercherait un probleme de donnees la ou il y a
    // un probleme de demarrage.
    if (startup.isBroken) return StartupFailureScreen(report: startup);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      /*
       * Les deux themes de la charte EduQuali.
       *
       * Cahier par defaut, Tableau au choix de l'utilisateur — et le reglage
       * du telephone **est** ce choix tant qu'il n'y a pas de selecteur dans
       * l'application. C'est ce que les gens attendent d'un telephone, et
       * c'est aussi ce que fait le site.
       *
       * Les deux sont construits par la meme fonction, a partir de deux
       * palettes : ajouter un composant au theme le dote des deux d'un coup,
       * et il n'y a pas d'endroit ou l'oublier.
       */
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // La mise a l'échelle du texte est bornée pour preserver la
        // hierarchie visuelle sur les appareils a grands reglages (§54).
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
