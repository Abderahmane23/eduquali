import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/course_models.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Ce qu'on demande au professeur avant de proposer un plan.
///
/// Renvoie un [CourseBrief] ; c'est l'assistant qui enchaîne sur le plan.
/// Rien n'est débité ici : le plan est gratuit.
class CourseFormScreen extends ConsumerStatefulWidget {
  const CourseFormScreen({super.key});

  @override
  ConsumerState<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends ConsumerState<CourseFormScreen> {
  final _title = TextEditingController();
  final _objectives = TextEditingController();
  final _exercises = TextEditingController(text: '15');
  final _chapters = TextEditingController(text: '4');

  final Set<String> _levelIds = {};
  CoursePeriod _period = CoursePeriod.trimester1;
  bool _withExercises = true;
  bool _withDefinitions = true;
  bool _withChapters = true;
  bool _withDates = false;
  DateTime? _start;
  DateTime? _end;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _objectives.dispose();
    _exercises.dispose();
    _chapters.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau cours')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Label('Titre du cours', text),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Les fonctions affines',
              ),
            ),

            _Label('Pour quelles classes ?', text),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final l in levels)
                  FilterChip(
                    label: Text(l.name),
                    selected: _levelIds.contains(l.id),
                    onSelected: (on) => setState(
                      () => on ? _levelIds.add(l.id) : _levelIds.remove(l.id),
                    ),
                  ),
              ],
            ),

            _Label('Sur quelle période ?', text),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final p in CoursePeriod.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _period == p,
                    onSelected: (_) => setState(() => _period = p),
                  ),
              ],
            ),

            _Label('Ce que les élèves doivent apprendre', text),
            Text(
              'Une notion par ligne : chaque ligne devient un chapitre.',
              style: text.bodySmall,
            ),
            const Gap(AppSpacing.sm),
            TextField(
              controller: _objectives,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Définition et vocabulaire\n'
                    'Représentation graphique\n'
                    'Sens de variation\n'
                    'Problèmes concrets',
              ),
            ),

            const Gap(AppSpacing.xl),
            _Toggle(
              label: 'Des exercices',
              value: _withExercises,
              onChanged: (v) => setState(() => _withExercises = v),
              field: _exercises,
              unit: 'exercices',
            ),
            _Toggle(
              label: 'Des définitions',
              value: _withDefinitions,
              onChanged: (v) => setState(() => _withDefinitions = v),
            ),
            _Toggle(
              label: 'Des chapitres',
              value: _withChapters,
              onChanged: (v) => setState(() => _withChapters = v),
              field: _chapters,
              unit: 'chapitres',
            ),
            _Toggle(
              label: 'Couvrir des dates précises',
              value: _withDates,
              onChanged: (v) => setState(() => _withDates = v),
            ),

            if (_withDates) ...[
              const Gap(AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(isStart: true),
                      child: Text(
                        _start == null ? 'Début' : Fmt.dateShort(_start!),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(isStart: false),
                      child: Text(_end == null ? 'Fin' : Fmt.dateShort(_end!)),
                    ),
                  ),
                ],
              ),
            ],

            if (_error != null) ...[
              const Gap(AppSpacing.lg),
              InfoBanner(
                message: _error!,
                tone: StatusTone.danger,
                icon: Icons.error_outline,
              ),
            ],
          ],
        ),
      ),
      // Ce que fait le bouton reste écrit au-dessus de lui : le plan vient
      // avant le cours, et c'est là qu'on corrige le découpage.
      bottomNavigationBar: StickyActionBar(
        label: 'Voir le plan',
        note:
            'Le plan s’affiche avant le cours : vous corrigez le découpage '
            'avant qu’il soit écrit.',
        onPressed: _submit,
      ),
    );
  }

  Future<void> _pick({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  void _submit() {
    final levels = ref.read(levelsProvider).valueOrNull ?? const [];
    final names = [
      for (final l in levels)
        if (_levelIds.contains(l.id)) l.name,
    ];

    final missing = [
      if (_title.text.trim().isEmpty) 'le titre',
      if (names.isEmpty) 'au moins une classe',
      if (_objectives.text.trim().length < 10) 'ce que les élèves apprennent',
      if (_withDates && (_start == null || _end == null)) 'les deux dates',
    ];
    if (missing.isNotEmpty) {
      setState(() => _error = 'Il manque ${missing.join(', ')}.');
      return;
    }
    if (_withDates && _end!.isBefore(_start!)) {
      setState(() => _error = 'La fin doit venir après le début.');
      return;
    }

    Navigator.pop(
      context,
      CourseBrief(
        title: _title.text.trim(),
        levelNames: names,
        period: _period,
        objectives: _objectives.text.trim(),
        exerciseCount: _withExercises
            ? (int.tryParse(_exercises.text) ?? 10).clamp(1, 60)
            : 0,
        withDefinitions: _withDefinitions,
        chapterCount: _withChapters
            ? (int.tryParse(_chapters.text) ?? 4).clamp(1, 12)
            : 1,
        startDate: _withDates ? _start : null,
        endDate: _withDates ? _end : null,
      ),
    );
  }
}

/// « Des exercices [oui/non] [15] »
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.field,
    this.unit,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final TextEditingController? field;
  final String? unit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        if (value && field != null) ...[
          SizedBox(
            width: 64,
            child: TextField(
              controller: field,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.text);

  final String label;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
    child: Text(label, style: text.titleSmall),
  );
}
