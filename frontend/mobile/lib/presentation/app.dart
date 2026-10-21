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
       * Le theme clair, et lui seul.
       *
       * --- Ce qui etait ecrit ici, et pourquoi c'etait faux --------------
       *
       * « Cahier par defaut, Tableau au choix de l'utilisateur — et le
       * reglage du telephone est ce choix. » L'intention etait bonne. Le
       * resultat ne l'etait pas : `theme` et `darkTheme` etaient fournis
       * **sans `themeMode`**, dont la valeur par defaut est
       * `ThemeMode.system`. Un telephone regle en sombre obtenait donc
       * `AppTheme.dark`, sans que rien ne le signale.
       *
       * Et la palette Tableau porte un vrai defaut de contraste. Rendue
       * cote a cote avec la claire (`tool/captures/theme_probe_test.dart`),
       * elle montre un champ de saisie ou le texte tape — « Aissatou » —
       * est a peine distinct du fond : on ecrit sans voir ce qu'on ecrit.
       * Le titre de l'ecran est dans le meme cas.
       *
       * Signale le 21/10 en trois fois — « les champs ont un fond noir »,
       * « le texte dedans est invisible », « le fond des pages est noir ».
       * Trois signalements, une seule cause.
       *
       * Aucune capture ne l'avait montre : toutes passent `AppTheme.light`
       * explicitement. Le defaut ne vivait que sur un vrai telephone, regle
       * en sombre.
       *
       * --- Pourquoi forcer plutot que corriger ---------------------------
       *
       * La charte EduQuali est une charte de papier : encre sur papier,
       * surligneur, marges. Le sombre en est une transposition, et elle
       * demande son propre travail de contraste — celui-la n'a pas ete
       * fait. Tant qu'il ne l'est pas, le proposer revient a offrir un
       * ecran ou l'on ne peut pas lire ce qu'on tape.
       *
       * `AppTheme.dark` reste : la charte l'eprouve (`charte_test.dart`),
       * et le travail n'est pas perdu. Il n'est simplement plus atteignable
       * depuis l'application. Le rebrancher demande d'abord de reprendre le
       * contraste de la palette Tableau — champ de saisie en premier.
       */
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
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
