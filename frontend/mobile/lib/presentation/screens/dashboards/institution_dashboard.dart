import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';
import '../live/live_now_section.dart';

/// L'accueil de l'établissement, d'après les maquettes du 23/09.
///
/// Ses chiffres, ses professeurs, trois actions. La coche dit qui a commencé,
/// l'ondulation qui attend encore — c'est la première question que pose un
/// directeur en ouvrant l'application.
///
/// Les actions rapides sont passées de sept à trois. Sept liens empilés font
/// de l'accueil un menu, et l'accueil doit être l'écran le plus utile, pas
/// une table des matières. « Résilier un contrat » vit dans le contrat
/// concerné — une action destructrice n'a pas sa place à un doigt d'écart
/// d'actions sûres, là où l'on ne sait même pas lequel on résilie.
class InstitutionDashboard extends ConsumerWidget {
  const InstitutionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contracts =
        ref.watch(institutionContractsProvider).valueOrNull ?? const [];
    final stats = ref.watch(institutionMetricsProvider).valueOrNull;
    final name = ref.watch(currentSessionProvider)?.displayName;
    // Les cinq premiers du classement : déjà triés par compatibilité, et
    // restreints à la ville de l'établissement.
    //
    // La ville était passée à `null` (04/10) : un lycée de Conakry se voyait
    // proposer des professeurs de Kankan en tête de son accueil, alors que sa
    // ville est obligatoire et connue depuis son inscription.
    final ville = ref.watch(institutionRecordProvider).valueOrNull?.city;
    final enAvant =
        (ref.watch(availableTeachersProvider(ville)).valueOrNull ?? const [])
            .take(5)
            .toList();

    final nonLues = ref.watch(unreadNotificationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshContracts(ref);
        refreshMetrics(ref);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHero(
            eyebrow: 'Bonjour',
            title: name == null || name.isEmpty ? 'Établissement' : name,
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
                      (value: '${stats.filled}', label: 'Postes pourvus'),
                      (value: '${stats.pending}', label: 'En attente'),
                      (
                        value: Fmt.compactMoney(stats.monthlyCost),
                        label: 'GNF par mois',
                      ),
                    ],
                  ),
          ),

          // Cinq professeurs en tête : un directeur ouvre l'application pour
          // savoir qui est disponible, et devoir passer par la recherche
          // pour l'apprendre lui coûte un écran de plus chaque matin.
          const LiveNowSection(),
          const Gap(AppSpacing.xl),
          KitCarousel(
            title: 'Professeurs disponibles',
            actionLabel: 'Voir tout',
            onAction: () => context.push(Routes.institutionSearch),
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
                      title: 'Trouver un professeur',
                      onTap: () => context.push(Routes.institutionSearch),
                    ),
                    // L'etablissement ecrit aux professeurs depuis le
                    // 02/10 : il lui faut une porte pour y revenir. Pas un
                    // sixieme onglet — la barre en compte cinq, et un
                    // sixieme la rendrait illisible.
                    ActionCard(
                      compact: true,
                      icon: Icons.forum_outlined,
                      title: 'Mes messages',
                      tone: StatusTone.info,
                      onTap: () => context.push(Routes.institutionMessages),
                    ),
                    ActionCard(
                      compact: true,
                      icon: Icons.campaign_outlined,
                      title: 'Nous faire connaître',
                      tone: StatusTone.warning,
                      onTap: () => context.push(Routes.promotionNew),
                    ),
                  ],
                ),

                // --- Ce qui coûte, et ce que ça met de temps ---------------
                if (stats != null) ...[
                  const Gap(AppSpacing.lg),
                  KitGrid(
                    children: [
                      MetricCard(
                        icon: Icons.payments_outlined,
                        value: Fmt.compactMoney(stats.monthlyCost),
                        label: 'Coût mensuel (GNF)',
                        tone: StatusTone.success,
                        onTap: () => context.push(Routes.contracts),
                      ),
                      // Le delai moyen : personne ne le mesure, et c'est lui
                      // qui dit le plus. Trente jours sans demarrage, ce sont
                      // des exigences hors marche.
                      MetricCard(
                        icon: Icons.timer_outlined,
                        value: stats.averageHiringDays == null
                            ? '—'
                            : '${stats.averageHiringDays} j',
                        label: 'Délai moyen de recrutement',
                        tone: StatusTone.info,
                      ),
                    ],
                  ),
                ],

                // --- Qui travaille ici -------------------------------------
                const Gap(AppSpacing.lg),
                KitSectionTitle(
                  title: 'Professeurs',
                  actionLabel: contracts.isEmpty ? null : 'Ajouter',
                  onAction: contracts.isEmpty
                      ? null
                      : () => context.push(Routes.institutionSearch),
                ),
                if (contracts.isEmpty)
                  KitEmpty(
                    icon: Icons.groups_outlined,
                    message:
                        'Aucun professeur sous contrat. Publiez une offre ou '
                        'parcourez les profils disponibles.',
                    actionLabel: 'Ajouter un professeur',
                    onAction: () => context.push(Routes.institutionSearch),
                  )
                else
                  for (final contract in contracts)
                    ListItemCard(
                      onTap: () => context.push(Routes.contract(contract.id)),
                      leading: InitialsTile(
                        name: contract.counterpartName.isEmpty
                            ? contract.label
                            : contract.counterpartName,
                        tone: contract.isActive
                            ? StatusTone.success
                            : StatusTone.warning,
                      ),
                      title: contract.counterpartName.isEmpty
                          ? contract.label
                          : contract.counterpartName,
                      subtitle: contract.label,
                      chips: [
                        TagChip(
                          label: contract.isActive ? 'Démarré' : 'En attente',
                          tone: contract.isActive
                              ? StatusTone.success
                              : StatusTone.warning,
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
