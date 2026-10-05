import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import '../providers/core_providers.dart';
import '../theme/app_theme.dart';

/// Bandeau d'état réseau (§42).
///
/// Distingue les quatre états plutot que d'opposer « en ligne » et « hors
/// ligne » : l'utilisateur sait s'il n'a aucun réseau, un réseau sans
/// Internet, ou un Internet dont le serveur reste injoignable.
class NetworkBanner extends ConsumerWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cette version n'a pas de serveur : annoncer « serveur injoignable »
    // sur chaque ecran decrirait un incident, alors que c'est le
    // fonctionnement prevu. Tout vit sur l'appareil, et l'ecran de
    // synchronisation le dit une fois, en clair.
    if (!AppConstants.hasBackend) return const SizedBox.shrink();

    final state =
        ref.watch(networkStateProvider).valueOrNull ??
        ref.watch(networkServiceProvider).state;
    final sync = ref.watch(syncStateProvider).valueOrNull;

    // Serveur joignable et file vide : aucun bandeau a afficher.
    if (state == NetworkState.serverAvailable &&
        (sync == null || !sync.hasPendingWork)) {
      return const SizedBox.shrink();
    }

    final (message, tone, icon) = switch (state) {
      NetworkState.noNetwork => (
        'Aucun réseau — vos modifications sont enregistrees sur l’appareil.',
        _Tone.warning,
        Icons.signal_cellular_off,
      ),
      NetworkState.networkAvailable => (
        'Réseau sans acces Internet — synchronisation en attente.',
        _Tone.warning,
        Icons.wifi_off,
      ),
      NetworkState.internetReachable => (
        'Serveur injoignable — nouvelle tentative automatique.',
        _Tone.info,
        Icons.cloud_off_outlined,
      ),
      NetworkState.serverAvailable => (
        sync!.running
            ? 'Synchronisation en cours…'
            : '${sync.pending + sync.failed} operation(s) a synchroniser',
        _Tone.info,
        Icons.sync,
      ),
    };

    final (bg, fg) = switch (tone) {
      _Tone.warning => (AppColors.warningSurface, AppColors.warning),
      _Tone.info => (AppColors.infoSurface, AppColors.info),
    };

    return Material(
      color: bg,
      child: InkWell(
        onTap: () => context.push('/sync'),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (sync?.conflicts case final conflicts?
                    when conflicts > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '$conflicts conflit(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Tone { warning, info }
