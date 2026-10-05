import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Tous les contrats, au bout de « Voir tous les contrats ».
///
/// Le même écran pour les trois rôles, chacun voyant les siens : un contrat
/// n'a qu'une version, et deux listes divergeraient sur ce qui a été convenu.
class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentSessionProvider)?.role;
    final contracts = switch (role) {
      UserRole.institution => ref.watch(institutionContractsProvider),
      UserRole.parent => ref.watch(parentContractsProvider),
      _ => ref.watch(teacherContractsProvider),
    };

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Contrats'),
      ),
      body: AsyncGate(
        value: contracts,
        placeholder: const SkeletonDashboard(cards: [4]),
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
                icon: Icons.handshake_outlined,
                message: 'Aucun contrat pour le moment.',
              )
            else
              for (final contract in items)
                ListItemCard(
                  onTap: () => context.push(Routes.contract(contract.id)),
                  leading: IconTile(
                    icon: contract.isActive
                        ? Icons.check_circle_outline
                        : Icons.more_horiz,
                    tone: contract.isActive
                        ? StatusTone.success
                        : StatusTone.warning,
                    size: 48,
                  ),
                  title: role == UserRole.institution
                      ? contract.counterpartName
                      : contract.label,
                  subtitle: role == UserRole.institution
                      ? contract.label
                      : contract.counterpartName,
                  chips: [
                    TagChip(
                      label: contract.status.label,
                      tone: contract.isActive
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
}
