import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/kyc_onboarding_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/capture_widgets.dart';
import '../../widgets/common.dart';

/// Consentement prealable au traitement des données biometriques (§52).
///
/// La collecte doit reposer sur un consentement explicite, une finalite
/// annoncee et une minimisation des données. L'écran énoncé ce qui est
/// collecte, pourquoi, et ce que l'utilisateur peut refuser.
class KycConsentScreen extends ConsumerStatefulWidget {
  const KycConsentScreen({super.key});

  @override
  ConsumerState<KycConsentScreen> createState() => _KycConsentScreenState();
}

class _KycConsentScreenState extends ConsumerState<KycConsentScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(kycOnboardingProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepIndicator(
          current: 1,
          total: 4,
          label: 'Vérification d’identité',
        ),
        const Gap(AppSpacing.xl),
        Text('Avant de commencer', style: text.headlineSmall),
        const Gap(AppSpacing.sm),
        Text(
          'La vérification de votre identité permet aux établissements de '
          'savoir que votre profil correspond bien a une personne reelle.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Gap(AppSpacing.xl),

        const _ConsentPoint(
          icon: Icons.photo_camera_front_outlined,
          title: 'Un selfie',
          detail:
              'Pour confirmer que vous etes bien la personne qui cree le profil.',
        ),
        const Gap(AppSpacing.lg),
        const _ConsentPoint(
          icon: Icons.badge_outlined,
          title: 'Votre piece d’identité',
          detail:
              'Pour vérifier votre nom et votre date de naissance. Le numéro '
              'complet n’est jamais affiche sur votre profil public.',
        ),
        const Gap(AppSpacing.lg),
        const _ConsentPoint(
          icon: Icons.lock_outline,
          title: 'Conservation limitée',
          detail:
              'Les documents servent uniquement a la vérification. Vous pouvez '
              'en demander la suppression a tout moment.',
        ),

        const Gap(AppSpacing.xl),
        const InfoBanner(
          tone: StatusTone.warning,
          icon: Icons.science_outlined,
          title: 'Mode démonstration',
          message:
              'Aucune donnée n’est transmise et aucun service externe n’est '
              'appele. Les images restent sur cet appareil et chaque étape '
              'peut etre passee.',
        ),
        const Gap(AppSpacing.xl),

        InkWell(
          onTap: () => setState(() => _accepted = !_accepted),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'J’accepte que mon selfie et ma piece d’identité soient '
                      'utilises pour vérifier mon identité.',
                      style: text.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.xl),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _accepted ? controller.giveConsent : null,
            child: const Text('Commencer la vérification'),
          ),
        ),
        const Gap(AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            // Le parcours reste franchissable sans consentement pendant la
            // mise au point ; en production ce bouton disparait.
            onPressed: () => controller.skip(KycStep.consent),
            child: const Text('Passer cette étape'),
          ),
        ),
      ],
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const Gap(AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Gap(AppSpacing.xs),
              Text(
                detail,
                style: text.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
