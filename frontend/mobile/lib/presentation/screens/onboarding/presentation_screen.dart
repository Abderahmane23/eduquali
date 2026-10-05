import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_flow_controller.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import 'onboarding_flow_screen.dart';

/// Écrans de présentation, montrés **après** la création du compte.
///
/// Avant, quatre écrans passaient avant de savoir à qui on parlait. Désormais
/// on ouvre le compte, puis on explique — et on peut expliquer le bon métier,
/// puisqu'on connaît enfin le profil.
///
/// Vus une fois : un rappel à chaque ouverture serait une punition.
class PresentationScreen extends ConsumerWidget {
  const PresentationScreen({super.key});

  /// Clé de mémorisation, par compte : un téléphone partagé ne doit pas
  /// priver le suivant de sa présentation.
  static String seenKey(String userId) => 'presentation_seen_$userId';

  /// Ces écrans ont-ils déjà été vus par ce compte ?
  static Future<bool> alreadySeen(WidgetRef ref, String userId) async =>
      await ref.read(databaseProvider).readMeta(seenKey(userId)) != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const SizedBox.shrink();

    Future<void> finish() async {
      await ref
          .read(databaseProvider)
          .writeMeta(seenKey(session.userId), DateTime.now().toIso8601String());
      if (context.mounted) context.go(Routes.homeFor(session.role));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: finish, child: const Text('Passer')),
          const SizedBox(width: 8),
        ],
      ),
      body: OnboardingFlowScreen(
        audience: OnboardingAudience.presentation,
        // Le rôle ne se redemande pas : il vient du compte qu'on vient
        // d'ouvrir, et décide quels écrans s'affichent.
        initialAnswers: {'role': session.role.code},
        onCompleted: (_) => finish(),
      ),
    );
  }
}
