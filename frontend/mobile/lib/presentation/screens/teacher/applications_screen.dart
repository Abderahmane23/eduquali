import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactions.dart';
import '../../widgets/common.dart';

/// Écran 26 — Mes candidatures (§18).
class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes candidatures')),
      body: applicationsAsync.when(
        loading: () => const SkeletonDashboard(cards: [3]),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (applications) {
          if (applications.isEmpty) {
            return EmptyState(
              icon: Icons.description_outlined,
              title: 'Aucune candidature',
              message:
                  'Parcourez les offres et candidatez en un geste : votre '
                  'profil vérifié est transmis automatiquement.',
              actionLabel: 'Voir les offres',
              onAction: () => context.go(Routes.teacherOffers),
            );
          }

          final active = applications.where((a) => a.isActive).toList();
          final closed = applications.where((a) => !a.isActive).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (active.isNotEmpty) ...[
                SectionHeader(
                  title: 'En cours',
                  subtitle: '${active.length} candidature(s) suivie(s)',
                ),
                const Gap(AppSpacing.md),
                for (final application in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ApplicationCard(application: application),
                  ),
              ],

              if (closed.isNotEmpty) ...[
                const Gap(AppSpacing.lg),
                SectionHeader(title: 'Terminees'),
                const Gap(AppSpacing.md),
                for (final application in closed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ApplicationCard(application: application),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.application});

  final ApplicationItem application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final job = application.job;

    return AppCard(
      onTap: () => application.roomId != null
          ? context.push('/rooms/${application.roomId}')
          : context.push('/teacher/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(job.institution.name, style: text.bodyMedium),
                  ],
                ),
              ),
              StatusPill.application(application.status),
            ],
          ),

          const SizedBox(height: 12),

          // Progression dans le workflow de recrutement (§28).
          _StatusTimeline(status: application.status),

          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Envoyée ${Fmt.relative(application.appliedAt)}',
                style: text.labelSmall,
              ),
              const Spacer(),
              if (application.matchScore != null)
                TagChip(
                  label: 'Compatibilite ${application.matchScore} %',
                  tone: StatusTone.neutral,
                ),
            ],
          ),

          if (application.status == ApplicationStatus.sent) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmWithdraw(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Retirer ma candidature'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer la candidature ?'),
        content: Text(
          'Votre candidature pour « ${application.job.title} » sera retiree. '
          'Vous pourrez candidater a nouveau tant que l’offre est ouverte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(jobRepositoryProvider).withdraw(application.id);
  }
}

/// Frise du parcours de candidature (§18).
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final ApplicationStatus status;

  static const _steps = [
    ApplicationStatus.sent,
    ApplicationStatus.viewed,
    ApplicationStatus.shortlisted,
    ApplicationStatus.interview,
    ApplicationStatus.offerReceived,
    ApplicationStatus.hired,
  ];

  @override
  Widget build(BuildContext context) {
    if (status.isClosed) {
      return InfoBanner(
        message: status == ApplicationStatus.rejected
            ? 'Cette candidature n’a pas ete retenue.'
            : 'Vous avez retire cette candidature.',
        tone: StatusTone.neutral,
        icon: Icons.info_outline,
      );
    }

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: _steps[i].order <= status.order
                    ? AppColors.primary
                    : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < _steps.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}
