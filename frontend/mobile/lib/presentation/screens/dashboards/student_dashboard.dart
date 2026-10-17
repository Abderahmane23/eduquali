import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';
import '../contests/contests_page.dart' show pointsBalanceProvider;
import '../contests/shop_page.dart' show favoritesProvider;
import '../live/live_presence_strip.dart';
import '../live/live_now_section.dart';
import '../shared/promotion_slot.dart';

/// L'accueil d'un compte universitaire — quelqu'un qui suit sa propre scolarité.
///
/// --- Pourquoi un écran distinct de celui du parent ----------------------
///
/// Les deux partageaient `ParentDashboard`, qui masquait ses sections
/// « enfants » selon le rôle. Cela suffisait tant que le reste se ressemblait.
/// Ce n'est plus le cas : un universitaire veut voir **ses** cours, **ses**
/// professeurs et **ses** points, là où un parent veut voir ses enfants et ce
/// qu'ils coûtent. Continuer à empiler des conditions dans un seul écran aurait
/// fini par rendre les deux illisibles.
///
/// --- L'ordre des sections n'est pas décoratif ---------------------------
///
/// Mes cours, mes professeurs, mes favoris : du plus utilisé au moins utilisé.
/// On ouvre l'application pour reprendre un cours, parfois pour écrire à un
/// professeur, rarement pour rêver devant un lot. Chaque section porte son
/// propre bouton d'ajout, parce qu'une liste vide sans porte de sortie est un
/// cul-de-sac.
///
/// --- Le contraste ---------------------------------------------------------
///
/// Un seul aplat fort : l'en-tête dégradé. Tout le reste vit sur la surface
/// claire, et les seules couleurs saturées sont celles qui portent une
/// information — un cœur allumé, un solde. Les pastilles de l'en-tête utilisent
/// `onHeroSurface`, le blanc à 15 % prévu par le thème pour ce cas : lisible
/// sans ajouter une seconde zone criarde.
class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final nom = session?.displayName;
    final nonLues = ref.watch(unreadNotificationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(myPurchasedCoursesProvider)
          ..invalidate(parentContractsProvider)
          ..invalidate(favoritesProvider)
          ..invalidate(pointsBalanceProvider);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHero(
            eyebrow: 'Bonjour',
            title: nom == null || nom.isEmpty ? 'Bienvenue' : nom,
            actions: [
              // Le solde en haut à droite, comme demandé — et avant la cloche,
              // parce qu'on le consulte plus souvent qu'on ne lit ses
              // notifications.
              const _SoldePastille(),
              HeroIconButton(
                icon: Icons.notifications_none,
                tooltip: nonLues == 0
                    ? 'Notifications'
                    : '$nonLues notification(s) non lue(s)',
                badge: nonLues > 0,
                onPressed: () => context.push(Routes.notifications),
              ),
            ],
          ),

          const Gap(AppSpacing.lg),
          // Ce qui se passe maintenant, s'il se passe quelque chose : les deux
          // composants ne rendent rien quand il n'y a rien à dire.
          const LiveNowSection(),
          const LivePresenceStrip(),
          const WeeklyStudyCard(),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl,
              AppSpacing.screenH,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _MesCours(),
                Gap(AppSpacing.xl),
                _MesProfesseurs(),
                Gap(AppSpacing.xl),
                _MesFavoris(),
                // L'annonce d'un etablissement : un universitaire est
                // exactement la cible d'une ecole qui recrute.
                PromotionSlot(),
                // Après les trois sections demandées, pour ne pas déranger
                // leur ordre : elle n'apparaît que lorsqu'elle a quelque chose
                // à dire. C'est souvent la seule qui en a sur un compte neuf,
                // dont les cours, les professeurs et les favoris sont vides.
                Gap(AppSpacing.xl),
                _PourVotreNiveau(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le solde, en haut à droite.
///
/// Discret par construction : il vient du serveur, et tant qu'il n'a pas
/// répondu **rien ne s'affiche**. Montrer « 0 » en attendant ferait croire à un
/// solde vide à chaque ouverture, ce qui est précisément le contraire de ce
/// qu'une monnaie de fidélité doit inspirer.
class _SoldePastille extends ConsumerWidget {
  const _SoldePastille();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solde = ref.watch(pointsBalanceProvider).valueOrNull;
    if (solde == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: AppColors.onHeroSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => context.push(Routes.contests),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_outlined, size: 17, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  Fmt.money(solde.balance, withCurrency: false),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MesCours extends ConsumerWidget {
  const _MesCours();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cours = ref.watch(myPurchasedCoursesProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitSectionTitle(
          title: 'Mes cours',
          actionLabel: cours.isEmpty ? null : 'Ajouter',
          onAction: cours.isEmpty
              ? null
              : () => context.go(Routes.parentCatalog),
        ),
        if (cours.isEmpty)
          KitEmpty(
            icon: Icons.play_circle_outline,
            message:
                'Vous n’avez pas encore de cours. Le catalogue en propose en '
                'vidéo, à regarder hors ligne.',
            actionLabel: 'Voir le catalogue',
            onAction: () => context.go(Routes.parentCatalog),
          )
        else
          for (final item in cours.take(4))
            ListItemCard(
              leading: IconTile(
                icon: Icons.play_circle_outline,
                tone: StatusTone.primary,
              ),
              title: item.title,
              subtitle: item.subjectName,
              onTap: () => context.push('/catalogue/${item.id}'),
            ),
      ],
    );
  }
}

/// Ce que la classe et les matières déclarées rendent possible.
///
/// Elles étaient demandées à l'inscription et lues par aucun écran de
/// contenu : le catalogue ne filtrait que le statut, donc un universitaire qui
/// venait de déclarer sa classe et cinq matières voyait exactement le même
/// catalogue qu'un élève de CE2 — et un compte neuf n'affichait que trois
/// sections vides.
class _PourVotreNiveau extends ConsumerWidget {
  const _PourVotreNiveau();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cours = ref.watch(recommendedCoursesProvider).valueOrNull ?? const [];
    // Rien de pertinent : la section disparaît au lieu de se remplir de cours
    // d'un autre niveau, ce qui serait un titre qui ment.
    if (cours.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitSectionTitle(
          title: 'Pour votre niveau',
          actionLabel: 'Tout le catalogue',
          onAction: () => context.go(Routes.parentCatalog),
        ),
        for (final item in cours)
          ListItemCard(
            leading: IconTile(
              icon: Icons.auto_stories_outlined,
              tone: StatusTone.success,
            ),
            title: item.title,
            subtitle: item.subjectName,
            onTap: () => context.push('/catalogue/${item.id}'),
          ),
      ],
    );
  }
}

