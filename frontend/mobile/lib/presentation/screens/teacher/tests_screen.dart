import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/test_models.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 18 — Liste des tests disponibles (§10).
///
/// Un test est propose pour chaque couple matière + niveau declare (§10.1).
class TestsScreen extends ConsumerWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = ref.watch(availableTestsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests de compétence'),
        leading: const BackButton(),
      ),
      body: tests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Aucun test disponible',
              message:
                  'Selectionnez vos matières et vos niveaux : un test vous '
                  'sera propose pour chaque combinaison.',
              actionLabel: 'Ajouter mes matières',
              onAction: () => context.push('/teacher/subjects'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'La certification combine identité vérifiée, diplôme vérifié '
                'et compétence évaluée.',
                style: text.bodyMedium,
              ),
              const Gap(AppSpacing.xl),
              for (final test in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _TestCard(test: test),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({required this.test});

  final TestSummary test;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cert = test.certification;

    return AppCard(
      onTap: () => context.push('/teacher/tests/${test.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cert != null
                      ? AppColors.successSurface
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  cert != null
                      ? Icons.workspace_premium
                      : Icons.assignment_outlined,
                  size: 20,
                  color: cert != null ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(test.subject.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text('Niveau : ${test.level.name}', style: text.bodySmall),
                  ],
                ),
              ),
              if (cert != null)
                StatusPill(
                  label: '${cert.score} %',
                  tone: StatusTone.success,
                  icon: Icons.verified,
                )
              else if (test.canResume)
                const StatusPill(
                  label: 'A reprendre',
                  tone: StatusTone.warning,
                  icon: Icons.play_circle_outline,
                ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              _Meta(
                icon: Icons.help_outline,
                label: '${test.questionCount} questions',
              ),
              const SizedBox(width: 16),
              _Meta(icon: Icons.schedule, label: '${test.durationMinutes} min'),
              const Spacer(),
              Text(
                cert != null ? 'Repasser' : 'Commencer',
                style: text.titleSmall?.copyWith(color: AppColors.primary),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.textTertiary),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
