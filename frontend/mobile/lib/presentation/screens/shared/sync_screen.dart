import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// État du réseau et de la synchronisation (§42, §44, §45).
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkState =
        ref.watch(networkStateProvider).valueOrNull ??
        ref.watch(networkServiceProvider).state;
    final sync = ref.watch(syncStateProvider).valueOrNull;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (!AppConstants.hasBackend) ...[
            // Dit une fois, au bon endroit : l'utilisateur qui vient voir
            // pourquoi rien ne se synchronise trouve la reponse ici, et non
            // un bandeau d'alerte sur tous les ecrans.
            const InfoBanner(
              message:
                  'Cette version fonctionne sans serveur. Votre compte, vos '
                  'offres et vos cours sont enregistrés sur cet appareil. '
                  'Ils partiront vers le serveur dès qu’il sera en ligne.',
              tone: StatusTone.info,
              icon: Icons.phone_android,
            ),
            const Gap(AppSpacing.xl),
          ],

          Text('État du réseau', style: text.titleMedium),
          const Gap(AppSpacing.md),

          // Les quatre états réseau, du plus degrade au plus complet (§42).
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < NetworkState.values.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  _NetworkStep(
                    state: NetworkState.values[i],
                    reached: NetworkState.values[i].index <= networkState.index,
                    current: NetworkState.values[i] == networkState,
                  ),
                ],
              ],
            ),
          ),

          const Gap(AppSpacing.xl),

          Text('File de synchronisation', style: text.titleMedium),
          const Gap(AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Operations en attente',
                  value: '${sync?.pending ?? 0}',
                ),
                const Divider(height: 20),
                InfoRow(
                  label: 'Operations en echec',
                  value: '${sync?.failed ?? 0}',
                  valueColor: (sync?.failed ?? 0) > 0 ? AppColors.danger : null,
                ),
                const Divider(height: 20),
                InfoRow(
                  label: 'Conflits',
                  value: '${sync?.conflicts ?? 0}',
                  valueColor: (sync?.conflicts ?? 0) > 0
                      ? AppColors.warning
                      : null,
                ),
                const Divider(height: 20),
                InfoRow(
                  label: 'Dernière synchronisation',
                  value: sync?.lastSyncAt == null
                      ? 'Jamais'
                      : Fmt.relative(sync!.lastSyncAt!),
                ),
              ],
            ),
          ),

          if (sync?.lastError != null) ...[
            const Gap(AppSpacing.md),
            InfoBanner(
              title: 'Dernière erreur',
              message: sync!.lastError!,
              tone: StatusTone.warning,
            ),
          ],

          if ((sync?.conflicts ?? 0) > 0) ...[
            const Gap(AppSpacing.md),
            const InfoBanner(
              title: 'Conflits detectes',
              message:
                  'Une donnée a ete modifiee sur un autre appareil. Aucune '
                  'modification n’est ecrasee silencieusement : ces operations '
                  'sont mises de cote pour résolution.',
              tone: StatusTone.warning,
              icon: Icons.merge_type,
            ),
          ],

          const Gap(AppSpacing.xl),

          FilledButton.icon(
            onPressed: sync?.running == true
                ? null
                : () async {
                    await ref.read(networkServiceProvider).refresh();
                    await ref.read(syncEngineProvider).synchronize();
                  },
            icon: sync?.running == true
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, size: 19),
            label: Text(
              sync?.running == true
                  ? 'Synchronisation en cours…'
                  : 'Synchroniser maintenant',
            ),
          ),

          if ((sync?.failed ?? 0) > 0) ...[
            const Gap(AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => ref.read(syncEngineProvider).retryFailed(),
              icon: const Icon(Icons.refresh, size: 19),
              label: const Text('Reessayer les operations en echec'),
            ),
          ],

          const Gap(AppSpacing.xl),
          const InfoBanner(
            title: 'Fonctionnement hors ligne',
            message:
                'Vos actions sont d’abord enregistrees sur l’appareil, puis '
                'transmises au serveur des qu’il redevient joignable. Vous '
                'pouvez continuer a utiliser l’application sans connexion.',
            tone: StatusTone.info,
            icon: Icons.offline_bolt_outlined,
          ),
        ],
      ),
    );
  }
}

class _NetworkStep extends StatelessWidget {
  const _NetworkStep({
    required this.state,
    required this.reached,
    required this.current,
  });

  final NetworkState state;
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final description = switch (state) {
      NetworkState.noNetwork => 'Aucune interface réseau active',
      NetworkState.networkAvailable =>
        'Une interface est active, sans acces Internet confirme',
      NetworkState.internetReachable => 'Internet repond aux requetes',
      NetworkState.serverAvailable =>
        'L’API de la plateforme est joignable — synchronisation possible',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          reached ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 19,
          color: current
              ? AppColors.primary
              : reached
              ? AppColors.success
              : AppColors.borderStrong,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    state.label,
                    style: text.titleSmall?.copyWith(
                      color: current ? AppColors.primary : null,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(width: 8),
                    const TagChip(label: 'Actuel', tone: StatusTone.primary),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(description, style: text.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}