class _MesProfesseurs extends ConsumerWidget {
  const _MesProfesseurs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contrats = ref.watch(parentContractsProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitSectionTitle(
          title: 'Mes professeurs',
          actionLabel: contrats.isEmpty ? null : 'Chercher',
          onAction: contrats.isEmpty
              ? null
              : () => context.push(Routes.parentTeachers),
        ),
        if (contrats.isEmpty)
          KitEmpty(
            icon: Icons.person_search_outlined,
            message:
                'Aucun professeur pour le moment. Ceux qui se déplacent près '
                'de chez vous apparaissent dans la recherche.',
            actionLabel: 'Chercher un professeur',
            onAction: () => context.push(Routes.parentTeachers),
          )
        else
          for (final contrat in contrats.take(4))
            ListItemCard(
              leading: InitialsTile(name: contrat.counterpartName),
              title: contrat.counterpartName,
              subtitle: contrat.subjectName,
              onTap: () => context.push(Routes.contracts),
            ),
      ],
    );
  }
}

/// Les lots mis de côté dans la boutique.
///
/// En dernier, et volontairement sobre : c'est une section de motivation, pas
/// une vitrine. Elle ne doit pas peser plus que les cours.
class _MesFavoris extends ConsumerWidget {
  const _MesFavoris();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoris = ref.watch(favoritesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitSectionTitle(
          title: 'Mes favoris',
          actionLabel: 'La boutique',
          onAction: () => context.push(Routes.shop),
        ),
        favoris.when(
          // Ni roue ni message pendant le chargement : cette section est la
          // moins importante de l'écran, et un bloc qui tourne en bas attire
          // l'œil exactement là où il ne faut pas.
          loading: () => const SizedBox.shrink(),
          // Une boutique injoignable ne doit pas afficher d'erreur ici :
          // l'écran reste utile sans elle.
          error: (_, _) => const SizedBox.shrink(),
          data: (lots) => lots.isEmpty
              ? KitEmpty(
                  icon: Icons.favorite_border,
                  message:
                      'Mettez un lot de côté dans la boutique : il apparaîtra '
                      'ici, avec ce qu’il vous reste à gagner.',
                  actionLabel: 'Voir les lots',
                  onAction: () => context.push(Routes.shop),
                )
              : Column(
                  children: [
                    for (final lot in lots.take(3))
                      ListItemCard(
                        leading: lot.hasImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                child: Image.asset(
                                  lot.assetPath,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const IconTile(
                                    icon: Icons.card_giftcard_outlined,
                                    tone: StatusTone.warning,
                                  ),
                                ),
                              )
                            : const IconTile(
                                icon: Icons.redeem_outlined,
                                tone: StatusTone.primary,
                              ),
                        title: lot.name,
                        subtitle:
                            '${Fmt.money(lot.pointsPrice, withCurrency: false)} points',
                        onTap: () => context.push(Routes.shop),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Les cours vidéo déjà achetés.
///
/// Filtrés sur `purchased` plutôt que lus dans une table à part : le catalogue
/// porte déjà l'information, et une seconde source finirait par diverger de la
/// première.
final myPurchasedCoursesProvider = FutureProvider((ref) async {
  final catalogue = await ref.watch(videoCatalogProvider.future);
  return [
    for (final cours in catalogue)
      if (cours.purchased) cours,
  ];
});
