import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/usecases/subscription_rules.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Propose l'abonnement au moment où il manque.
///
/// Demandé là où le geste est refusé, et non à l'avance : une personne qui
/// vient d'essayer de contacter un professeur sait exactement ce qu'elle
/// achète. La même feuille demandée sur un écran d'accueil ne répond à
/// aucune question qu'on se pose encore.
///
/// [required] est la formule minimale qui ouvre la fonction ; [because] dit
/// en une ligne pourquoi on la propose maintenant.
Future<bool> showSubscriptionSheet(
  BuildContext context, {
  required SubscriptionPlan required,
  required String because,
}) async {
  final souscrit = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SubscriptionSheet(required: required, because: because),
  );
  return souscrit ?? false;
}

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({required this.required, required this.because});

  final SubscriptionPlan required;
  final String because;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_SubscriptionSheet> {
  bool _busy = false;

  /// Les formules qui ouvrent la fonction : inutile de proposer celles qui
  /// ne la débloquent pas — elles feraient payer pour rien.
  List<SubscriptionPlan> get _offres => [
    for (final p in SubscriptionPlan.values)
      if (p != SubscriptionPlan.free && p.covers(widget.required)) p,
  ];

  Future<void> _subscribe(SubscriptionPlan plan) async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).subscribe(plan);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Passer à l’abonnement'),
          Text(
            widget.because,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(AppSpacing.lg),

          for (final plan in _offres) ...[
            KitCard(
              onTap: _busy ? null : () => _subscribe(plan),
              child: Row(
                children: [
                  IconTile(
                    icon: plan == SubscriptionPlan.master
                        ? Icons.workspace_premium_outlined
                        : Icons.verified_outlined,
                    tone: plan == SubscriptionPlan.master
                        ? StatusTone.warning
                        : StatusTone.primary,
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.label,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (plan == SubscriptionPlan.recommended) ...[
                              const SizedBox(width: AppSpacing.sm),
                              const StatusPill(
                                label: 'Le plus choisi',
                                tone: StatusTone.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan == SubscriptionPlan.master
                              ? 'Tout Pro, plus la mise en avant'
                              : 'Contact direct, messagerie et favoris',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  MoneyText(Fmt.money(plan.monthlyPriceGnf), suffix: '/mois'),
                ],
              ),
            ),
            const Gap(AppSpacing.md),
          ],

          const Gap(AppSpacing.xs),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    ),
  );
}
