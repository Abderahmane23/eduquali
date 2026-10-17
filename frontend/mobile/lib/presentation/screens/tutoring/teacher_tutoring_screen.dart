import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/tutoring_repository.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tutoring_cards.dart';

/// Cours à domicile, côté professeur : demandes reçues et offres publiées.
///
/// Les demandes passent en premier : c'est là qu'une famille attend une
/// réponse. Les offres se consultent moins souvent.
class TeacherTutoringScreen extends ConsumerWidget {
  const TeacherTutoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref
            .watch(teacherTutoringRequestsProvider)
            .valueOrNull
            ?.where((r) => r.status == TutoringStatus.sent)
            .length ??
        0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cours à domicile'),
          bottom: TabBar(
            tabs: [
              Tab(text: pending > 0 ? 'Demandes ($pending)' : 'Demandes'),
              const Tab(text: 'Mes offres'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/teacher/tutoring/new'),
          icon: const Icon(Icons.add),
          label: const Text('Publier une offre'),
        ),
        body: const TabBarView(children: [_Requests(), _Offers()]),
      ),
    );
  }
}

class _Requests extends ConsumerWidget {
  const _Requests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(teacherTutoringRequestsProvider);

    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Impossible d’afficher les demandes',
        message: 'Réessayez dans un instant.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Aucune demande pour l’instant',
            message: 'Les familles qui réservent vos cours apparaîtront ici.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => refreshTutoring(ref),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.md),
            itemBuilder: (_, index) {
              final item = items[index];
              final open = item.status == TutoringStatus.sent;
              return TutoringRequestCard(
                item: item,
                viewer: TutoringActor.teacher,
                onAccept: open
                    ? () => _answer(context, ref, item, TutoringStatus.accepted)
                    : null,
                onDecline: open
                    ? () => _answer(context, ref, item, TutoringStatus.declined)
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    TutoringRequestItem item,
    TutoringStatus to,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(tutoringRepositoryProvider)
          .setStatus(requestId: item.id, actor: TutoringActor.teacher, to: to);
      refreshTutoring(ref);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            to == TutoringStatus.accepted
                ? 'Demande acceptée. Contactez la famille pour le premier cours.'
                : 'Demande refusée.',
          ),
        ),
      );
    } on TutoringException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _Offers extends ConsumerWidget {
  const _Offers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(myTutoringOffersProvider);

    final availability = ref.watch(tutoringAvailabilityProvider).valueOrNull;
    final problem = availability == null
        ? null
        : tutoringAvailabilityProblem(
            days: availability.days,
            slots: availability.slots,
          );

    Widget banner() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AppCard(
        onTap: () => context.push('/teacher/tutoring/availability'),
        child: Row(
          children: [
            Icon(
              problem == null ? Icons.event_available : Icons.schedule,
              color: problem == null ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes disponibilités',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    problem ??
                        '${availability!.days.length} jours · '
                            '${availability.slots.map((s) => s.label).join(", ")}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );

    return offers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Impossible d’afficher vos offres',
        message: 'Réessayez dans un instant.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            children: [
              banner(),
              Expanded(
                child: EmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'Donnez des cours près de chez vous',
                  message:
                      'Quatre questions : vos jours, vos créneaux, ce que '
                      'vous enseignez, vos conditions. Les parents de votre '
                      'quartier verront ensuite votre offre.',
                  // Un seul chemin d'entree, guide : sans disponibilites la
                  // publication est de toute facon refusee, alors autant
                  // poser les deux dans le meme mouvement.
                  actionLabel: 'Mettre en place mes cours',
                  onAction: () => context.push('/teacher/tutoring/setup'),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            banner(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.md),
                itemBuilder: (_, index) {
                  final offer = items[index];
                  return Opacity(
                    opacity: offer.active ? 1 : 0.55,
                    child: TutoringOfferCard(
                      offer: offer,
                      trailing: Switch(
                        value: offer.active,
                        onChanged: (active) async {
                          await ref
                              .read(tutoringRepositoryProvider)
                              .setOfferActive(offer.id, active: active);
                          refreshTutoring(ref);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
