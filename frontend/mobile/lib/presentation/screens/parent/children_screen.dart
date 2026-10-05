import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/children_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/type_ahead.dart';

/// Les enfants du parent : en ajouter, corriger, retirer.
///
/// L'inscription promet « vous pourrez en ajouter d'autres depuis votre
/// profil » — c'est ici que cette promesse se tient.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentChildrenProvider);
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final filieres = ref.watch(filieresProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    String levelName(String? id) =>
        levels.where((l) => l.id == id).map((l) => l.name).firstOrNull ?? '';

    String filiereName(String? id) =>
        filieres.where((f) => f.id == id).map((f) => f.name).firstOrNull ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mes enfants')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Ajouter un enfant'),
      ),
      body: children.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Impossible d’afficher vos enfants',
          message: 'Réessayez dans un instant.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.child_care_outlined,
              title: 'Aucun enfant enregistré',
              message:
                  'Ajoutez votre enfant pour réserver un professeur '
                  'à son niveau.',
              actionLabel: 'Ajouter un enfant',
              onAction: () => _edit(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.md),
            itemBuilder: (_, index) {
              final child = items[index];
              final subjectNames = [
                for (final id in ChildrenRepository.split(child.subjectIds))
                  ...subjects.where((s) => s.id == id).map((s) => s.name),
              ];

              return AppCard(
                onTap: () => _edit(context, ref, child: child),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              child.firstName,
                              child.lastName ?? '',
                            ].where((p) => p.isNotEmpty).join(' '),
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              levelName(child.levelId),
                              filiereName(child.filiereId),
                              child.schoolName ?? '',
                            ].where((p) => p.isNotEmpty).join(' · '),
                            style: text.bodySmall,
                          ),
                          if (subjectNames.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Aide en ${subjectNames.join(", ")}',
                              style: text.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _remove(context, ref, child),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Retirer',
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    ChildRow? child,
  }) async {
    final parentId = ref.read(currentSessionProvider)?.parentId;
    if (parentId == null) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChildSheet(parentId: parentId, child: child),
    );
    if (saved ?? false) ref.invalidate(parentChildrenProvider);
  }

  /// Retire un enfant, avec cinq secondes pour se raviser.
  ///
  /// La fiche part d'abord : la boîte « Êtes-vous sûr ? » demandait avant
  /// qu'on voie ce qui disparaît, et la demandait à chaque fois. L'identifiant
  /// est conservé tel quel, donc les demandes passées le retrouvent.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ChildRow child,
  ) async {
    final repo = ref.read(childrenRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final ChildRow removed;
    try {
      removed = await repo.remove(child.id);
    } on ChildException catch (error) {
      // Le refus vient du dépôt : des demandes en cours désignent l'enfant.
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    ref.invalidate(parentChildrenProvider);
    if (!context.mounted) return;

    showUndo(
      context,
      // « Fiche de X retirée » et non « X retiré(e) » : deviner le genre
      // d'apres la derniere lettre se trompe ici, ou Alpha, Ibrahima et
      // Ousmane sont des prenoms masculins en « a ».
      message: 'Fiche de ${child.firstName} retirée.',
      onUndo: () async {
        await repo.restore(removed);
        ref.invalidate(parentChildrenProvider);
      },
    );
  }
}

/// Formulaire d'un enfant : les champs demandés le 19/09.
class _ChildSheet extends ConsumerStatefulWidget {
  const _ChildSheet({required this.parentId, this.child});

  final String parentId;
  final ChildRow? child;

  @override
  ConsumerState<_ChildSheet> createState() => _ChildSheetState();
}

class _ChildSheetState extends ConsumerState<_ChildSheet> {
  late final _firstName = TextEditingController(
    text: widget.child?.firstName ?? '',
  );
  late final _lastName = TextEditingController(
    text: widget.child?.lastName ?? '',
  );
  late final _school = TextEditingController(
    text: widget.child?.schoolName ?? '',
  );
  late String? _levelId = widget.child?.levelId;
  late String? _filiereId = widget.child?.filiereId;
  late final Set<String> _subjectIds = {
    ...ChildrenRepository.split(widget.child?.subjectIds ?? ''),
  };
  bool _busy = false;
  String? _error;

  /// Les profils ouverts à cette classe. Vide avant la 12ème année.
  List<FiliereRow> _filieresFor(String? levelId) {
    if (levelId == null) return const [];
    final all = ref.read(filieresProvider).valueOrNull ?? const [];
    return [
      for (final filiere in all)
        if (filiere.levelIds.split(',').contains(levelId)) filiere,
    ];
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _school.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final filieres = _filieresFor(_levelId);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.child == null ? 'Nouvel enfant' : 'Modifier la fiche',
                style: text.titleLarge,
              ),

              const Gap(AppSpacing.lg),
              TextField(
                controller: _firstName,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const Gap(AppSpacing.md),
              TextField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),

              const Gap(AppSpacing.lg),
              Text('Classe', style: text.titleSmall),
              const Gap(AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final level in levels)
                    ChoiceChip(
                      label: Text(level.name),
                      selected: _levelId == level.id,
                      onSelected: (_) => setState(() {
                        _levelId = level.id;
                        // La 11ème année est commune aux trois profils :
                        // repasser en 11ème doit effacer le profil, sinon
                        // c'est lui qui partirait en base sans être
                        // affiché.
                        final ouverts = _filieresFor(level.id).map((f) => f.id);
                        if (!ouverts.contains(_filiereId)) _filiereId = null;
                      }),
                    ),
                ],
              ),

              if (_filieresFor(_levelId).isNotEmpty) ...[
                const Gap(AppSpacing.lg),
                Text('Profil', style: text.titleSmall),
                const Gap(AppSpacing.xs),
                Text(
                  'À partir de la 12ème année, le lycée se partage en trois '
                  'profils.',
                  style: text.bodySmall,
                ),
                const Gap(AppSpacing.sm),
                RadioGroup<String>(
                  groupValue: _filiereId,
                  onChanged: (id) => setState(() => _filiereId = id),
                  child: Column(
                    children: [
                      for (final filiere in filieres)
                        RadioListTile<String>(
                          value: filiere.id,
                          title: Text(filiere.name),
                          subtitle: filiere.note.isEmpty
                              ? null
                              : Text(filiere.note),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ],

              const Gap(AppSpacing.lg),
              TextField(
                controller: _school,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Établissement fréquenté',
                ),
              ),

              const Gap(AppSpacing.lg),
              Text('Matières à soutenir', style: text.titleSmall),
              const Gap(AppSpacing.sm),
              TypeAheadTags(
                options: [
                  for (final subject in subjects)
                    PickerOption(value: subject.id, label: subject.name),
                ],
                selected: _subjectIds.toList(),
                hint: 'Tapez une matière…',
                emptyMessage: 'Aucune matière ne correspond',
                onToggle: (id) => setState(
                  () => _subjectIds.contains(id)
                      ? _subjectIds.remove(id)
                      : _subjectIds.add(id),
                ),
              ),

              if (_error != null) ...[
                const Gap(AppSpacing.md),
                InfoBanner(
                  message: _error!,
                  tone: StatusTone.danger,
                  icon: Icons.error_outline,
                ),
              ],

              const Gap(AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Enregistrement…' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(childrenRepositoryProvider);
    try {
      if (widget.child == null) {
        await repo.add(
          parentId: widget.parentId,
          firstName: _firstName.text,
          lastName: _lastName.text,
          levelId: _levelId,
          filiereId: _filiereId,
          schoolName: _school.text,
          subjectIds: _subjectIds.toList(),
        );
      } else {
        await repo.update(
          childId: widget.child!.id,
          firstName: _firstName.text,
          lastName: _lastName.text,
          levelId: _levelId,
          filiereId: _filiereId,
          schoolName: _school.text,
          subjectIds: _subjectIds.toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ChildException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
