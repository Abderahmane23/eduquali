import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/kyc_onboarding_controller.dart';
import '../../theme/app_theme.dart';
import 'kyc_capture_screen.dart';
import 'kyc_consent_screen.dart';
import 'kyc_review_screen.dart';

/// Conteneur du parcours de vérification d'identité (§6).
///
/// Une seule route porte l'ensemble du parcours : l'étape courante vit dans le
/// controleur, ce qui permet de revenir en arriere, de reprendre une capture ou
/// de sauter une étape sans empiler des routes.
class KycFlowScreen extends ConsumerWidget {
  const KycFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kycOnboardingProvider);
    final controller = ref.read(kycOnboardingProvider.notifier);
    final atStart = state.step == KycStep.consent;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (atStart || state.submitted) {
              Navigator.of(context).maybePop();
            } else {
              controller.back();
            }
          },
          tooltip: 'Retour',
        ),
        title: const Text('Vérification d’identité'),
        actions: [
          if (!state.submitted)
            TextButton(
              // Sortie de secours du mode démonstration : on quitte le
              // parcours sans rien transmettre.
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Quitter'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.section,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(state.step),
              child: switch (state.step) {
                KycStep.consent => const KycConsentScreen(),
                KycStep.review => const KycReviewScreen(),
                final step => KycCaptureScreen(step: step),
              },
            ),
          ),
        ),
      ),
    );
  }
}
