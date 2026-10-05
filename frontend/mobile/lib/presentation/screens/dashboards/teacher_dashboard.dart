import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/repositories/contracts_repository.dart';
import '../../../domain/entities/job_models.dart';
import '../../../data/repositories/stats_repository.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';
import '../../widgets/mini_chart.dart';
import '../live/live_now_section.dart';
import '../live/start_live_button.dart';

/// L'accueil du professeur, d'après les maquettes du 23/09.
///
/// L'en-tête dit qui il est et ce que vaut son mois ; dessous, ce qu'il peut
/// faire, ce qu'il a reçu, et la forme de sa semaine. Rien d'autre : les
/// détails vivent au bout d'un lien, pas sur la page d'accueil.
///
/// Aucun chiffre n'est décoratif. Là où la maquette montrait une note moyenne
/// — que l'application ne mesure pas — on affiche les vues du profil, qui
/// existent vraiment.
class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;
    final stats = ref.watch(teacherMetricsProvider).valueOrNull;
    final payments = ref.watch(teacherPaymentsProvider).valueOrNull ?? const [];
    final week = ref.watch(teacherWeeklyIncomeProvider).valueOrNull;

    // Les offres d'abord : c'est ce qu'un professeur vient chercher. S'il
    // n'y en a aucune, on montre les établissements — une liste vide ne dit
    // rien, une liste d'écoles dit au moins vers qui se tourner.
    final offres = (ref.watch(opportunitiesProvider).valueOrNull ?? const [])
        .take(5)
        .toList();
    final ecoles = offres.isNotEmpty
        ? const <InstitutionSummary>[]
        : (ref.watch(institutionProfilesProvider(null)).valueOrNull ??
                  const <InstitutionSummary>[])
              .take(5)
              .toList();

    final nonLues = ref.watch(unreadNotificationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshContracts(ref);
        refreshMetrics(ref);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHero(
            eyebrow: 'Bonjour',
            title: profile?.firstName ?? 'Professeur',
            actions: [
              // Une cloche qui ouvrait « Paiements », et dont la pastille
              // suivait les sommes a venir : elle promettait des nouvelles et
              // menait a une facture. Elle ouvre maintenant les
              // notifications, comme sur les deux autres accueils, et compte
              // ce qui n'a pas ete lu.
              HeroIconButton(
                icon: Icons.notifications_none,
                tooltip: nonLues == 0
                    ? 'Notifications'
                    : '$nonLues notification(s) non lue(s)',
                badge: nonLues > 0,
                onPressed: () => context.push(Routes.notifications),
              ),
            ],
            bottom: stats == null
                ? null
                : HeroStatStrip(
                    items: [
                      (value: '${stats.lessonsGiven}', label: 'Cours donnés'),
                      (
                        value: '${stats.activeStudents}',
                        label: 'Élèves actifs',
                      ),
                      (value: '${stats.profileViews}', label: 'Vues du profil'),
                      (
                        value: Fmt.compactMoney(stats.monthlyIncome),
                        label: 'GNF reçus',
                      ),
                    ],
                  ),
          ),

          if (offres.isNotEmpty)
            KitCarousel(
              title: 'Offres pour vous',
              actionLabel: 'Voir tout',
              onAction: () => context.go(Routes.teacherOffers),
              children: [
                for (final o in offres)
                  TeacherMiniCard(
                    name: o.title,
                    subtitle: o.institution.name,
                    city: o.city,
                    onTap: () => context.push('/teacher/jobs/${o.id}'),
                  ),
              ],
            )
          else
            KitCarousel(
              title: 'Établissements de Guinée',
              children: [
                for (final e in ecoles)
                  TeacherMiniCard(
                    name: e.name,
                    subtitle: e.type.label,
                    city: e.city,
                    onTap: () => context.push('/etablissements/${e.id}'),
                  ),
              ],
            ),

          // Le geste principal du professeur, avant tout le reste : la
          // carte ouvre la classe du jour — qui a paye, qui est entre, qui
          // reste a prevenir. Au-dessus des bandes, parce qu'un cours se
          // commence a l'heure et non apres avoir fait defiler la page.
          const StartLiveButton(),

          const LiveNowSection(),
          const Gap(AppSpacing.md),

          // Trois bandes pleine largeur qui alternent : une page longue
          // s'ordonne par ses fonds, pas par des lignes de separation. Une
          // idee par bande — deux, et l'alternance ne dit plus rien.
          Band(
            title: 'Actions ',
            accented: 'rapides',
            children: [
              KitGrid(
                children: [
                  ActionCard(
                    compact: true,
                    icon: Icons.work_outline,
                    title: 'Chercher un poste',
                    onTap: () => context.go(Routes.teacherOffers),
                  ),
                  ActionCard(
                    compact: true,
                    icon: Icons.person_search_outlined,
                    title: 'Trouver un élève',
                    tone: StatusTone.warning,
                    onTap: () => context.push('/teacher/tutoring'),
                  ),
                ],
              ),
              ActionCard(
                compact: true,
                icon: Icons.videocam_outlined,
                title: 'Créer un cours vidéo',
                tone: StatusTone.success,
                onTap: () => context.push(Routes.courseNew),
              ),

              // --- Ce qui est rentré, et ce qui va rentrer ---------------,
            ],
          ),

          Band(
            tone: BandTone.soft,
            title: 'Paiements',
            children: [
              const Gap(AppSpacing.xl),
              KitCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _Somme(
                                label: 'Reçus ce mois',
                                amount: stats?.monthlyIncome ?? 0,
                                tone: StatusTone.success,
                              ),
                            ),
                            const VerticalDivider(
                              width: AppSpacing.lg,
                              thickness: 1,
                              color: AppColors.border,
                            ),
                            Expanded(
                              child: _Somme(
                                label: 'À venir',
                                amount: stats?.pendingIncome ?? 0,
                                tone: StatusTone.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Text(
                          'Aucune échéance. Elles apparaîtront dès qu’un '
                          'contrat démarre.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else ...[
                      for (final payment in payments.take(4))
                        _LignePaiement(payment: payment),
                      const Divider(height: 1, color: AppColors.border),
                      TextButton(
                        onPressed: () => context.push(Routes.payments),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppSpacing.touchTarget + 4,
                          ),
                        ),
                        child: const Text('Voir tous les paiements'),
                      ),
                    ],
                  ],
                ),
              ),

              // --- Ce qui bouge d'un mois sur l'autre --------------------,
            ],
          ),

          Band(
            children: [
              if (stats != null) ...[
                const Gap(AppSpacing.xl),
                KitGrid(
                  children: [
                    MetricCard(
                      compact: true,
                      icon: Icons.groups_outlined,
                      value: '${stats.activeStudents}',
                      label: 'Élèves actifs',
                    ),
                    MetricCard(
                      compact: true,
                      icon: Icons.play_circle_outline,
                      value: '${stats.videoSalesThisMonth}',
                      label: 'Ventes vidéos',
                      tone: StatusTone.success,
                      delta: TeacherStats.delta(
                        stats.videoSalesThisMonth,
                        stats.videoSalesLastMonth,
                      ),
                      onTap: () => context.go(Routes.teacherCatalog),
                    ),
                    MetricCard(
                      compact: true,
                      icon: Icons.visibility_outlined,
                      value: '${stats.profileViews}',
                      label: 'Vues du profil',
                      tone: StatusTone.info,
                    ),
                    MetricCard(
                      compact: true,
                      icon: Icons.event_available_outlined,
                      value: '${stats.lessonsThisMonth}',
                      label: 'Cours ce mois',
                      tone: StatusTone.warning,
                      delta: TeacherStats.delta(
                        stats.lessonsThisMonth,
                        stats.lessonsLastMonth,
                      ),
                      onTap: () => context.go(Routes.teacherCalendar),
                    ),
                  ],
                ),
              ],

              if (week != null && week.isNotEmpty)
                WeeklyIncomeChart(
                  title: 'Revenus – 7 derniers jours',
                  firstLabel: 'Domicile',
                  secondLabel: 'Vidéos',
                  days: [
                    for (final day in week)
                      (
                        label: Fmt.weekdayShort(day.day),
                        first: day.tutoring,
                        second: day.videos,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Reçus ce mois / 320 000 GNF », dans la carte des paiements.
class _Somme extends StatelessWidget {
  const _Somme({required this.label, required this.amount, required this.tone});

  final String label;
  final int amount;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (surface: _, :ink) = tonePair(tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Fmt.money(amount),
            maxLines: 1,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Une échéance, dans la carte des paiements.
class _LignePaiement extends StatelessWidget {
  const _LignePaiement({required this.payment});

  final ContractPaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final regle = payment.status == ContractPaymentStatus.paid;
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              IconTile(
                icon: regle
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined,
                tone: regle ? StatusTone.success : StatusTone.warning,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.contractLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      Fmt.date(payment.dueOn),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MoneyText(
                Fmt.money(payment.amount),
                tone: regle ? StatusTone.success : StatusTone.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
