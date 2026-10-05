import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/type_ahead.dart';

/// Écran 14 — Matières enseignees (§8).
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  Set<String>? _selection;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;
    final text = Theme.of(context).textTheme;

    // La selection initiale provient du profil, puis reste locale a l'écran.
    _selection ??= profile == null
        ? <String>{}
        : {for (final c in profile.capabilities) c.subject.id};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matières enseignees'),
        leading: const BackButton(),
      ),
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Referentiel indisponible',
          message: '$error',
        ),
        data: (items) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selectionnez les matières que vous etes capable d’enseigner. '
                  'Vous choisirez ensuite les niveaux pour chacune.',
                  style: text.bodyMedium,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  TypeAheadTags(
                    options: [
                      for (final subject in items)
                        PickerOption(value: subject.id, label: subject.name),
                    ],
                    selected: _selection!.toList(),
                    hint: 'Tapez une matière…',
                    emptyMessage: 'Aucune matière ne correspond',
                    onToggle: (id) => setState(() {
                      if (!_selection!.remove(id)) _selection!.add(id);
                    }),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              label: 'Continuer',
              enabled: _selection!.isNotEmpty && !_saving,
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() => _saving = true);
    await ref
        .read(teacherRepositoryProvider)
        .setSubjects(teacherId, _selection!.toList());

    if (!mounted) return;
    setState(() => _saving = false);
    // Les niveaux se choisissent matière par matière (§9).
    context.pushReplacement('/teacher/levels');
  }
}

/// Tuile selectionnable — reprend la maquette « Matières enseignees ».
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected ? AppColors.primary : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 21,
              color: selected ? AppColors.primary : AppColors.borderStrong,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Barre d'action fixee en bas d'écran.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    ),
  );
}
