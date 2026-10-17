import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Ecrans 12 et 13 établissement — Candidatures reçues, classees (§22).
class JobApplicantsScreen extends ConsumerWidget {
  const JobApplicantsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicantsAsync = ref.watch(applicantsProvider(jobId));
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Candidatures'),
            if (jobAsync.valueOrNull case final job?)
              Text(
                job.title,
                style: text.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: applicantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (candidates) {
          if (candidates.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Aucune candidature',
              message:
                  'Les candidatures reçues apparaîtront ici, classees par '
                  'pertinence selon vos critères.',
            );
          }

          final shortlisted = candidates.where((c) => c.shortlisted).toList();
          final others = candidates.where((c) => !c.shortlisted).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                '${candidates.length} candidature(s) — classees par '
                'compatibilite avec votre offre.',
                style: text.bodySmall,
              ),
              const Gap(AppSpacing.lg),

              if (shortlisted.isNotEmpty) ...[
                SectionHeader(
                  title: 'Preselectionnes',
                  subtitle: '${shortlisted.length} profil(s)',
                ),
                const Gap(AppSpacing.md),
                for (final candidate in shortlisted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ApplicantCard(candidate: candidate, jobId: jobId),
                  ),
                const Gap(AppSpacing.lg),
              ],

              if (others.isNotEmpty) ...[
                SectionHeader(
                  title: shortlisted.isEmpty
                      ? 'Candidatures'
                      : 'Autres candidatures',
                ),
                const Gap(AppSpacing.md),
                for (var i = 0; i < others.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ApplicantCard(
                      candidate: others[i],
                      jobId: jobId,
                      rank: shortlisted.length + i + 1,
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

class _ApplicantCard extends ConsumerWidget {
  const _ApplicantCard({
    required this.candidate,
    required this.jobId,
    this.rank,
  });

  final RankedCandidate candidate;
  final String jobId;
  final int? rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profile = candidate.profile;

    return AppCard(
      onTap: () {
        // Consulter une candidature la fait passer au statut « Vue » (§18).
        if (candidate.applicationId != null) {
          ref
              .read(jobRepositoryProvider)
              .markApplicationViewed(candidate.applicationId!);
        }
        context.push('/teachers/${profile.teacherId}?jobId=$jobId');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(
                firstName: profile.firstName,
                lastName: profile.lastName,
                photoPath: profile.photoPath,
                size: 46,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (rank != null) ...[
                          Text('$rank. ', style: text.titleMedium),
                        ],
                        Flexible(
                          child: Text(
                            profile.fullName,
                            style: text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(profile.displayHeadline, style: text.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${candidate.match.value} %',
                    style: text.titleMedium?.copyWith(
                      color: candidate.match.value >= 75
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text('compatibilite', style: text.labelSmall),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final badge in profile.badges)
                TrustBadgeChip(badge: badge, compact: true),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                Fmt.experience(profile.yearsExperience),
                style: text.bodySmall,
              ),
              const SizedBox(width: 12),
              Text(profile.city ?? '—', style: text.bodySmall),
              const Spacer(),
              if (candidate.applicationStatus != null)
                StatusPill.application(candidate.applicationStatus!),
            ],
          ),

          const Divider(height: 22),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(jobRepositoryProvider)
                      .setShortlisted(
                        candidate.applicationId!,
                        !candidate.shortlisted,
                      )
                      .then((_) => ref.invalidate(applicantsProvider(jobId))),
                  icon: Icon(
                    candidate.shortlisted ? Icons.star : Icons.star_outline,
                    size: 18,
                  ),
                  label: Text(
                    candidate.shortlisted ? 'Retirer' : 'Preselectionner',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    foregroundColor: candidate.shortlisted
                        ? AppColors.primary
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openRoom(context, ref),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('Contacter'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ouvre l'espace de recrutement du candidat (§24).
  Future<void> _openRoom(BuildContext context, WidgetRef ref) async {
    if (candidate.applicationId == null) return;

    final repository = ref.read(recruitmentRepositoryProvider);
    final roomId = await repository.openRoom(candidate.applicationId!);

    // Contacter un candidat vaut preselection (§28).
    if (!candidate.shortlisted) {
      await ref
          .read(jobRepositoryProvider)
          .setShortlisted(candidate.applicationId!, true);
      await repository.advanceStage(roomId, RecruitmentStage.shortlisted);
    }

    ref.invalidate(applicantsProvider(jobId));
    if (!context.mounted) return;
    context.push('/rooms/$roomId');
  }
}
