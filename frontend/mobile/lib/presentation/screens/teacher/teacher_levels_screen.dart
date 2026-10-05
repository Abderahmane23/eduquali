import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'subjects_screen.dart';

/// Écran 15 — Niveaux d'enseignement (§9).
///
/// Une matière peut etre associee a plusieurs niveaux (§8) ; chaque couple
/// ouvre un test de compétence (§10.1).
class TeacherLevelsScreen extends ConsumerStatefulWidget {
  const TeacherLevelsScreen({super.key, this.subjectId});

  /// Matière ciblee ; sans valeur, l'écran passe en revue toutes les matières.
  final String? subjectId;

  @override
  ConsumerState<TeacherLevelsScreen> createState() =>
      _TeacherLevelsScreenState();
}

class _TeacherLevelsScreenState extends ConsumerState<TeacherLevelsScreen> {
  int _index = 0;
  final Map<String, Set<String>> _selection = {};
  bool _initialized = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;
    final levelsAsync = ref.watch(levelsByCategoryProvider);
    final text = Theme.of(context).textTheme;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final capabilities = widget.subjectId == null
        ? profile.capabilities
        : profile.capabilities
              .where((c) => c.subject.id == widget.subjectId)
              .toList();

    if (capabilities.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Niveaux'),
          leading: const BackButton(),
        ),
        body: EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Aucune matière selectionnee',
          message: 'Choisissez d’abord les matières que vous enseignez.',
          actionLabel: 'Ajouter mes matières',
          onAction: () => context.pushReplacement('/teacher/subjects'),
        ),
      );
    }

    // Selection initiale issue du profil.
    if (!_initialized) {
      for (final capability in capabilities) {
        _selection[capability.subject.id] = {
          for (final level in capability.levels) level.id,
        };
      }
      _initialized = true;
    }

    final current = capabilities[_index.clamp(0, capabilities.length - 1)];
    final selected = _selection[current.subject.id] ?? <String>{};
    final isLast = _index >= capabilities.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Niveaux enseignes'),
        leading: const BackButton(),
      ),
      body: levelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Referentiel indisponible',
          message: '$error',
        ),
        data: (grouped) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.subject.name,
                          style: text.headlineSmall,
                        ),
                      ),
                      if (capabilities.length > 1)
                        Text(
                          '${_index + 1} / ${capabilities.length}',
                          style: text.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A quels niveaux enseignez-vous cette matière ?',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final entry in _orderedCategories(grouped)) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.md,
                      ),
                      child: Text(
                        CatalogRepository.categoryLabels[entry.key] ??
                            entry.key,
                        style: text.labelSmall,
                      ),
                    ),
                    for (final level in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SelectableTile(
                          label: level.name,
                          subtitle: current.isCertified(level.id)
                              ? 'Certifié ${current.certifiedScores[level.id]} %'
                              : null,
                          selected: selected.contains(level.id),
                          onTap: () => setState(() {
                            final set = _selection.putIfAbsent(
                              current.subject.id,
                              () => <String>{},
                            );
                            if (set.contains(level.id)) {
                              set.remove(level.id);
                            } else {
                              set.add(level.id);
                            }
                          }),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            BottomActionBar(
              label: isLast ? 'Enregistrer' : 'Matière suivante',
              enabled: !_saving,
              busy: _saving,
              onPressed: () => _next(capabilities, isLast),
            ),
          ],
        ),
      ),
    );
  }

  /// Primaire, puis scolaire, puis universitaire (§9).
  List<MapEntry<String, List<RefItem>>> _orderedCategories(
    Map<String, List<RefItem>> grouped,
  ) {
    const order = ['PRIMARY', 'SECONDARY', 'UNIVERSITY'];
    final entries = grouped.entries.toList()
      ..sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
    return entries;
  }

  Future<void> _next(List<TeachingCapability> capabilities, bool isLast) async {
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    final current = capabilities[_index];
    setState(() => _saving = true);

    await ref
        .read(teacherRepositoryProvider)
        .setLevelsForSubject(
          teacherId,
          current.subject.id,
          (_selection[current.subject.id] ?? {}).toList(),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (isLast) {
      // Les tests correspondants deviennent disponibles (§10.1).
      context.pushReplacement('/teacher/tests');
    } else {
      setState(() => _index++);
    }
  }
}
