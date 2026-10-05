import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/promotions_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dashboard.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';

/// Ce que la promotion a rapporté.
///
/// Un établissement paie sa formule Master pour être montré aux familles.
/// Sans cette page, il paie et ne sait rien : ni combien de fois sa promotion
/// a été vue, ni combien de jours il lui reste. Le message « Votre promotion
/// est en ligne » était le dernier mot de l'application sur le sujet.
///
/// Le chiffre affiché est le nombre d'affichages : c'est exactement ce que
/// la mise en avant produit. On ne montre pas de « taux » ni d'estimation de
/// portée — ce seraient des nombres construits, et un directeur qui compare
/// deux mois a besoin d'un compteur, pas d'un indice.
class InstitutionPromotionsTab extends ConsumerWidget {
  const InstitutionPromotionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions =
        ref.watch(institutionPromotionsProvider).valueOrNull ?? const [];

    final enLigne = [
      for (final p in promotions)
        if (p.isActive) p,
    ];
    final terminees = [
      for (final p in promotions)
        if (!p.isActive) p,
    ];
    final vues = promotions.fold<int>(0, (n, p) => n + p.row.views);

    return RefreshIndicator(
      onRefresh: () async => refreshPromotions(ref),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHero(
            title: 'Ma promotion',
            subtitle: 'Ce que votre mise en avant a rapporté',
            actions: [
              HeroIconButton(
                icon: Icons.add,
                tooltip: 'Nouvelle promotion',
                onPressed: () => context.push(Routes.promotionNew),
              ),
            ],
            bottom: promotions.isEmpty
                ? null
                : HeroStatStrip(
                    items: [
                      (value: '$vues', label: 'Affichages'),
                      (value: '${enLigne.length}', label: 'En ligne'),
                      (value: '${terminees.length}', label: 'Terminées'),
                    ],
                  ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (promotions.isEmpty)
                  KitEmpty(
                    icon: Icons.campaign_outlined,
                    message:
                        'Aucune promotion. Une mise en avant place votre '
                        'établissement devant les familles qui cherchent une '
                        'école près de chez elles.',
                    actionLabel: 'Mettre en ligne une promotion',
                    onAction: () => context.push(Routes.promotionNew),
                  )
                else ...[
                  if (enLigne.isNotEmpty) ...[
                    const KitSectionTitle(title: 'En ligne'),
                    for (final promotion in enLigne)
                      _PromotionCard(promotion: promotion),
                    const Gap(AppSpacing.lg),
                  ],
                  if (terminees.isNotEmpty) ...[
                    const KitSectionTitle(title: 'Terminées'),
                    for (final promotion in terminees)
                      _PromotionCard(promotion: promotion),
                    const Gap(AppSpacing.lg),
                  ],
                  AddPill(
                    label: 'Nouvelle promotion',
                    onTap: () => context.push(Routes.promotionNew),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une promotion et ses chiffres.
class _PromotionCard extends ConsumerWidget {
  const _PromotionCard({required this.promotion});

  final PromotionItem promotion;

  /// Les jours qu'il reste. Nul quand la promotion est terminée ou n'a pas
  /// de fin : afficher « 0 jour » sur une promotion terminée se lit comme
  /// « elle finit aujourd'hui ».
  int? get _joursRestants {
    final fin = promotion.row.endsAt;
    if (!promotion.isActive || fin == null) return null;
    final reste = fin.difference(DateTime.now()).inDays;
    return reste < 0 ? 0 : reste;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reste = _joursRestants;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: KitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    promotion.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusPill(
                  label: promotion.status.label,
                  tone: promotion.isActive
                      ? StatusTone.success
                      : StatusTone.neutral,
                ),
              ],
            ),

            const Gap(AppSpacing.md),
            StatRow(
              tiles: [
                StatTile(value: '${promotion.row.views}', label: 'Affichages'),
                StatTile(
                  value: reste == null ? '—' : '$reste j',
                  label: 'Jours restants',
                ),
              ],
            ),

            if (promotion.isActive) ...[
              const Gap(AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _retirer(context, ref),
                  child: const Text('Retirer de la mise en avant'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Retirer est définitif : on le dit avant, pas après.
  Future<void> _retirer(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer cette promotion ?'),
        content: const Text(
          'Elle ne sera plus montrée aux familles. Vous pourrez en mettre '
          'une autre en ligne quand vous voudrez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    await ref.read(promotionsRepositoryProvider).end(promotion.id);
    refreshPromotions(ref);
  }
}
