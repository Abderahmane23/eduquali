import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';
import '../assistant/assistant_screen.dart';
import '../catalog/catalog_page.dart';
import '../dashboards/calendar_page.dart';
import '../dashboards/parent_dashboard.dart';
import '../dashboards/student_dashboard.dart';
import '../chat/chat_groups_page.dart';

/// Espace parent (§55-bis).
///
/// Quatre onglets : l'accueil — les séances passées et à venir —, trouver un
/// répétiteur, suivre ses demandes, gérer son compte et ses enfants.
///
/// L'accueil a remplacé l'ancien onglet « Écoles » : un parent ouvre
/// l'application pour savoir quand son enfant a cours, pas pour parcourir un
/// annuaire d'établissements. La recherche d'école reste accessible depuis
/// les actions rapides.
class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  late int _tab = widget.initialTab;

  /// Changer d'onglet depuis un écran vide (« Voir les professeurs »).
  void setTab(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pas de `SafeArea` ici : l'en-tete degrade monte jusqu'au bord et
      // gere lui-meme la barre d'etat. L'envelopper laisserait un bandeau
      // blanc au-dessus du violet.
      body: switch (_tab) {
        1 => const CalendarPage(),
        2 => const CatalogPage(),
        // Les groupes de cours et les fils a deux, au meme endroit.
        3 => const ChatGroupsPage(),
        4 => const AssistantScreen(),
        5 => const _ProfileTab(),
        /*
         * Deux accueils, une seule coquille.
         *
         * Les onglets — agenda, catalogue, messages, assistant, profil — servent
         * les deux comptes sans changement : ce qu'on y fait ne depend pas de
         * savoir si l'on suit sa propre scolarite ou celle d'un enfant. Seul
         * l'accueil differe vraiment, et c'est donc le seul ecran dedouble.
         *
         * Dupliquer la coquille entiere aurait recopie six onglets pour en
         * changer un.
         */
        _ =>
          ref.watch(currentSessionProvider)?.role == UserRole.student
              ? const StudentDashboard()
              : const ParentDashboard(),
      },
      bottomNavigationBar: KitBottomNav(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        // L'ordre suit l'usage : ce qu'on fait aujourd'hui, puis ce qu'on
        // regarde, puis les outils, le profil en dernier.
        items: const [
          (icon: Icons.home_outlined, active: Icons.home, label: 'Accueil'),
          (
            icon: Icons.calendar_month_outlined,
            active: Icons.calendar_month,
            label: 'Agenda',
          ),
          (
            icon: Icons.play_circle_outline,
            active: Icons.play_circle,
            label: 'Vidéos',
          ),
          (icon: Icons.forum_outlined, active: Icons.forum, label: 'Messages'),
          (
            icon: Icons.auto_awesome_outlined,
            active: Icons.auto_awesome,
            label: 'Assistant',
          ),
          (icon: Icons.person_outline, active: Icons.person, label: 'Profil'),
        ],
      ),
    );
  }
}

// --- Calendrier : voir `dashboards/calendar_page.dart` -------------------

// --- Accueil : voir `dashboards/parent_dashboard.dart` ---------------------

// --- Écoles ----------------------------------------------------------------

/// L'annuaire des etablissements, ouvert depuis l'accueil.
class ParentSchoolsScreen extends StatelessWidget {
  const ParentSchoolsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    // Ouvert depuis l'accueil : sans bouton de retour, on reste coince.
    appBar: AppBar(leading: const BackButton()),
    body: const SafeArea(child: _SchoolsTab()),
  );
}

class _SchoolsTab extends ConsumerWidget {
  const _SchoolsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = ref.watch(parentRecordProvider);
    final city = parent.valueOrNull?.city;
    final async = ref.watch(institutionProfilesProvider(city));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: 'Écoles et universités',
          subtitle: city == null
              ? 'Tous les établissements'
              : 'À $city — et partout ailleurs si vous élargissez',
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Liste indisponible',
              message: '$error',
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.school_outlined,
                  title: 'Aucun établissement ici',
                  message: city == null
                      ? 'La liste est vide pour le moment.'
                      : 'Aucun établissement enregistré à $city.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _SchoolCard(institution: items[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.institution});

  final InstitutionSummary institution;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final origin = institution.originLine;

