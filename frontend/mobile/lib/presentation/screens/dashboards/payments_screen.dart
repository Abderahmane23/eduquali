import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/repositories/contracts_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Toutes les échéances, au bout de la flèche de la carte « Paiements ».
///
/// Le professeur y voit ce qui lui arrive ; le parent, ce qu'il doit. La même
/// liste, lue de chaque côté — et seul le parent peut pointer une échéance
/// comme réglée, puisque c'est lui qui paie.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentSessionProvider)?.role;
    // Un etudiant majeur paie ses propres cours : il voit « ce que je
    // dois », pas « ce que je vais recevoir ».
    final isParent = role?.followsAStudent ?? false;
    final payments = ref.watch(
      isParent ? parentPaymentsProvider : teacherPaymentsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(isParent ? 'Mes paiements' : 'Paiements'),
      ),
      body: AsyncGate(
        value: payments,
        placeholder: const SkeletonDashboard(cards: [5]),
        error: (_) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Liste indisponible',
          message: 'Réessayez dans un instant.',
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (items.isEmpty)
              const KitEmpty(
                icon: Icons.receipt_long_outlined,
                message:
                    'Aucune échéance. Elles apparaîtront dès qu’un contrat '
                    'démarre.',
              )
            else
              for (final payment in items)
                ListItemCard(
                  onTap:
                      isParent && payment.status != ContractPaymentStatus.paid
                      ? () => _pay(context, ref, payment)
                      : null,
                  leading: IconTile(
                    icon: switch (payment.status) {
                      ContractPaymentStatus.paid => Icons.check_circle_outline,
                      ContractPaymentStatus.late => Icons.warning_amber_rounded,
                      ContractPaymentStatus.due => Icons.schedule_outlined,
                    },
                    tone: switch (payment.status) {
                      ContractPaymentStatus.paid => StatusTone.success,
                      ContractPaymentStatus.late => StatusTone.danger,
                      ContractPaymentStatus.due => StatusTone.info,
                    },
                    size: 48,
                  ),
                  title: payment.contractLabel,
                  subtitle: 'Échéance du ${Fmt.date(payment.dueOn)}',
                  chips: [
                    TagChip(
                      label: payment.status.label,
                      tone: switch (payment.status) {
                        ContractPaymentStatus.paid => StatusTone.success,
                        ContractPaymentStatus.late => StatusTone.danger,
                        ContractPaymentStatus.due => StatusTone.info,
                      },
                    ),
                  ],
                  meta: [
                    // Seul le parent peut pointer une echeance comme reglee :
                    // c'est lui qui paie.
                    MetaText(
                      isParent && payment.status != ContractPaymentStatus.paid
                          ? 'Toucher pour marquer réglé'
                          : payment.status.label,
                    ),
                    MoneyText(
                      Fmt.money(payment.amount),
                      tone: payment.status == ContractPaymentStatus.paid
                          ? StatusTone.success
                          : StatusTone.warning,
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    ContractPaymentItem payment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Marquer comme réglé'),
        content: Text(
          '${payment.contractLabel} — ${Fmt.money(payment.amount)}, '
          'échéance du ${Fmt.date(payment.dueOn)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('C’est réglé'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(contractsRepositoryProvider).markPaid(payment.row.id);
    refreshContracts(ref);
  }
}
