import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/usecases/test_scoring.dart';
import '../../providers/feature_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 21 — Résultat du test (§12).
///
/// Affiche le score global et le detail par domaine de compétence. En cas de
/// réussite, la certification est delivree pour le couple matière + niveau
/// (§13).
class TestResultScreen extends ConsumerWidget {
  const TestResultScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(testResultProvider(sessionId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat du test'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.teacherHome),
          tooltip: 'Fermer',
        ),
      ),
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Résultat indisponible',
          message: '$error',
        ),
        data: (result) {
          if (result == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Aucun résultat',
              message: 'Cette session n’a pas encore ete corrigee.',
            );
          }
          return _ResultBody(result: result, sessionId: sessionId, text: text);
        },
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.result,
    required this.sessionId,
    required this.text,
  });

  final TestResult result;
  final String sessionId;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: ScoreDial(
                  score: result.score,
                  passed: result.passed,
                  size: 200,
                ),
              ),
              const Gap(AppSpacing.lg),

              Center(
                child: Text(
                  '${result.correctCount} / ${result.totalQuestions} bonnes réponses',
                  style: text.titleSmall?.copyWith(
                    color: result.passed
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),

              if (result.unansweredCount > 0) ...[
                const Gap(AppSpacing.sm),
                Center(
                  child: Text(
                    '${result.unansweredCount} question(s) sans réponse',
                    style: text.bodySmall,
                  ),
                ),
              ],

              const Gap(AppSpacing.xl),

              InfoBanner(
                title: result.passed
                    ? 'Compétence certifiée'
                    : 'Seuil non atteint',
                message: result.passed
                    ? 'Votre certification a ete ajoutee a votre profil et sera '
                          'visible par les établissements après synchronisation.'
                    : 'Le score minimum requis est de ${result.passingScore} %. '
                          'Vous pouvez repasser ce test ulterieurement.',
                tone: result.passed ? StatusTone.success : StatusTone.warning,
                icon: result.passed
                    ? Icons.workspace_premium
                    : Icons.info_outline,
              ),

              const Gap(AppSpacing.section),

              // Detail par domaine de compétence (§12).
              if (result.domainScores.isNotEmpty) ...[
                Text('Résultats par domaine', style: text.titleMedium),
                const Gap(AppSpacing.lg),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < result.domainScores.length; i++) ...[
                        if (i > 0) const Divider(height: AppSpacing.xl),
                        _DomainRow(
                          score: result.domainScores[i],
                          // Meme mesure, meme teinte. Seul le domaine le
                          // plus faible passe a l'accent : c'est celui sur
                          // lequel travailler.
                          color:
                              result.domainScores[i].percentage ==
                                  result.domainScores
                                      .map((d) => d.percentage)
                                      .reduce((a, b) => a < b ? a : b)
                              ? AppColors.chartHighlight
                              : AppColors.chartBar,
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(AppSpacing.xl),
              ],

              // Le serveur reste la source officielle du résultat (§11).
              Text(
                'Ce résultat a ete calcule sur l’appareil pour un affichage '
                'immediat. Il sera confirme par le serveur lors de la '
                'prochaine synchronisation.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        context.push('/teacher/result/$sessionId/detail'),
                    child: const Text('Voir le detail'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.go(Routes.teacherOffers),
                    child: const Text('Voir les offres'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne « Domaine — pourcentage » avec barre de progression.
class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.score, required this.color});

  final DomainScore score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                score.domain,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${score.percentage} %',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ThinProgressBar(value: score.percentage / 100, height: 5, color: color),
        const SizedBox(height: 5),
        Text(
          '${score.correct} / ${score.total} bonnes réponses',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
