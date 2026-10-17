import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../../domain/usecases/test_scoring.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 22 — Certifications (§13).
///
/// Chaque certification est rattachee a une matière et a un niveau precis :
/// jamais un simple « enseignant certifié ».
class CertificationsScreen extends ConsumerWidget {
  const CertificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentTeacherProfileProvider);
    final history = ref.watch(testHistoryProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certifications'),
        leading: const BackButton(),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          final certs = profile.certifications;

          if (certs.isEmpty) {
            return EmptyState(
              icon: Icons.workspace_premium_outlined,
              title: 'Aucune certification',
              message:
                  'Passez un test de compétence pour obtenir votre première '
                  'certification par matière et niveau.',
              actionLabel: 'Voir les tests',
              onAction: () => context.push('/teacher/tests'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Vos compétences sont evaluees pour chaque couple matière et '
                'niveau. Les établissements voient precisement ce qui a ete '
                'vérifié.',
                style: text.bodyMedium,
              ),
              const Gap(AppSpacing.xl),

              for (final cert in certs)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _CertificationCard(certification: cert),
                ),

              if (history.isNotEmpty) ...[
                const Gap(AppSpacing.xl),
                Text('Historique des tests', style: text.titleMedium),
                const Gap(AppSpacing.md),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < history.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        InkWell(
                          onTap: () => context.push(
                            '/teacher/result/${history[i].sessionId}',
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      history[i].title,
                                      style: text.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Fmt.date(history[i].date),
                                      style: text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: '${history[i].score ?? 0} %',
                                tone: history[i].passed
                                    ? StatusTone.success
                                    : StatusTone.warning,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({required this.certification});

  final CertificationItem certification;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final domains = TestResult.parseDomainScores(
      certification.domainScoresJson,
    );
    // Le domaine le plus faible : le seul qui passe a l'accent. Calcule une
    // fois, pas a chaque barre.
    final aTravailler = domains.isEmpty
        ? -1
        : domains.map((d) => d.percentage).reduce((a, b) => a < b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(certification.subject.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Niveau ${certification.level.name} · Compétence vérifiée',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              ProgressRing(
                value: certification.score / 100,
                size: 52,
                strokeWidth: 4.5,
                color: AppColors.success,
                child: Text(
                  '${certification.score}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          // Le domaine a travailler en priorite : c'est le seul qui
          // passe a l'accent.
          if (domains.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < domains.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(domains[i].domain, style: text.bodySmall),
                    ),
                    Expanded(
                      flex: 4,
                      child: ThinProgressBar(
                        value: domains[i].percentage / 100,
                        height: 4,
                        // Une seule mesure repetee : une seule teinte. Seul
                        // le domaine le plus faible passe a l'accent, parce
                        // que c'est celui sur lequel travailler.
                        color: domains[i].percentage == aTravailler
                            ? AppColors.chartHighlight
                            : AppColors.chartBar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${domains[i].percentage} %',
                        textAlign: TextAlign.end,
                        style: text.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 8),
          Text(
            'Certifié le ${Fmt.date(certification.issuedAt)}',
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}
