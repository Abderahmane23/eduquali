import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kit.dart';
import '../../widgets/common.dart';
import '../../widgets/job_card.dart';
import '../../widgets/network_banner.dart';

/// Coquille de navigation de l'espace enseignant (§55).
class TeacherShell extends ConsumerWidget {
  const TeacherShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  // Six onglets, donc des libelles courts : « Calendrier » et « Catalogue »
  // se coupaient a soixante points de large. « Agenda » et « Videos » disent
  // la meme chose et tiennent.
  static const _tabs = [
    (
      path: Routes.teacherHome,
      icon: Icons.home_outlined,
      active: Icons.home,
      label: 'Accueil',
    ),
    (
      path: Routes.teacherOffers,
      icon: Icons.work_outline,
      active: Icons.work,
      label: 'Offres',
    ),
    (
      path: Routes.teacherCalendar,
      icon: Icons.calendar_month_outlined,
      active: Icons.calendar_month,
      label: 'Agenda',
    ),
    // Le catalogue quitte la barre : six onglets etaient deja la limite, et
    // un professeur y va une fois par mois quand il ouvre ses messages tous
    // les jours. Il reste a un doigt — la tuile « Ventes videos » de
    // l'accueil y mene.
    (
      path: Routes.teacherMessages,
      icon: Icons.forum_outlined,
      active: Icons.forum,
      label: 'Messages',
    ),
    (
      path: Routes.teacherAssistant,
      icon: Icons.auto_awesome_outlined,
      active: Icons.auto_awesome,
      label: 'Assistant',
    ),
    (
      path: Routes.teacherProfile,
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

/// Écran 6 — Tableau de bord enseignant (§55).
class TeacherDashboardTab extends ConsumerWidget {
  const TeacherDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentTeacherProfileProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: profileAsync.valueOrNull == null
            ? const Text('Accueil')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bonjour,', style: text.bodySmall),
                  Text(profileAsync.value!.firstName, style: text.titleLarge),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Synchronisation',
            onPressed: () => context.push('/sync'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Profil indisponible',
          message: '$error',
        ),
        data: (profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Aucun profil',
              message: 'Reconnectez-vous pour acceder a votre espace.',
            );
          }
          return _DashboardBody(profile: profile);
        },
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final opportunities = ref.watch(opportunitiesProvider);
    final applications = ref.watch(myApplicationsProvider).valueOrNull ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(opportunitiesProvider);
        await ref.read(networkServiceProvider).refresh();
        await ref.read(syncEngineProvider).synchronize();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Carte de completion (§16) — reprend la maquette « Profil a completer ».
          _CompletionCard(profile: profile),
          const Gap(AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${profile.certifications.length}',
                  label: 'Certification(s)',
                  icon: Icons.workspace_premium_outlined,
                  tone: StatusTone.primary,
                  onTap: () => context.push('/teacher/certifications'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  value: '${applications.where((a) => a.isActive).length}',
                  label: 'Candidatures actives',
                  icon: Icons.send_outlined,
                  onTap: () => context.go(Routes.teacherApplications),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${profile.trust.value}',
                  label: profile.trust.label,
                  icon: Icons.shield_outlined,
                  tone: StatusTone.info,
                  onTap: () => context.push('/teacher/completion'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  value: '${profile.yearsExperience}',
                  label: 'An(s) d’experience',
                  icon: Icons.timeline_outlined,
                  onTap: () => context.push('/teacher/experience'),
                ),
              ),
            ],
          ),

          const Gap(AppSpacing.md),
          const _TutoringCard(),

          const Gap(AppSpacing.section),

          // Prochaine étape recommandee, tiree du calcul de completion (§16).
          if (profile.completion.nextStep case final step?) ...[
            SectionHeader(
              title: 'Prochaine étape',
              subtitle: 'Pour ameliorer votre visibilité',
            ),
            const Gap(AppSpacing.md),
            AppCard(
              onTap: () => context.push(step.route),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.label, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          '+${step.weight} % de completion',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.section),
          ],

          SectionHeader(
            title: 'Offres recommandees',
            actionLabel: 'Tout voir',
            onAction: () => context.go(Routes.teacherOffers),
          ),
          const Gap(AppSpacing.md),