    return InkWell(
      onTap: () => context.push('/parent/etablissement/${institution.id}'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    institution.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (institution.isVerified) ...[
                  const Gap(AppSpacing.xs),
                  const StatusPill(label: 'Vérifié', tone: StatusTone.success),
                ],
              ],
            ),
            const Gap(AppSpacing.xxs),
            Text(
              [institution.type.label, institution.city, ?origin].join(' · '),
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (institution.specialties.isNotEmpty) ...[
              const Gap(AppSpacing.sm),
              Text(
                // Trois filieres suffisent a situer un etablissement ; la
                // liste complete est sur la fiche.
                institution.specialties.take(3).join(' · '),
                style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Professeurs -----------------------------------------------------------

/// La recherche de repetiteurs, ouverte depuis l'accueil.
///
/// Elle occupait un onglet ; le catalogue l'a remplacee. Un parent cherche
/// un professeur ponctuellement, il regarde ses cours tous les jours.
class ParentTeachersScreen extends StatelessWidget {
  const ParentTeachersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: const SafeArea(child: _TeachersTab()),
  );
}

class _TeachersTab extends ConsumerWidget {
  const _TeachersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = ref.watch(parentRecordProvider);
    final city = parent.valueOrNull?.city;
    /*
     * Deux filtres, et chacun répond à une phrase de la note du 02/10.
     *
     * « Par défaut à domicile » : les autres ne se réservent pas, et leur fiche
     * n'offre rien à une famille. « Pas de prof universitaire pour des élèves » :
     * c'est le palier de l'apprenant qui décide.
     *
     * Les deux sont des défauts, pas des prisons — le second s'annonce et se
     * retire juste en dessous. Une liste filtrée en silence fait croire qu'il
     * n'y a que trois professeurs dans la ville.
     */
    final async = ref.watch(bookableTeachersProvider(city));

    final apprenants =
        ref.watch(parentChildrenProvider).valueOrNull ?? const [];
    final apprenant = ref.watch(selectedLearnerProvider).valueOrNull;
    final cycle = ref.watch(learnerCycleProvider).valueOrNull;
    final actif = ref.watch(cycleFilterEnabledProvider);
    final mord = ref.watch(cycleFilterBitesProvider(city)).valueOrNull ?? false;
    final noms = ref.watch(stageNamesProvider).valueOrNull ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: 'Professeurs disponibles',
          subtitle: city == null
              ? 'Renseignez votre ville pour voir ceux près de chez vous'
              : 'À $city',
        ),

        // Choisir de qui on parle, dès qu'il y a plus d'un apprenant : un
        // collégien et un lycéen n'appellent pas les mêmes professeurs, et
        // filtrer sur le premier sans le dire serait faux une fois sur deux.
        if (apprenants.length > 1) ...[
          FilterChipsRow(
            items: [
              for (final a in apprenants) (label: a.firstName, icon: null),
            ],
            selected: apprenants
                .indexWhere((a) => a.id == apprenant?.id)
                .clamp(0, apprenants.length - 1),
            onSelected: (i) =>
                ref.read(selectedLearnerIdProvider.notifier).state =
                    apprenants[i].id,
          ),
          const Gap(AppSpacing.sm),
        ],

        // L'indication ne s'affiche que si le filtre écarte vraiment
        // quelqu'un : annoncer un filtre qui ne retire rien apprend à
        // l'ignorer, et la fois où il compte, il ne se lit plus.
        if (cycle != null && mord)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.sm,
            ),
            child: InfoBanner(
              icon: Icons.filter_alt_outlined,
              tone: StatusTone.neutral,
              message: actif
                  ? 'Niveau ${noms[cycle] ?? cycle} : les professeurs qui '
                        'n’enseignent pas à ce niveau sont masqués.'
                  : 'Tous les niveaux sont affichés, y compris '
                        'l’enseignement supérieur.',
              actionLabel: actif ? 'Tout voir' : 'Filtrer',
              onAction: () =>
                  ref.read(cycleFilterEnabledProvider.notifier).state = !actif,
            ),
          ),

        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Liste indisponible',
              message: '$error',
            ),
            data: (items) {
              if (items.isEmpty) {
                // Quand c'est le filtre qui a vidé la liste, le dire. Annoncer
                // « aucun professeur à Conakry » alors qu'il y en a, mais d'un
                // autre niveau, envoie chercher ailleurs pour rien.
                final filtreCoupable = actif && mord && cycle != null;
                return EmptyState(
                  icon: Icons.person_search_outlined,
                  title: filtreCoupable
                      ? 'Aucun professeur à ce niveau'
                      : 'Aucun professeur disponible',
                  message: filtreCoupable
                      ? 'Personne n’enseigne au niveau '
                            '${noms[cycle] ?? cycle} ici pour le moment. '
                            'D’autres professeurs existent à d’autres niveaux.'
                      : city == null
                      ? 'Aucun professeur disponible pour le moment.'
                      : 'Aucun professeur disponible à $city pour le moment.',
                  actionLabel: filtreCoupable ? 'Voir tous les niveaux' : null,
                  onAction: filtreCoupable
                      ? () =>
                            ref
                                    .read(cycleFilterEnabledProvider.notifier)
                                    .state =
                                false
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
                itemBuilder: (context, index) {
                  final profile = items[index].profile;
                  return InkWell(
                    onTap: () => context.push('/teachers/${profile.teacherId}'),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: AppCard(
                      child: Row(
                        children: [
                          ProfileAvatar(
                            firstName: profile.firstName,
                            lastName: profile.lastName,
                            photoPath: profile.photoPath,
                            size: 44,
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  profile.displayHeadline,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (profile.badges.contains(TrustBadge.identity)) ...[
                            const Gap(AppSpacing.xs),
                            const Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: AppColors.success,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Profil ----------------------------------------------------------------

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final parent = ref.watch(parentRecordProvider);
    final children = ref.watch(parentChildrenProvider).valueOrNull ?? const [];
    final role = session?.role ?? UserRole.parent;

    // Un étudiant majeur s'inscrit pour lui-même : il n'a pas d'enfants à
    // gérer, il *est* l'élève. Lui montrer « Mes enfants » lui demande de se
    // chercher dans une liste où il ne figure pas.
    final suitDesEnfants = role == UserRole.parent;
    final nom = [
      session?.firstName ?? '',
      session?.lastName ?? '',
    ].join(' ').trim();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // L'en-tête dégradé règle au passage le contenu collé au bord haut :
        // la coquille du parent n'a plus de `SafeArea`, c'est l'en-tête qui
        // s'occupe de la barre d'état.
        GradientHero(
          title: 'Mon profil',
          actions: [
            HeroIconButton(
              icon: Icons.logout,
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go(Routes.splash);
              },
            ),
          ],
          bottom: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    firstName: session?.firstName ?? '',
                    lastName: session?.lastName ?? '',
                    size: 66,
                  ),
                  const Gap(AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom.isEmpty ? role.label : nom,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          session?.phone ?? role.label,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.onHeroMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (suitDesEnfants) ...[
                const Gap(AppSpacing.lg),
                HeroStatStrip(
                  items: [
                    (value: '${children.length}', label: 'Enfants'),
                    (value: parent.valueOrNull?.city ?? '—', label: 'Ville'),
                    (value: role.label, label: 'Profil'),
                  ],
                ),
              ],
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
              if (suitDesEnfants) ...[
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
                        'Aucun enfant enregistré. Ajoutez-en un pour recevoir '
                        'des propositions adaptées à sa classe.',
                    actionLabel: 'Ajouter un enfant',
                    onAction: () => context.push(Routes.parentChildren),
                  )
                else
                  for (final child in children)
                    ListItemCard(
                      onTap: () => context.push(Routes.parentChildren),
                      leading: InitialsTile(name: child.firstName),
                      title: child.firstName,
                      subtitle: child.schoolName ?? 'École non renseignée',
                    ),
                const Gap(AppSpacing.lg),
              ],

              // Déplacés de l'accueil le 24/09 : ce sont des choses qu'on
              // consulte, pas des choses qu'on fait tous les jours. L'accueil
              // sert à trouver un professeur ; le profil, à gérer ce qui est
              // déjà en place.
              const KitSectionTitle(title: 'Mes engagements'),
              _Lien(
                icon: Icons.handshake_outlined,
                label: 'Mes contrats',
                onTap: () => context.push(Routes.contracts),
              ),
              _Lien(
                icon: Icons.receipt_long_outlined,
                label: 'Mes paiements',
                tone: StatusTone.warning,
                onTap: () => context.push(Routes.payments),
              ),
              _Lien(
                icon: Icons.credit_card_outlined,
                label: 'Moyens de paiement',
                tone: StatusTone.success,
                onTap: () => context.push(Routes.paymentMethods),
              ),

              const Gap(AppSpacing.lg),
              const KitSectionTitle(title: 'Compte'),
              KitCard(
                child: Column(
                  children: [
                    if (parent.valueOrNull?.city != null) ...[
                      InfoRow(
                        icon: Icons.place_outlined,
                        label: 'Ville',
                        value: parent.valueOrNull!.city!,
                      ),
                      const Divider(height: 20),
                    ],
                    InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Profil',
                      value: role.label,
                    ),
                    if (session?.phone != null) ...[
                      const Divider(height: 20),
                      InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Téléphone',
                        value: session!.phone,
                      ),
                    ],
                  ],
                ),
              ),

              const Gap(AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).logout();
                  if (context.mounted) context.go(Routes.splash);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(AppSpacing.xxs),
          Text(
            subtitle,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de renvoi sur la page profil : pastille, libellé, chevron.
class _Lien extends StatelessWidget {
  const _Lien({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = StatusTone.primary,
  });

  final IconData icon;
  final String label;
  final StatusTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: KitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconTile(icon: icon, tone: tone, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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
