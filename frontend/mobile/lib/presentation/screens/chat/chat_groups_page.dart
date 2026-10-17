import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/remote/chat_api.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';

/// Les groupes de discussion, et les fils à deux, sur le même écran.
///
/// --- Ce que « comme Discord » veut dire ici ------------------------------
///
/// Discord mobile pose une liste de discussions, puis on entre dans l'une
/// d'elles ; le fil est une suite de lignes avec avatar, nom, heure et texte —
/// **pas des bulles**. C'est cette forme qui est reprise, parce qu'elle tient
/// plus de texte à l'écran qu'un fil à bulles, ce qui compte quand quinze
/// personnes écrivent.
///
/// --- Ce qui n'est pas repris, et pourquoi --------------------------------
///
///   * **Pas de salons dans un groupe.** Un groupe de maths de Terminale n'a
///     pas besoin de cinq sous-salons ; il a besoin d'un endroit.
///   * **Pas de découverte, pas de code d'invitation.** Un groupe existe
///     autour d'une relation — un cours suivi, un contrat — et ses membres
///     sont ceux que cette relation lie. On ne peut donc pas entrer dans un
///     groupe d'adolescents sans y avoir sa place, et la question de la
///     modération d'un groupe public ne se pose pas.
class ChatGroupsPage extends ConsumerWidget {
  const ChatGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupes = ref.watch(chatGroupsProvider);
    final fils = ref.watch(conversationsProvider).valueOrNull ?? const [];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(chatGroupsProvider),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const GradientHero(
            title: 'Discussions',
            subtitle: 'Vos groupes de cours et vos échanges',
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
                const KitSectionTitle(title: 'Groupes'),
                groupes.when(
                  loading: () => const KitEmpty(
                    icon: Icons.groups_outlined,
                    message: 'Chargement…',
                  ),
                  // Un groupe se lit au serveur : sans réseau on le dit, sans
                  // prétendre qu'il n'y en a aucun.
                  error: (erreur, _) => KitEmpty(
                    icon: Icons.cloud_off_outlined,
                    message: '$erreur',
                  ),
                  data: (liste) => liste.isEmpty
                      ? const KitEmpty(
                          icon: Icons.groups_outlined,
                          message:
                              'Vos groupes s’ouvrent tout seuls : un par cours '
                              'en direct suivi. Il n’y a rien à créer ni à '
                              'rejoindre.',
                        )
                      : Column(
                          children: [
                            for (final groupe in liste)
                              _LigneGroupe(groupe: groupe),
                          ],
                        ),
                ),

                // Les fils à deux restent : le premier contact, une question
                // qui ne regarde qu'une famille, la négociation d'un contrat.
                // Le groupe s'ajoute à côté, il ne les remplace pas.
                if (fils.isNotEmpty) ...[
                  const Gap(AppSpacing.xl),
                  const KitSectionTitle(title: 'Messages privés'),
                  for (final fil in fils)
                    ListItemCard(
                      onTap: () => context.push('/messages/${fil.id}'),
                      leading: InitialsTile(name: fil.otherName),
                      title: fil.otherName,
                      subtitle: fil.lastMessage ?? fil.subtitle,
                      trailing: fil.unread == 0
                          ? null
                          : _Pastille(nombre: fil.unread),
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

class _LigneGroupe extends StatelessWidget {
  const _LigneGroupe({required this.groupe});

  final ChatGroup groupe;

  @override
  Widget build(BuildContext context) {
    return ListItemCard(
      // Le nom part avec l'adresse : l'en-tete de la discussion s'affiche
      // tout de suite, au lieu d'attendre une lecture du serveur.
      onTap: () => context.push(
        '${Routes.chatGroup(groupe.id)}?nom=${Uri.encodeComponent(groupe.name)}',
      ),
      // Le dièse de Discord : il dit « salon » sans qu'on l'explique, et il
      // distingue le groupe du fil privé juste en dessous.
      leading: const IconTile(icon: Icons.tag, tone: StatusTone.primary),
      title: groupe.name,
      subtitle: groupe.apercu,
      trailing: groupe.lastAt == null
          ? null
          : MetaText(Fmt.relative(groupe.lastAt!)),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.nombre});

  final int nombre;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.danger,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      nombre > 9 ? '9+' : '$nombre',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Les groupes de la personne.
final chatGroupsProvider = FutureProvider<List<ChatGroup>>(
  (ref) => ref.watch(chatApiProvider).groups(),
);
