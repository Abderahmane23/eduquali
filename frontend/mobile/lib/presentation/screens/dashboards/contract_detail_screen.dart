import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/contracts_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';

/// Ce qu'on lit au bout de la flèche d'une ligne de contrat.
///
/// Le même écran pour les trois rôles : le contrat est un objet partagé, et
/// deux versions diveregeraient sur ce qui a été convenu — exactement ce
/// qu'un contrat existe pour éviter. Seules les actions changent.
class ContractDetailScreen extends ConsumerWidget {
  const ContractDetailScreen({super.key, required this.contractId});

  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final role = session?.role;

    // On relit la liste du rôle courant : pas de requête de plus, et le
    // contrat d'autrui reste hors de portée.
    final contracts = switch (role) {
      UserRole.institution =>
        ref.watch(institutionContractsProvider).valueOrNull,
      UserRole.parent => ref.watch(parentContractsProvider).valueOrNull,
      _ => ref.watch(teacherContractsProvider).valueOrNull,
    };
    final contract = contracts?.where((c) => c.id == contractId).firstOrNull;

    return Scaffold(
      body: contract == null
          ? const EmptyState(
              icon: Icons.description_outlined,
              title: 'Contrat introuvable',
              message: 'Il a peut-être été résilié.',
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // Le montant et l'état en tête : ce sont les deux choses
                // qu'on vient vérifier sur un contrat.
                GradientHero(
                  onBack: () => Navigator.of(context).maybePop(),
                  title: contract.label,
                  subtitle: contract.counterpartName,
                  bottom: HeroStatStrip(
                    items: [
                      (
                        value: Fmt.compactMoney(contract.row.monthlyAmount),
                        label: 'GNF par mois',
                      ),
                      (value: contract.status.label, label: 'État'),
                      if (contract.row.startedAt != null)
                        (
                          value: Fmt.dateShort(contract.row.startedAt!),
                          label: 'Depuis le',
                        ),
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
                      const KitSectionTitle(title: 'Ce qui a été convenu'),
                      KitCard(
                        child: Column(
                          children: [
                            InfoRow(
                              label: role == UserRole.teacher
                                  ? 'Employeur'
                                  : 'Professeur',
                              value: contract.counterpartName,
                            ),
                            if (contract.subjectName != null) ...[
                              const Divider(height: 20),
                              InfoRow(
                                label: 'Matière',
                                value: contract.subjectName!,
                              ),
                            ],
                            if (contract.childName != null) ...[
                              const Divider(height: 20),
                              InfoRow(
                                label: 'Élève',
                                value: contract.childName!,
                              ),
                            ],
                            const Divider(height: 20),
                            InfoRow(
                              label: 'Montant mensuel',
                              value: Fmt.money(contract.row.monthlyAmount),
                            ),
                          ],
                        ),
                      ),

                      // « Résilier » vit ici, dans le contrat concerné, et
                      // nulle part ailleurs : une action qui prévient l'autre
                      // partie n'a pas sa place dans une liste d'actions
                      // rapides où l'on ne sait même pas lequel on résilie.
                      if (contract.isActive ||
                          (!contract.isActive &&
                              role == UserRole.institution)) ...[
                        const Gap(AppSpacing.xl),
                        const KitSectionTitle(title: 'Actions'),
                        if (!contract.isActive && role == UserRole.institution)
                          _Action(
                            icon: Icons.play_circle_outline,
                            tone: StatusTone.success,
                            label: 'Démarrer ce contrat',
                            hint: 'Les échéances commenceront à courir',
                            onTap: () => _activate(context, ref),
                          ),
                        if (contract.isActive)
                          _Action(
                            icon: Icons.cancel_outlined,
                            tone: StatusTone.danger,
                            label: 'Résilier ce contrat',
                            hint: 'L’autre partie en sera informée',
                            onTap: () => _terminate(context, ref, contract),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(contractsRepositoryProvider).activate(contractId);
    refreshContracts(ref);
    messenger.showSnackBar(
      const SnackBar(content: Text('Contrat démarré. Les échéances suivent.')),
    );
  }

  Future<void> _terminate(
    BuildContext context,
    WidgetRef ref,
    WorkContractItem contract,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(contractsRepositoryProvider)
          .terminate(contractId, reason: reason);
      refreshContracts(ref);
      if (context.mounted) context.pop();
    } on WorkContractException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Une résiliation sans motif laisse les deux parties sans rien à se dire.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Résilier le contrat'),
    content: TextField(
      controller: _reason,
      autofocus: true,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Raison',
        hintText: 'Fin d’année, déménagement, désaccord…',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _reason.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('Résilier'),
      ),
    ],
  );
}

/// Une action du contrat : pastille, libellé, conséquence.
///
/// La conséquence est écrite sous le libellé, pas cachée dans la boîte de
/// confirmation : on décide avant de taper, pas après.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tone,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final StatusTone tone;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (surface: _, :ink) = tonePair(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: KitCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconTile(icon: icon, tone: tone, size: 46),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
