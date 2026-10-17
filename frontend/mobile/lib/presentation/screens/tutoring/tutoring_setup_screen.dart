import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/tutoring_repository.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/type_ahead.dart';

/// Mettre en place ses cours à domicile, une question à la fois.
///
/// Un seul écran portant jours, créneaux, matière, classes, tarif et zone
/// décourage : le professeur voyait six blocs et fermait. Quatre étapes
/// courtes, chacune avec sa raison d'être expliquée, se terminent.
///
/// L'ordre n'est pas décoratif : les disponibilités passent en premier parce
/// qu'aucune offre ne peut être publiée sans elles.
class TutoringSetupScreen extends ConsumerStatefulWidget {
  const TutoringSetupScreen({super.key});

  @override
  ConsumerState<TutoringSetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<TutoringSetupScreen> {
  static const _lastStep = 3;

  int _step = 0;
  bool _busy = false;
  String? _error;

  // Étape 1 et 2 — quand.
  final Set<Weekday> _days = {};
  final Set<DaySlot> _slots = {};
  bool _loaded = false;

  // Étape 3 — quoi.
  String? _subjectId;
  final Set<String> _levelIds = {};

  // Étape 4 — dans quelles conditions.
  final _rate = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();
  TutoringMode _mode = TutoringMode.atStudent;

  @override
  void dispose() {
    _rate.dispose();
    _city.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Ce qui manque à l'étape courante, dit en une phrase. `null` = on avance.
  String? get _blocking => switch (_step) {
    0 =>
      _days.length >= minTutoringDays
          ? null
          : 'Choisissez au moins $minTutoringDays jours.',
    1 => _slots.isEmpty ? 'Choisissez au moins un moment de la journée.' : null,
    2 =>
      _subjectId == null
          ? 'Choisissez la matière que vous enseignez.'
          : _levelIds.isEmpty
          ? 'Choisissez au moins une classe.'
          : null,
    _ =>
      (int.tryParse(_rate.text.trim()) ?? 0) <= 0
          ? 'Indiquez votre tarif horaire.'
          : _city.text.trim().isEmpty
          ? 'Indiquez votre ville.'
          : null,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final saved = ref.watch(tutoringAvailabilityProvider).valueOrNull;
    final parent = ref.watch(parentRecordProvider).valueOrNull;

    // Première ouverture : on repart de ce qui est déjà enregistré.
    if (!_loaded && saved != null) {
      _days.addAll(saved.days);
      _slots.addAll(saved.slots);
      _loaded = true;
    }
    if (_city.text.isEmpty && parent?.city != null) {
      _city.text = parent!.city!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cours à domicile'),
        leading: BackButton(
          onPressed: _step == 0
              ? () => context.pop()
              : () => setState(() => _step--),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step + 1) / (_lastStep + 1),
            minHeight: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Text(
                    'Étape ${_step + 1} sur ${_lastStep + 1}',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(_titles[_step], style: text.headlineSmall),
                  const Gap(AppSpacing.xs),
                  Text(_reasons[_step], style: text.bodyMedium),
                  const Gap(AppSpacing.xl),
                  _content(),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  if (_blocking != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        _blocking!,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || _blocking != null ? null : _next,
                      child: Text(
                        _busy
                            ? 'Enregistrement…'
                            : _step == _lastStep
                            ? 'Publier mon offre'
                            : 'Continuer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _titles = [
    'Quels jours pouvez-vous venir ?',
    'À quels moments ?',
    'Qu’enseignez-vous ?',
    'Vos conditions',
  ];

  static const _reasons = [
    'Une famille installe un rythme : au moins trois jours par semaine, '
        'sinon l’élève ne progresse pas et vous perdez la place.',
    'Les familles filtrent par créneau. Celui que vous cochez est celui '
        'qu’on vous proposera.',
    'Seules ces classes verront votre offre. Mieux vaut trois classes que '
        'vous maîtrisez que dix approximatives.',
    'Le tarif et la zone s’affichent avant qu’on vous contacte : personne '
        'ne vous écrira pour négocier ce qui est déjà écrit.',
  ];

  Widget _content() => switch (_step) {
    0 => Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final day in Weekday.values)
          FilterChip(
            label: Text(day.label),
            selected: _days.contains(day),
            onSelected: (on) => setState(() {
              on ? _days.add(day) : _days.remove(day);
              _error = null;
            }),
          ),
      ],
    ),
    1 => Column(
      children: [
        for (final slot in DaySlot.values)
          CheckboxListTile(
            value: _slots.contains(slot),
            onChanged: (on) => setState(() {
              (on ?? false) ? _slots.add(slot) : _slots.remove(slot);
              _error = null;
            }),
            title: Text(slot.label),
            subtitle: Text(slot.hours),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    ),
    2 => _SubjectAndLevels(
      subjectId: _subjectId,
      levelIds: _levelIds,
      onSubject: (id) => setState(() {
        // Reappuyer sur l'étiquette la retire : c'est le seul geste qui
        // permette de revenir en arriere une fois la matière choisie.
        _subjectId = _subjectId == id ? null : id;
        // Les classes avaient été choisies pour la matière precedente ;
        // les garder enverrait en base des niveaux que l'écran n'affiche
        // plus, puisque la liste suit le cycle de la matière.
        _levelIds.clear();
        _error = null;
      }),
      onLevel: (id, on) => setState(() {
        on ? _levelIds.add(id) : _levelIds.remove(id);
        _error = null;
      }),
    ),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _rate,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Tarif horaire',
            suffixText: 'GNF',
          ),
        ),
        const Gap(AppSpacing.md),
        TextField(
          controller: _city,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Ville'),
        ),
        const Gap(AppSpacing.lg),
        Text(
          'Où se passe le cours ?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Gap(AppSpacing.sm),
        for (final mode in TutoringMode.values)
          RadioGroup<TutoringMode>(
            groupValue: _mode,
            onChanged: (m) => setState(() => _mode = m ?? _mode),
            child: RadioListTile<TutoringMode>(
              value: mode,
              title: Text(mode.label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const Gap(AppSpacing.md),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ce que les familles doivent savoir (facultatif)',
            hintText: 'Méthode, matériel à prévoir, quartiers desservis…',
          ),
        ),
      ],
    ),
  };

  Future<void> _next() async {
    if (_step < _lastStep) {
      setState(() => _step++);
      return;
    }

    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(tutoringRepositoryProvider);
      // Les disponibilités d'abord : `publishOffer` les exige, et refuserait
      // l'offre juste après avoir fait remplir quatre écrans.
      await repo.saveAvailability(
        teacherId: teacherId,
        days: _days,
        slots: _slots,
      );
      await repo.publishOffer(
        teacherId: teacherId,
        subjectId: _subjectId!,
        levelIds: _levelIds.toList(),
        mode: _mode,
        hourlyRate: int.parse(_rate.text.trim()),
        city: _city.text.trim(),
        description: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      refreshTutoring(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre offre est en ligne.')),
      );
      context.pop();
    } on TutoringException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Matière puis classes, les classes suivant le cycle de la matière.
class _SubjectAndLevels extends ConsumerWidget {
  const _SubjectAndLevels({
    required this.subjectId,
    required this.levelIds,
    required this.onSubject,
    required this.onLevel,
  });

  final String? subjectId;
  final Set<String> levelIds;
  final ValueChanged<String> onSubject;
  final void Function(String id, bool selected) onLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];

    // Les classes suivent la matière : proposer la Terminale à un
    // professeur de lecture n'aurait pas de sens.
    final cycles = subjects
        .where((s) => s.id == subjectId)
        .expand((s) => s.cycles)
        .toSet();
    final shown = cycles.isEmpty
        ? levels
        : [
            for (final level in levels)
              if (level.cycles.any(cycles.contains)) level,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Matière', style: text.titleSmall),
        const Gap(AppSpacing.sm),
        TypeAheadTags(
          options: [
            for (final subject in subjects)
              PickerOption(value: subject.id, label: subject.name),
          ],
          // Une seule matière par offre : l'étiquette retenue remplace la
          // précédente au lieu de s'ajouter à elle.
          selected: subjectId == null ? const [] : [subjectId!],
          hint: 'Tapez une matière…',
          emptyMessage: 'Aucune matière ne correspond',
          onToggle: onSubject,
        ),
        if (subjectId != null) ...[
          const Gap(AppSpacing.lg),
          Text('Classes', style: text.titleSmall),
          const Gap(AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final level in shown)
                FilterChip(
                  label: Text(level.name),
                  selected: levelIds.contains(level.id),
                  onSelected: (on) => onLevel(level.id, on),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
