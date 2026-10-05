import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/common.dart';

/// Écran 1 — Splash (§55).
///
/// Attend la restauration de session puis oriente vers l'espace adapte.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideRoute());
  }

  Future<void> _decideRoute() async {
    // Laisse le temps a la restauration de session de se résoudre.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final session = ref.read(currentSessionProvider);
    if (!mounted) return;

    if (session == null) {
      // L'écran d'action, et non la connexion. Demander un numéro de
      // téléphone à quelqu'un qui ne sait pas encore ce que l'application
      // contient, c'est réclamer avant d'avoir montré. La connexion reste à
      // un geste de là, pour ceux qui reviennent.
      context.go(Routes.landing);
      return;
    }

    context.go(Routes.homeFor(session.role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // La marque, et non plus une toque generique de la bibliotheque
            // d'icones : c'est le premier ecran, et il annonce l'application
            // qu'on vient d'ouvrir.
            const AppLogo.mark(size: 84),
            const Gap(AppSpacing.xl),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Gap(AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Vérifier • Évaluer • Recruter',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Gap(AppSpacing.section),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
