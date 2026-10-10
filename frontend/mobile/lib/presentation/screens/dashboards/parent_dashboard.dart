import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/children_repository.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../live/live_presence_strip.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';
import '../live/live_now_section.dart';
import '../shared/promotion_slot.dart';

/// L'accueil du parent, d'après les maquettes du 23/09.
///
/// Ses enfants, ses contrats, sa prochaine échéance. Sur la ligne d'un
/// enfant, « sans professeur » est écrit en toutes lettres : c'est ce qu'un
/// parent vient vérifier, et le passer sous silence le laisserait croire que
/// tout est en place.
class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentChildrenProvider).valueOrNull ?? const [];
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];
    final contracts =
        ref.watch(parentContractsProvider).valueOrNull ?? const [];
    final stats = ref.watch(familyMetricsProvider).valueOrNull;
    final name = ref.watch(currentSessionProvider)?.displayName;
    // Les cinq premiers du classement, deja tries par compatibilite, et
    // restreints a ceux qui se deplacent : c'est le seul type de professeur
    // qu'une famille peut reserver.
    // Filtrés sur le palier de l'apprenant **et sur la ville**, comme la liste
    // complète : c'est le carrousel de l'accueil, donc la toute première liste
    // de professeurs que quelqu'un voit. Y laisser des chargés de cours
    // d'université pour un collégien contredirait l'écran suivant.
    //
    // La ville était passée à `null` (04/10) : le carrousel listait toute la
    // Guinée alors que l'étape d'inscription qui recueille le quartier annonce
    // « Le quartier décide des professeurs qui peuvent venir », et que l'écran
    // de recherche, à un geste de là, filtrait bien. Deux listes, deux règles,
    // et c'était celle de l'accueil qui démentait la promesse.
    //
    // Sans ville renseignée, le dépôt garde la liste large plutôt que vide.
    final ville = ref.watch(parentRecordProvider).valueOrNull?.city;
    final enAvant =
        (ref.watch(bookableTeachersProvider(ville)).valueOrNull ?? const [])
            .take(5)
            .toList();
    // Les demandes parties dont on attend encore la reponse.
    final enAttente = [
      for (final demande
          in ref.watch(parentTutoringRequestsProvider).valueOrNull ?? const [])
        if (demande.status == TutoringStatus.sent) demande,
    ];
    // Un etudiant majeur s'inscrit pour lui-meme : il *est* l'eleve. Lui
    // montrer « Mes enfants » lui demande de se chercher dans une liste ou
    // il ne figure pas.
    final suitDesEnfants =
        ref.watch(currentSessionProvider)?.role == UserRole.parent;

    String levelName(String? id) =>
        levels.where((l) => l.id == id).map((l) => l.name).firstOrNull ?? '—';

    /// Un enfant est couvert dès qu'un contrat en cours le nomme.
    bool hasTeacher(String childId) =>
        contracts.any((c) => c.row.childId == childId && c.isActive);

    final nonLues = ref.watch(unreadNotificationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshContracts(ref);
        refreshMetrics(ref);
        ref.invalidate(parentChildrenProvider);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHero(
            eyebrow: 'Bonjour',
            title: name == null || name.isEmpty ? 'Bienvenue' : name,
            actions: [
              HeroIconButton(
                icon: Icons.notifications_none,
                tooltip: nonLues == 0
                    ? 'Notifications'
                    : '$nonLues notification(s) non lue(s)',
                // La pastille existait dans le composant sans etre branchee :
                // la cloche etait donc muette, et une demande de cours
                // arrivait sans que personne ne le sache.
                badge: nonLues > 0,
                onPressed: () => context.push(Routes.notifications),
              ),
            ],
            bottom: stats == null
                ? null
                : HeroStatStrip(
                    items: [
                      if (suitDesEnfants)
                        (value: '${children.length}', label: 'Enfants'),
                      (
                        value: '${stats.sessionsDone}/${stats.sessionsPlanned}',
                        label: 'Séances ce mois',
                      ),
                      (
                        value: Fmt.compactMoney(stats.monthlyCost),
                        label: 'GNF par mois',
                      ),
                    ],
                  ),
          ),

          // « Fatoumata suit Mathématiques — en direct depuis 23 min ».
          //
          // Juste sous l'en-tête, avant tout le reste : un parent qui veut
          // savoir si son enfant est en cours ne doit pas avoir à faire défiler.
          // Les deux composants ne rendent rien quand il n'y a rien à dire,
          // donc ils ne coûtent aucune place aux autres comptes.
          const Gap(AppSpacing.lg),
          const LiveNowSection(),
          const LivePresenceStrip(),
          // L'annonce d'un etablissement, pour les comptes en formule FREE.
          // Le serveur decide qui en voit une : payer, c'est ne plus en voir.
          const PromotionSlot(),
          const WeeklyStudyCard(),

          // Cinq professeurs, en tête : c'est ce qu'une famille vient
          // chercher, et le lui montrer évite d'avoir à ouvrir la recherche
          // pour découvrir qu'il y a du monde.
          const Gap(AppSpacing.xl),
          KitCarousel(
            title: 'Professeurs disponibles',
            actionLabel: 'Voir tout',
            onAction: () => context.push(Routes.parentTeachers),
            children: [
              for (final t in enAvant)
                TeacherMiniCard(
                  name: t.profile.fullName,
                  subtitle: t.profile.capabilities
                      .map((c) => c.subject.name)
                      .join(' · '),
                  city: t.profile.city,
                  photoPath: t.profile.photoPath,
                  onTap: () => context.push('/teachers/${t.profile.teacherId}'),
                ),
            ],
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
                const KitSectionTitle(title: 'Actions rapides'),
                KitGrid(
                  children: [
                    ActionCard(
                      compact: true,
                      icon: Icons.person_search_outlined,
                      title: 'Chercher un professeur',
                      onTap: () => context.push(Routes.parentTeachers),
                    ),
                    ActionCard(
                      compact: true,
                      icon: Icons.play_circle_outline,
                      title: 'Cours vidéo',
                      tone: StatusTone.success,
                      onTap: () => context.go(Routes.parentCatalog),
                    ),
                    // Les cours en direct ont besoin d'une porte d'entrée :
                    // sans elle, une famille ne découvre leur existence que
                    // par le site, et la grille reste vide faute de public.
                    ActionCard(
                      compact: true,
                      icon: Icons.sensors,
                      title: 'Cours en direct',
                      tone: StatusTone.primary,
                      onTap: () => context.push(Routes.live),
                    ),
                    // Même raison que les cours en direct : sans porte
                    // d'entrée, un concours hebdomadaire n'a pas de public, et
                    // un classement sans participants ne s'ouvre jamais.
                    ActionCard(
                      compact: true,
                      icon: Icons.emoji_events_outlined,
                      title: 'Concours et points',
                      tone: StatusTone.warning,
                      onTap: () => context.push(Routes.contests),
                    ),
                  ],
                ),

                // --- Les demandes parties, et sans réponse ----------
                //
                // Une demande envoyée disparaissait de l'écran : la famille
                // revenait sur la fiche du professeur pour voir si quelque
                // chose avait bougé, et n'y trouvait rien non plus. Le nom
                // du professeur attendu se lit ici, dès l'accueil.
                if (enAttente.isNotEmpty) ...[
                  const Gap(AppSpacing.lg),
                  const KitSectionTitle(title: 'Demandes envoyées'),
                  for (final demande in enAttente)
                    ListItemCard(
                      onTap: () =>
                          context.push('/teachers/${demande.offer.teacherId}'),
                      leading: InitialsTile(
                        name: demande.offer.teacherName,
                        tone: StatusTone.info,
                      ),
                      title: demande.offer.teacherName,
                      subtitle: demande.offer.subjectName,
                      chips: const [
                        TagChip(
                          label: 'En attente de confirmation',
                          tone: StatusTone.info,
                        ),
                      ],
                    ),
                ],

                // Ce que la classe et les matieres declarees rendent
                // possible. Elles n'etaient lues par aucun ecran de contenu.
                const _PourSonNiveau(),

                // --- Qui suit qui : un parent seulement -------------
                if (suitDesEnfants) ...[
                  const Gap(AppSpacing.lg),
                  KitSectionTitle(
                    title: 'Mes enfants',
                    actionLabel: children.isEmpty ? null : 'Ajouter',
                    onAction: children.isEmpty
                        ? null
                        : () => context.push(Routes.parentChildren),
                  ),
                  if (children.isEmpty)
                    KitEmpty(
                      icon: Icons.child_care_outlined,
                      message:
                          'Ajoutez votre enfant pour lui trouver un professeur '
                          'à son niveau.',
                      actionLabel: 'Ajouter un enfant',
                      onAction: () => context.push(Routes.parentChildren),
                    )
                  else
                    for (final child in children)
                      ListItemCard(
                        onTap: () => context.push(Routes.parentChildren),
                        leading: InitialsTile(
                          name: child.firstName,
                          tone: hasTeacher(child.id)
                              ? StatusTone.success
                              : StatusTone.warning,
                        ),
                        title: child.firstName,
                        subtitle: levelName(child.levelId),
                        chips: [
                          if (hasTeacher(child.id))
                            const TagChip(
                              label: 'Suivi',
                              tone: StatusTone.success,
                            )
                          else
                            const TagChip(
                              label: 'Sans professeur',
                              tone: StatusTone.warning,
                            ),
                        ],
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

/// Les cours qui correspondent a la classe et aux matieres de l'apprenant.
///
/// Le titre parle de l'enfant suivi, pas du parent : c'est lui qui a un
/// niveau. Rien de pertinent, et la section disparait — un titre « Pour sa
/// classe » au-dessus de cours d'une autre classe serait un mensonge.
class _PourSonNiveau extends ConsumerWidget {
  const _PourSonNiveau();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cours = ref.watch(recommendedCoursesProvider).valueOrNull ?? const [];
    if (cours.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(AppSpacing.lg),
        KitSectionTitle(
          title: 'Pour sa classe',
          actionLabel: 'Tout le catalogue',
          onAction: () => context.go(Routes.parentCatalog),
        ),
        for (final item in cours)
          ListItemCard(
            leading: const IconTile(
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

/// Les matières où l'enfant a besoin d'aide, telles que le parent les a
/// déclarées. Sert au libellé d'un contrat créé depuis cet écran.
List<String> childSubjects(String raw) => ChildrenRepository.split(raw);