          opportunities.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('$error', style: text.bodySmall),
            data: (offers) {
              if (offers.isEmpty) {
                return const EmptyState(
                  icon: Icons.work_off_outlined,
                  title: 'Aucune offre pour le moment',
                  message:
                      'Ajoutez vos matières et niveaux pour recevoir des '
                      'opportunites correspondant a votre profil.',
                );
              }
              return Column(
                children: [
                  for (final offer in offers.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: JobCard(
                        offer: offer,
                        onTap: () => context.push('/teacher/jobs/${offer.id}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Accès aux cours à domicile depuis l'accueil.
///
/// Une demande en attente est une famille qui attend une réponse : elle
/// s'affiche ici, sans avoir à ouvrir l'écran pour la découvrir.
class _TutoringCard extends ConsumerWidget {
  const _TutoringCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final pending =
        ref
            .watch(teacherTutoringRequestsProvider)
            .valueOrNull
            ?.where((r) => r.status == TutoringStatus.sent)
            .length ??
        0;
    final offers = ref.watch(myTutoringOffersProvider).valueOrNull ?? const [];

    final subtitle = pending > 0
        ? pending == 1
              ? '1 famille attend votre réponse'
              : '$pending familles attendent votre réponse'
        : offers.isEmpty
        ? 'Publiez une offre, les parents réservent'
        : '${offers.where((o) => o.active).length} offre(s) en ligne';

    return AppCard(
      onTap: () => context.push('/teacher/tutoring'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pending > 0
                  ? AppColors.warningSurface
                  : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.home_work_outlined,
              size: 20,
              color: pending > 0 ? AppColors.warning : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cours à domicile', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
          if (pending > 0)
            StatusPill(label: '$pending', tone: StatusTone.warning),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// Carte de completion du profil (§16).
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final completion = profile.completion;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  completion.isComplete
                      ? 'Votre profil est complet.'
                      : 'Continuez pour etre visible par les établissements.',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              ProgressRing(
                value: completion.rate / 100,
                size: 54,
                strokeWidth: 4.5,
                color: Colors.white,
                trackColor: Colors.white24,
                child: Text(
                  '${completion.rate}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (!completion.isComplete) ...[
            const Gap(AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/teacher/completion'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Completer mon profil'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Écran 7 — Mon profil (§15).
class TeacherProfileTab extends ConsumerWidget {
  const TeacherProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentTeacherProfileProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => context.push('/teacher/profile/edit'),
          ),
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
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Profil indisponible',
          message: '$error',
        ),
        data: (profile) => profile == null
            ? const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Aucun profil',
              )
            : _ProfileBody(profile: profile, text: text),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.text});

  final TeacherProfile profile;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            ProfileAvatar(
              firstName: profile.firstName,
              lastName: profile.lastName,
              photoPath: profile.photoPath,
              size: 64,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(profile.displayHeadline, style: text.bodyMedium),
                  if (profile.city != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text('${profile.city}, Guinée', style: text.bodySmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const Gap(AppSpacing.xl),

        // Badges de confiance (§14).
        if (profile.badges.isNotEmpty) ...[
          Text('Badges', style: text.titleMedium),
          const Gap(AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                for (final badge in profile.badges)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TrustBadgeChip(badge: badge),
                  ),
              ],
            ),
          ),
          const Gap(AppSpacing.xl),
        ],

        // Certifications par matière et niveau (§13).
        SectionHeader(
          title: 'Certifications',
          actionLabel: profile.certifications.isEmpty ? null : 'Voir tout',
          onAction: profile.certifications.isEmpty
              ? null
              : () => context.push('/teacher/certifications'),
        ),
        const Gap(AppSpacing.md),
        if (profile.certifications.isEmpty)
          AppCard(
            onTap: () => context.push('/teacher/tests'),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Passez un test pour obtenir votre première certification.',
                    style: text.bodyMedium,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          )
        else
          Column(
            children: [
              for (final cert in profile.certifications.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cert.title, style: text.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                'Certifié le ${Fmt.date(cert.issuedAt)}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: '${cert.score} %',
                          tone: StatusTone.success,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

        const Gap(AppSpacing.xl),

        // Acces aux sections du profil (§55).
        Text('Mon profil', style: text.titleMedium),
        const Gap(AppSpacing.md),
        _ProfileLink(
          icon: Icons.verified_user_outlined,
          label: 'Vérification d’identité',
          trailing: StatusPill.verification(profile.identityStatus),
          route: '/teacher/identity',
        ),
        _ProfileLink(
          icon: Icons.school_outlined,
          label: 'Diplômes',
          trailing: StatusPill.verification(profile.diplomaStatus),
          route: '/teacher/diplomas',
        ),
        _ProfileLink(
          icon: Icons.menu_book_outlined,
          label: 'Matières enseignees',
          value: '${profile.capabilities.length}',
          route: '/teacher/subjects',
        ),
        _ProfileLink(
          icon: Icons.stairs_outlined,
          label: 'Niveaux',
          value:
              '${profile.capabilities.fold<int>(0, (s, c) => s + c.levels.length)}',
          route: '/teacher/levels',
        ),
        _ProfileLink(
          icon: Icons.fact_check_outlined,
          label: 'Tests de compétence',
          route: '/teacher/tests',
        ),
        _ProfileLink(
          icon: Icons.work_history_outlined,
          label: 'Expérience professionnelle',
          value: '${profile.experiences.length}',
          route: '/teacher/experience',
        ),
        _ProfileLink(
          icon: Icons.home_work_outlined,
          label: 'Cours à domicile',
          route: '/teacher/tutoring',
        ),
        _ProfileLink(
          icon: Icons.event_available_outlined,
          label: 'Disponibilité',
          value: profile.availability.label,
          route: '/teacher/availability',
        ),

        const Gap(AppSpacing.xl),

        // Reputation vérifiée (§33).
        Text('Reputation', style: text.titleMedium),
        const Gap(AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              InfoRow(
                label: 'Établissements',
                value: '${profile.reputation.institutionCount}',
              ),
              const Divider(height: 20),
              InfoRow(
                label: 'Expérience',
                value: Fmt.experience(profile.yearsExperience),
              ),
              const Divider(height: 20),
              InfoRow(
                label: 'Recrutements via la plateforme',
                value: '${profile.reputation.platformRecruitments}',
              ),
              const Divider(height: 20),
              InfoRow(
                label: 'Satisfaction',
                value: profile.reputation.satisfaction == null
                    ? 'Aucune évaluation'
                    : '${profile.reputation.satisfaction!.round()} %',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.label,
    required this.route,
    this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String route;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      onTap: () => context.push(route),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (trailing != null)
            trailing!
          else if (value != null)
            Text(value!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    ),
  );
}
