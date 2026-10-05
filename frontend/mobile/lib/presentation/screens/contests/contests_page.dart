import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/points_api.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Concours et points de fidélité (phase D1 et D4).
///
/// --- Pourquoi deux onglets et pas un -------------------------------------
///
/// « Classement » répond à *où est-ce que je me situe* ; « Mes points » répond à
/// *qu'est-ce que j'ai gagné, et pourquoi*. Les mélanger donnerait un écran où
/// le solde se perd entre deux podiums, alors que c'est le solde qu'on vient
/// vérifier le plus souvent.
///
/// --- Ce que cet écran ne fait pas ----------------------------------------
///
/// Il ne calcule rien. Pas de somme de points, pas de rang déduit localement :
/// tout vient du serveur. Un solde calculé ici divergerait de celui de la base,
/// et c'est celui affiché qu'on croirait. L'écran le dit franchement quand le
/// serveur n'est pas joignable, plutôt que d'afficher un zéro qui ressemble à
/// une réponse.
class ContestsPage extends ConsumerStatefulWidget {
  const ContestsPage({super.key});

  @override
  ConsumerState<ContestsPage> createState() => _ContestsPageState();
}

class _ContestsPageState extends ConsumerState<ContestsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Concours'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: SegmentedToggle(
                labels: const ['Classement', 'Mes points'],
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _tab == 0 ? const _LadderTab() : const _PointsTab(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le concours en cours et son classement.
class _LadderTab extends ConsumerWidget {
  const _LadderTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concours = ref.watch(contestsProvider);

    return concours.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Indisponible(message: '$error'),
      data: (liste) {
        if (liste.isEmpty) {
          return const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Aucun concours pour le moment',
            message:
                'Les concours s’ouvrent chaque semaine. Celui de cette semaine '
                'apparaîtra ici.',
          );
        }

        // Le concours ouvert d'abord ; sinon le plus récent, pour que le
        // classement de la semaine passée reste consultable.
        final retenu = liste.firstWhere(
          (c) => c.isOpen,
          orElse: () => liste.last,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            0,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retenu.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  MetaText(
                    retenu.isOpen
                        ? '${retenu.pointsPrize} points pour le premier'
                        : 'Terminé',
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.lg),
            _Ladder(contestId: retenu.id),
          ],
        );
      },
    );
  }
}

class _Ladder extends ConsumerWidget {
  const _Ladder({required this.contestId});

  final String contestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classement = ref.watch(leaderboardProvider(contestId));

    return classement.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Indisponible(message: '$error'),
      data: (vue) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /*
           * Son rang AVANT le podium.
           *
           * « Afficher son propre rang avant le top 10 : c'est ce que l'élève
           * cherche. » Un podium où l'on ne se trouve pas ne dit rien à celui
           * qui le regarde — et son rang reste honnête même quand le podium
           * n'est pas encore publié.
           */
          if (vue.myRank != null)
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MetaText('Votre place'),
                        const Gap(AppSpacing.xs),
                        Text(
                          '${vue.myRank}${vue.myRank == 1 ? 're' : 'e'} sur '
                          '${vue.participants}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vue.myScore != null)
                    StatusPill(
                      label: '${vue.myScore} / 100',
                      tone: StatusTone.primary,
                    ),
                ],
              ),
            )
          else
            const InfoBanner(
              icon: Icons.how_to_reg_outlined,
              tone: StatusTone.neutral,
              message:
                  'Vous n’avez pas encore rendu de copie pour ce concours.',
            ),

          const Gap(AppSpacing.lg),

          if (!vue.published)
            // Le seuil s'explique, il ne se subit pas : sans cette phrase, un
            // podium vide passerait pour une panne.
            InfoBanner(
              icon: Icons.groups_outlined,
              tone: StatusTone.info,
              title: 'Le classement n’est pas encore ouvert',
              message:
                  'Encore ${vue.missing} copie(s) avant la publication. Un '
                  'classement national n’a de sens qu’avec assez de '
                  'participants.',
            )
          else ...[
            const KitSectionTitle(title: 'Les dix premiers'),
            for (final place in vue.podium)
              ListItemCard(
                leading: InitialsTile(name: '${place.rank}'),
                title: place.firstName,
                subtitle: '${place.score} / 100',
              ),
          ],
        ],
      ),
    );
  }
}

/// Le solde et son historique.
class _PointsTab extends ConsumerWidget {
  const _PointsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solde = ref.watch(pointsBalanceProvider);
    final historique = ref.watch(pointsLedgerProvider);

    return solde.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Indisponible(message: '$error'),
      data: (compte) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MetaText('Vos points'),
                const Gap(AppSpacing.xs),
                Text(
                  '${compte.balance}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(AppSpacing.xs),
                const MetaText(
                  'Les points se gagnent — concours, participation en séance. '
                  'Ils ne s’achètent pas.',
                ),
                const Gap(AppSpacing.md),
                // Un solde sans contrepartie visible n'est qu'un nombre qui
                // monte. La porte vers les lots se trouve donc là où le solde
                // se regarde.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push(Routes.shop),
                    icon: const Icon(Icons.card_giftcard_outlined),
                    label: const Text('Voir ce que mes points permettent'),
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.lg),
          const KitSectionTitle(title: 'D’où ils viennent'),
          historique.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Indisponible(message: '$error'),
            data: (lignes) => lignes.isEmpty
                ? const EmptyState(
                    icon: Icons.stars_outlined,
                    title: 'Aucun point pour l’instant',
                    message:
                        'Participez à un concours ou répondez en séance pour '
                        'commencer.',
                  )
                : Column(
                    children: [
                      for (final ligne in lignes)
                        ListItemCard(
                          leading: InitialsTile(
                            name: ligne.delta > 0 ? '+' : '-',
                            tone: ligne.delta > 0
                                ? StatusTone.success
                                : StatusTone.neutral,
                          ),
                          // La raison, pas un code : « un solde qui monte sans
                          // raison lisible ne motive pas ».
                          title: ligne.reason,
                          subtitle: Fmt.dateShort(ligne.createdAt),
                          trailing: Text(
                            ligne.delta > 0
                                ? '+${ligne.delta}'
                                : '${ligne.delta}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ligne.delta > 0
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Ce que l'écran affiche quand le serveur manque.
///
/// Un message, jamais un zéro : « 0 point » ressemble à une réponse, et l'élève
/// croirait avoir perdu ses points.
class _Indisponible extends StatelessWidget {
  const _Indisponible({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.screenH),
    child: EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Indisponible',
      message: message,
    ),
  );
}

// --- Les sources de donnees ------------------------------------------------

final contestsProvider = FutureProvider<List<Contest>>(
  (ref) => ref.watch(pointsApiProvider).contests(),
);

final leaderboardProvider = FutureProvider.family<Leaderboard, String>(
  (ref, contestId) => ref.watch(pointsApiProvider).leaderboard(contestId),
);

final pointsBalanceProvider = FutureProvider<PointsBalance>(
  (ref) => ref.watch(pointsApiProvider).balance(),
);

final pointsLedgerProvider = FutureProvider<List<PointEntry>>(
  (ref) => ref.watch(pointsApiProvider).ledger(),
);
