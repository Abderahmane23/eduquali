import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kit.dart';
import '../../widgets/common.dart';
import '../../widgets/network_banner.dart';

/// Coquille de navigation de l'espace établissement (§56).
class InstitutionShell extends ConsumerWidget {
  const InstitutionShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const _tabs = [
    (
      path: Routes.institutionHome,
      icon: Icons.dashboard_outlined,
      active: Icons.dashboard,
      label: 'Tableau de bord',
    ),
    (
      path: Routes.institutionSearch,
      icon: Icons.groups_outlined,
      active: Icons.groups,
      label: 'Enseignants',
    ),
    (
      path: Routes.institutionJobs,
      icon: Icons.work_outline,
      active: Icons.work,
      label: 'Offres',
    ),
    // La mise en avant est le seul poste de depense recurrent d'un
    // etablissement : elle a son onglet, pas un lien au fond du profil.
    (
      path: Routes.institutionPromotions,
      icon: Icons.campaign_outlined,
      active: Icons.campaign,
      label: 'Promotion',
    ),
    (
      path: Routes.institutionProfile,
      icon: Icons.person_outline,
      active: Icons.person,
      label: 'Profil',
    ),
  ];

  int get _currentIndex {
    final index = _tabs.indexWhere((t) => t.path == location);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: KitBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => context.go(_tabs[index].path),
        items: [
          for (final tab in _tabs)
            (icon: tab.icon, active: tab.active, label: tab.label),
        ],
      ),
    );
  }
}

/// Écran 4 établissement — Tableau de bord (§20).
class InstitutionDashboardTab extends ConsumerWidget {
  const InstitutionDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(institutionStatsProvider).valueOrNull ?? const {};
    final jobs = ref.watch(institutionJobsProvider).valueOrNull ?? const [];
    final rooms = ref.watch(institutionRoomsProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace établissement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(institutionRoomsProvider);
          await ref.read(networkServiceProvider).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/institution/jobs/new'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Publier une offre'),
            ),
            const Gap(AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.institutionSearch),
              icon: const Icon(Icons.search, size: 19),
              label: const Text('Rechercher un enseignant'),
            ),

            const Gap(AppSpacing.section),

            Text('Activité de recrutement', style: text.titleMedium),
            const Gap(AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${stats['applications'] ?? 0}',
                    label: 'Candidatures',
                    icon: Icons.description_outlined,
                    tone: StatusTone.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    value: '${stats['shortlisted'] ?? 0}',
                    label: 'Profils preselectionnes',
                    icon: Icons.star_outline,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${stats['interviews'] ?? 0}',
                    label: 'Entretiens',
                    icon: Icons.event_outlined,
                    tone: StatusTone.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    value: '${stats['ongoing'] ?? 0}',
                    label: 'Recrutements en cours',
                    icon: Icons.handshake_outlined,
                    tone: StatusTone.success,
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.section),

            SectionHeader(
              title: 'Offres actives',
              actionLabel: 'Gerer',
              onAction: () => context.go(Routes.institutionJobs),
            ),
            const Gap(AppSpacing.md),

            if (jobs.isEmpty)
              const EmptyState(
                icon: Icons.work_off_outlined,
                title: 'Aucune offre publiée',
                message:
                    'Publiez votre première offre pour recevoir des '
                    'candidatures de profils vérifiés.',
              )
            else
              for (final job in jobs.where((j) => j.isOpen).take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _InstitutionJobCard(job: job),
                ),

            if (rooms.isNotEmpty) ...[
              const Gap(AppSpacing.xl),
              Text('Espaces de recrutement', style: text.titleMedium),
              const Gap(AppSpacing.md),
              for (final room in rooms.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    onTap: () => context.push('/rooms/${room.id}'),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          firstName: room.teacher.firstName,
                          lastName: room.teacher.lastName,
                          photoPath: room.teacher.photoPath,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.teacher.fullName,
                                style: text.titleSmall,
                              ),
                              Text(room.job.title, style: text.labelSmall),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: room.stage.label,
                          tone: StatusTone.info,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Écran 10 établissement — Offres publiées (§56).
class InstitutionJobsTab extends ConsumerWidget {
  const InstitutionJobsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(institutionJobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes offres')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/institution/jobs/new'),
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return EmptyState(
              icon: Icons.work_off_outlined,
              title: 'Aucune offre',
              message:
                  'Publiez une offre pour recevoir des candidatures '
                  'd’enseignants vérifiés et evalues.',
              actionLabel: 'Publier une offre',
              onAction: () => context.push('/institution/jobs/new'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.md),
            itemBuilder: (_, index) =>
                _InstitutionJobCard(job: jobs[index], showActions: true),
          );
        },
      ),
    );
  }
}

/// Carte d'offre cote établissement, avec le nombre de candidatures.
class _InstitutionJobCard extends ConsumerWidget {
  const _InstitutionJobCard({required this.job, this.showActions = false});

  final JobOffer job;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push('/institution/jobs/${job.id}/applicants'),
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
                    Text(
                      '${job.subject.name} · ${job.levelLabel}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: job.status.label,
                tone: job.status == JobStatus.published
                    ? StatusTone.success
                    : StatusTone.neutral,
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${job.applicationCount} candidature(s)',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(Fmt.relative(job.publishedAt), style: text.labelSmall),
            ],
          ),

          if (showActions) ...[
            const SizedBox(height: 6),
            const Divider(height: 18),
            Row(
              children: [
                if (job.isPrivate)
                  const TagChip(
                    label: 'Offre privee',
                    icon: Icons.lock_outline,
                    tone: StatusTone.warning,
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref
                      .read(jobRepositoryProvider)
                      .setJobStatus(
                        job.id,
                        job.status == JobStatus.published
                            ? JobStatus.paused
                            : JobStatus.published,
                      ),
                  child: Text(
                    job.status == JobStatus.published
                        ? 'Suspendre'
                        : 'Republier',
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/institution/jobs/${job.id}/applicants'),
                  child: const Text('Candidatures'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Écran 5 établissement — Profil de l'établissement (§56).
class InstitutionProfileTab extends ConsumerWidget {
  const InstitutionProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final stats = ref.watch(institutionStatsProvider).valueOrNull ?? const {};
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil établissement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go(Routes.splash);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session?.firstName ?? 'Établissement',
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(session?.phone ?? '', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.xl),

          Text('Recrutement', style: text.titleMedium),
          const Gap(AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Offres actives',
                  value: '${stats['activeJobs'] ?? 0}',
                ),
                const Divider(height: 20),
                InfoRow(
                  label: 'Candidatures reçues',
                  value: '${stats['applications'] ?? 0}',
                ),
                const Divider(height: 20),
                InfoRow(
                  label: 'Recrutements en cours',
                  value: '${stats['ongoing'] ?? 0}',
                ),
                const Divider(height: 20),
                InfoRow(
                  label: 'Recrutements termines',
                  value: '${stats['completed'] ?? 0}',
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.xl),

          // Les conditions commerciales ont quitte le profil (24/09) : la
          // remuneration passe par l'abonnement mensuel, et un encart sur
          // « un mois de salaire » y contredisait le prix affiche.
        ],
      ),
    );
  }
}
