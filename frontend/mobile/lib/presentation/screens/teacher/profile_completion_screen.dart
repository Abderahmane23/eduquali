import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/teacher_profile.dart';
import '../../../domain/usecases/profile_completion.dart';
import '../../../domain/usecases/trust_score.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 8 — Completion du profil (§16) et Trust Score (§62).
class ProfileCompletionScreen extends ConsumerWidget {
  const ProfileCompletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentTeacherProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completion du profil'),
        leading: const BackButton(),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (profile) =>
            profile == null ? const SizedBox.shrink() : _Body(profile: profile),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final completion = profile.completion;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: ProgressRing(
            value: completion.rate / 100,
            size: 150,
            strokeWidth: 9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${completion.rate} %', style: text.headlineMedium),
                Text('complété', style: text.bodySmall),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.xl),

        Center(
          child: Text(
            completion.isComplete
                ? 'Votre profil est complet.'
                : 'Votre profil est complété a ${completion.rate} %',
            style: text.titleMedium,
          ),
        ),
        const Gap(AppSpacing.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Un profil complet est mieux classe dans les recherches des '
              'établissements.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
        ),

        const Gap(AppSpacing.section),

        Text('Actions restantes', style: text.titleMedium),
        const Gap(AppSpacing.md),

        for (final step in completion.steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _StepRow(step: step),
          ),

        const Gap(AppSpacing.section),

        // Trust Score — detail par dimension (§62).
        SectionHeader(
          title: 'Indice de confiance',
          subtitle: profile.trust.label,
        ),
        const Gap(AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cet indice agrege des éléments verifiables : identité, '
                      'diplôme, compétence, experience, reputation et '
                      'historique.',
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  ProgressRing(
                    value: profile.trust.value / 100,
                    size: 56,
                    strokeWidth: 5,
                    child: Text(
                      '${profile.trust.value}',
                      style: text.titleSmall,
                    ),
                  ),
                ],
              ),
              const Divider(height: 26),
              for (var i = 0; i < profile.trust.dimensions.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _TrustRow(dimension: profile.trust.dimensions[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final CompletionStep step;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: step.done ? null : () => context.push(step.route),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderColor: step.done ? AppColors.successSurface : AppColors.border,
      child: Row(
        children: [
          Icon(
            step.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 21,
            color: step.done ? AppColors.success : AppColors.borderStrong,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.label,
              style: text.titleSmall?.copyWith(
                color: step.done ? AppColors.textSecondary : null,
              ),
            ),
          ),
          Text(
            '+${step.weight} %',
            style: text.labelMedium?.copyWith(
              color: step.done ? AppColors.success : AppColors.textTertiary,
            ),
          ),
          if (!step.done) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 19,
              color: AppColors.textTertiary,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.dimension});

  final TrustDimension dimension;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(dimension.label, style: text.titleSmall)),
            Text(
              '${dimension.earned} / ${dimension.max}',
              style: text.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ThinProgressBar(
          value: dimension.max == 0 ? 0 : dimension.earned / dimension.max,
          height: 4,
          color: dimension.complete ? AppColors.success : AppColors.primary,
        ),
        const SizedBox(height: 5),
        Text(dimension.detail, style: text.labelSmall),
      ],
    );
  }
}
