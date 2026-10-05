import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../controllers/kyc_onboarding_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/capture_widgets.dart';
import '../../widgets/common.dart';

/// Recapitulatif du dossier avant transmission (§6).
///
/// En mode démonstration la transmission est simulee : rien ne quitte
/// l'appareil. L'écran indique explicitement ce qui manque, afin que l'écart
/// entre un dossier complet et un dossier partiel reste visible.
class KycReviewScreen extends ConsumerWidget {
  const KycReviewScreen({super.key});

  static const _captureSteps = [
    KycStep.selfie,
    KycStep.idFront,
    KycStep.idBack,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kycOnboardingProvider);
    final controller = ref.read(kycOnboardingProvider.notifier);
    final text = Theme.of(context).textTheme;

    if (state.submitted) {
      return _SubmittedView(onRestart: controller.reset);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepIndicator(current: 4, total: 4, label: 'Recapitulatif'),
        const Gap(AppSpacing.xl),
        Text('Vérifiez votre dossier', style: text.headlineSmall),
        const Gap(AppSpacing.sm),
        Text(
          state.isComplete
              ? 'Votre dossier est complet. Vous pouvez le transmettre.'
              : 'Certaines pieces manquent. Vous pouvez les ajouter maintenant '
                    'ou poursuivre et les fournir plus tard.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Gap(AppSpacing.xl),

        for (final step in _captureSteps) ...[
          _ReviewRow(
            step: step,
            result: state.resultFor(step),
            onRetake: () => controller.retake(step),
          ),
          const Gap(AppSpacing.md),
        ],

        const Gap(AppSpacing.md),
        if (!state.consentGiven)
          const InfoBanner(
            tone: StatusTone.warning,
            icon: Icons.privacy_tip_outlined,
            message:
                'Le consentement n’a pas ete recueilli. Il sera obligatoire '
                'avant toute transmission reelle.',
          ),
        if (!state.consentGiven) const Gap(AppSpacing.lg),

        const InfoBanner(
          tone: StatusTone.info,
          icon: Icons.cloud_off_outlined,
          title: 'Aucune transmission',
          message:
              'La vérification n’est pas encore branchee : le bouton ci-dessous '
              'simule l’envoi. Les images restent sur cet appareil.',
        ),
        const Gap(AppSpacing.xl),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: state.submitting
                ? null
                : () => controller.simulateSubmission(),
            child: state.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Simuler la transmission'),
          ),
        ),
        const Gap(AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => controller.goTo(KycStep.selfie),
            child: const Text('Reprendre les captures'),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.step,
    required this.result,
    required this.onRetake,
  });

  final KycStep step;
  final KycStepResult? result;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final document = result?.document;
    final provided = document != null;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: provided
                ? Image.file(File(document.path), fit: BoxFit.cover)
                : const Icon(
                    Icons.image_not_supported_outlined,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
          ),
          const Gap(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.target?.title ?? step.label,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Gap(AppSpacing.xs),
                if (provided)
                  Text(
                    Fmt.bytes(document.sizeBytes),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    step == KycStep.idBack
                        ? 'Non fourni — facultatif selon la piece'
                        : 'Non fourni',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const Gap(AppSpacing.md),
          if (provided)
            StatusPill(label: 'Prete', tone: StatusTone.success)
          else
            TextButton(onPressed: onRetake, child: const Text('Ajouter')),
        ],
      ),
    );
  }
}

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(AppSpacing.section),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.successSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppColors.success,
            ),
          ),
        ),
        const Gap(AppSpacing.xl),
        Center(child: Text('Simulation terminee', style: text.headlineSmall)),
        const Gap(AppSpacing.sm),
        Text(
          'Le parcours a ete joue de bout en bout. Aucune donnée n’a ete '
          'transmise et aucun service externe n’a ete appele.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Gap(AppSpacing.xl),
        const InfoBanner(
          tone: StatusTone.neutral,
          icon: Icons.link_outlined,
          title: 'Prochaine étape',
          message:
              'Le branchement remplacera cette simulation par un envoi vers le '
              'service de vérification, suivi via la file de synchronisation.',
        ),
        const Gap(AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRestart,
            child: const Text('Rejouer le parcours'),
          ),
        ),
      ],
    );
  }
}
