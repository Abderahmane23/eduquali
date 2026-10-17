import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactions.dart';
import '../../widgets/common.dart';

/// Ecrans 6 et 7 établissement — Recherche d'enseignants et filtres (§21).
///
/// Les résultats sont classes par pertinence et le score reste explicable
/// (§22).
class TeacherSearchScreen extends ConsumerWidget {
  const TeacherSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(teacherSearchFiltersProvider);
    final results = ref.watch(teacherSearchProvider);
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];
    final cities = ref.watch(citiesProvider).valueOrNull ?? const [];
    final notifier = ref.read(teacherSearchFiltersProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher un enseignant')),
      body: Column(
        children: [
          // Panneau de recherche, resserré le 26/09.
          //
          // Il prenait la moitié haute de l'écran : trois lignes de menus,
          // un interrupteur pleine largeur et deux boutons de 46 px. On
          // ouvre cette page pour voir des enseignants, et il n'en restait
          // qu'un visible. Les trois menus tiennent sur une ligne, la
          // certification est devenue une puce, et « Plus de filtres » un
          // bouton d'icône — le reste vit déjà dans la feuille des filtres
          // avancés.
          Container(
            margin: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CompactDropdown<String>(
                        hint: 'Matière',
                        value: filters.subjectId,
                        items: [for (final s in subjects) (s.id, s.name)],
                        onChanged: (value) => notifier.update(
                          (f) => value == null
                              ? f.copyWith(clearSubject: true)
                              : f.copyWith(subjectId: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _CompactDropdown<String>(
                        hint: 'Niveau',
                        value: filters.levelId,
                        items: [for (final l in levels) (l.id, l.name)],
                        onChanged: (value) => notifier.update(
                          (f) => value == null
                              ? f.copyWith(clearLevel: true)
                              : f.copyWith(levelId: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _CompactDropdown<String>(
                        hint: 'Ville',
                        value: filters.city,
                        items: [for (final c in cities) (c, c)],
                        onChanged: (value) => notifier.update(
                          (f) => value == null
                              ? f.copyWith(clearCity: true)
                              : f.copyWith(city: value),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Certifié'),
                      selected: filters.certifiedOnly,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppColors.primarySurface,
                      side: BorderSide(
                        color: filters.certifiedOnly
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      labelStyle: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: filters.certifiedOnly
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      onSelected: (value) => notifier.update(
                        (f) => f.copyWith(certifiedOnly: value),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Le nombre de filtres actifs reste lisible sans le
                    // mot : c'est lui qui dit qu'une feuille cache des
                    // criteres, et sans lui on cherche pourquoi la liste
                    // est courte.
                    OutlinedButton(
                      onPressed: () => _openAdvanced(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune, size: 17),
                          if (filters.activeCount > 2) ...[
                            const SizedBox(width: 4),
                            Text('${filters.activeCount}'),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => ref.invalidate(teacherSearchProvider),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Rechercher'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: results.when(
              loading: () => const SkeletonDashboard(cards: [4]),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Recherche impossible',
                message: '$error',
              ),
              data: (candidates) {
                if (candidates.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Aucun enseignant trouve',
                    message:
                        'Élargissez vos critères : matière, niveau, ville ou '
                        'exigence de certification.',
                    actionLabel: filters.activeCount > 0
                        ? 'Reinitialiser les filtres'
                        : null,
                    onAction: filters.activeCount > 0
                        ? () => notifier.state = const TeacherSearchFilters()
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: candidates.length + 1,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.md),
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${candidates.length} enseignant(s) — classes par '
                          'pertinence',
                          style: text.bodySmall,
                        ),
                      );
                    }
                    return _CandidateCard(
                      candidate: candidates[index - 1],
                      rank: index,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdvanced(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _AdvancedFilters(),
      );
}

/// Carte candidat classee (§22) — badges, score et compatibilite.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.rank});

  final RankedCandidate candidate;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final profile = candidate.profile;
    final bestCert = profile.certifications.isEmpty
        ? null
        : profile.certifications.first;

    return AppCard(
      onTap: () => context.push('/teachers/${profile.teacherId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ProfileAvatar(
                    firstName: profile.firstName,
                    lastName: profile.lastName,
                    photoPath: profile.photoPath,
                    size: 48,
                  ),
                  if (rank <= 3)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.fullName,
                            style: text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.hasBoost) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.trending_up,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(profile.displayHeadline, style: text.bodySmall),
                    if (bestCert != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${bestCert.subject.name} — ${bestCert.level.name}',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 3),
              Text(profile.city ?? 'Non renseignee', style: text.bodySmall),
              const SizedBox(width: 12),
              Text(
                Fmt.experience(profile.yearsExperience),
                style: text.bodySmall,
              ),
              const Spacer(),
              if (profile.badges.isNotEmpty)
                Text(
                  '${profile.badges.length} vérification'
                  '${profile.badges.length > 1 ? "s" : ""}',
                  style: text.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String hint;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    isDense: true,
    hint: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
    decoration: const InputDecoration(
      // Trois menus sur une ligne : le rembourrage se resserre, sinon
      // « Mathematiques » n'a plus la place de s'afficher.
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    ),
    items: [
      DropdownMenuItem<T>(
        value: null,
        child: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
      ),
      for (final (itemValue, label) in items)
        DropdownMenuItem<T>(value: itemValue, child: Text(label)),
    ],
    onChanged: onChanged,
  );
}

/// Filtres avances (§21).
class _AdvancedFilters extends ConsumerWidget {
  const _AdvancedFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(teacherSearchFiltersProvider);
    final notifier = ref.read(teacherSearchFiltersProvider.notifier);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(AppSpacing.xl),
            Text('Filtres avances', style: text.titleLarge),
            const Gap(AppSpacing.xl),

            Text('Vérification', style: text.titleSmall),
            const Gap(AppSpacing.sm),
            _FilterSwitch(
              label: 'Identité vérifiée',
              value: filters.identityVerifiedOnly,
              onChanged: (v) =>
                  notifier.update((f) => f.copyWith(identityVerifiedOnly: v)),
            ),
            _FilterSwitch(
              label: 'Diplôme vérifié',
              value: filters.diplomaVerifiedOnly,
              onChanged: (v) =>
                  notifier.update((f) => f.copyWith(diplomaVerifiedOnly: v)),
            ),
            _FilterSwitch(
              label: 'Compétence certifiée',
              value: filters.certifiedOnly,
              onChanged: (v) =>
                  notifier.update((f) => f.copyWith(certifiedOnly: v)),
            ),

            const Gap(AppSpacing.lg),
            Text(
              'Score minimum au test : ${filters.minScore ?? 0} %',
              style: text.titleSmall,
            ),
            Slider(
              value: (filters.minScore ?? 0).toDouble(),
              max: 100,
              divisions: 20,
              activeColor: AppColors.primary,
              label: '${filters.minScore ?? 0} %',
              onChanged: (value) => notifier.update(
                (f) => value == 0
                    ? f.copyWith(clearMinScore: true)
                    : f.copyWith(minScore: value.round()),
              ),
            ),

            const Gap(AppSpacing.sm),
            Text(
              'Expérience minimale : ${filters.minExperience ?? 0} an(s)',
              style: text.titleSmall,
            ),
            Slider(
              value: (filters.minExperience ?? 0).toDouble(),
              max: 15,
              divisions: 15,
              activeColor: AppColors.primary,
              label: '${filters.minExperience ?? 0} an(s)',
              onChanged: (value) => notifier.update(
                (f) => value == 0
                    ? f.copyWith(clearMinExperience: true)
                    : f.copyWith(minExperience: value.round()),
              ),
            ),

            const Gap(AppSpacing.lg),
            Text('Disponibilité', style: text.titleSmall),
            const Gap(AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: [
                for (final availability in Availability.values)
                  ChoiceChip(
                    label: Text(availability.label),
                    selected: filters.availability == availability,
                    showCheckmark: false,
                    selectedColor: AppColors.primarySurface,
                    onSelected: (selected) => notifier.update(
                      (f) => selected
                          ? f.copyWith(availability: availability)
                          : f.copyWith(clearAvailability: true),
                    ),
                  ),
              ],
            ),

            const Gap(AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      notifier.state = const TeacherSearchFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Reinitialiser'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref.invalidate(teacherSearchProvider);
                      Navigator.pop(context);
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    contentPadding: EdgeInsets.zero,
    dense: true,
    activeThumbColor: AppColors.primary,
  );
}
