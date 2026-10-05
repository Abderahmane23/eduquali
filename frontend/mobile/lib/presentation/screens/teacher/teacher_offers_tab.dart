import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Les offres d'emploi, d'après la maquette du 23/09.
///
/// La liste reste celle des matières du professeur : un écran qui propose de
/// chercher dans tout le pays finit par afficher des postes de chimie à un
/// professeur de lettres. La recherche et les puces resserrent ce qui est
/// déjà pertinent — elles ne vont pas le chercher ailleurs, et ne peuvent
/// donc pas vider l'écran sans qu'on comprenne pourquoi.
class TeacherOffersTab extends ConsumerStatefulWidget {
  const TeacherOffersTab({super.key});

  @override
  ConsumerState<TeacherOffersTab> createState() => _TeacherOffersTabState();
}

class _TeacherOffersTabState extends ConsumerState<TeacherOffersTab> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;

  /// « Tous », puis les types de contrat. Pas de filtre par ville : elle est
  /// déjà dans la recherche, et deux chemins pour la même chose font hésiter.
  static const _filters = <({String label, ContractType? type})>[
    (label: 'Tous', type: null),
    (label: 'Vacation', type: ContractType.hourly),
    (label: 'Permanent', type: ContractType.permanent),
    (label: 'CDD', type: ContractType.fixedTerm),
    (label: 'Remplacement', type: ContractType.replacement),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(JobOffer offer) {
    final type = _filters[_filter].type;
    if (type != null && offer.contractType != type) return false;
    if (_query.isEmpty) return true;

    final q = _query.toLowerCase();
    return offer.title.toLowerCase().contains(q) ||
        offer.institution.name.toLowerCase().contains(q) ||
        offer.city.toLowerCase().contains(q) ||
        offer.subject.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(opportunitiesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(opportunitiesProvider),
      child: AsyncGate(
        value: offers,
        placeholder: const SkeletonDashboard(cards: [2, 4]),
        error: (_) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Impossible d’afficher les offres',
          message: 'Réessayez dans un instant.',
        ),
        data: (all) {
          final shown = [
            for (final offer in all)
              if (_matches(offer)) offer,
          ];
          // Mises en avant : les plus récentes, et seulement quand il y a
          // assez d'offres pour que « à la une » veuille dire quelque chose.
          final featured = all.length >= 4 ? all.take(3).toList() : const [];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              GradientHero(
                title: 'Offres d’emploi',
                subtitle: 'Trouvez votre prochain poste',
                search: HeroSearchField(
                  hint: 'Poste, établissement, ville…',
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),

              const Gap(AppSpacing.lg),
              FilterChipsRow(
                selected: _filter,
                onSelected: (i) => setState(() => _filter = i),
                items: [for (final f in _filters) (label: f.label, icon: null)],
              ),
              const Gap(AppSpacing.xl),

              if (featured.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: KitSectionTitle(title: 'À la une'),
                ),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: featured.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (_, i) => _FeaturedOffer(
                      offer: featured[i],
                      onTap: () =>
                          context.push('/teacher/jobs/${featured[i].id}'),
                    ),
                  ),
                ),
                const Gap(AppSpacing.xl),
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: KitSectionTitle(title: 'Toutes les offres'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            shown.length == 1
                                ? '1 résultat'
                                : '${shown.length} résultats',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (all.isEmpty)
                      KitEmpty(
                        icon: Icons.work_off_outlined,
                        message:
                            'Aucune offre dans vos matières. Ajoutez celles '
                            'que vous enseignez pour voir ce qui vous '
                            'correspond.',
                        actionLabel: 'Ajouter mes matières',
                        onAction: () => context.push('/teacher/subjects'),
                      )
                    else if (shown.isEmpty)
                      KitEmpty(
                        icon: Icons.search_off,
                        message: _query.isEmpty
                            ? 'Aucune offre de ce type pour le moment.'
                            : 'Rien ne correspond à « $_query ».',
                        actionLabel: 'Tout afficher',
                        onAction: () => setState(() {
                          _filter = 0;
                          _query = '';
                          _search.clear();
                        }),
                      )
                    else
                      for (final offer in shown)
                        _OfferCard(
                          offer: offer,
                          onTap: () =>
                              context.push('/teacher/jobs/${offer.id}'),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Une offre mise en avant, dans le carrousel.
class _FeaturedOffer extends StatelessWidget {
  const _FeaturedOffer({required this.offer, required this.onTap});

  final JobOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final salaire = Fmt.salaryRange(
      offer.salaryMin,
      offer.salaryMax,
      published: offer.salaryPublished,
    );
    final recente = DateTime.now().difference(offer.publishedAt).inDays <= 3;

    return Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 268,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroStart, AppColors.heroEnd],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.raised,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.onHeroSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    InitialsTile.initialsOf(offer.institution.name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                if (recente)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onHeroSurface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      'Nouveau',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              offer.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              offer.institution.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onHeroMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // Sans salaire publié, on le dit : une carte muette laisse
              // croire que l'offre en cache un.
              salaire ?? 'Salaire à discuter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une offre dans la liste.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});

  final JobOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final salaire = Fmt.salaryRange(
      offer.salaryMin,
      offer.salaryMax,
      published: offer.salaryPublished,
    );
    final recente = DateTime.now().difference(offer.publishedAt).inDays <= 3;
    final urgente =
        offer.closesAt != null &&
        offer.closesAt!.difference(DateTime.now()).inDays <= 7;

    return ListItemCard(
      onTap: onTap,
      leading: InitialsTile(name: offer.institution.name),
      title: offer.title,
      subtitle: offer.institution.name,
      chips: [
        TagChip(label: offer.contractType.shortLabel, tone: StatusTone.primary),
        if (recente) const TagChip(label: 'Nouveau', tone: StatusTone.success),
        if (urgente) const TagChip(label: 'Urgent', tone: StatusTone.danger),
        if (offer.hasApplied)
          const TagChip(label: 'Candidature envoyée', tone: StatusTone.info),
      ],
      meta: [
        MetaText(offer.city, icon: Icons.place_outlined),
        MetaText(Fmt.relative(offer.publishedAt)),
        if (salaire != null)
          MoneyText(salaire)
        else
          const MetaText('Salaire à discuter'),
      ],
    );
  }
}
