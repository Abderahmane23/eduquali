import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/tutoring_repository.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common.dart';

/// Quand le professeur peut donner des cours à domicile.
///
/// Au moins trois jours par semaine : en dessous, une famille ne peut pas
/// installer un rythme régulier, et l'offre promet ce qu'elle ne tient pas.
/// Tant que ce n'est pas renseigné, aucune offre ne se publie.
class TutoringAvailabilityScreen extends ConsumerStatefulWidget {
  const TutoringAvailabilityScreen({super.key});

  @override
  ConsumerState<TutoringAvailabilityScreen> createState() =>
      _AvailabilityState();
}

class _AvailabilityState extends ConsumerState<TutoringAvailabilityScreen> {
  final Set<Weekday> _days = {};
  final Set<DaySlot> _slots = {};
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final teacherId = ref.watch(currentTeacherIdProvider);
    final saved = ref.watch(tutoringAvailabilityProvider).valueOrNull;

    // Première ouverture : on repart de ce qui est déjà enregistré.
    if (!_loaded && saved != null) {
      _days.addAll(saved.days);
      _slots.addAll(saved.slots);
      _loaded = true;
    }

    final problem = tutoringAvailabilityProblem(days: _days, slots: _slots);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes disponibilités')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Quand pouvez-vous donner des cours ?',
              style: text.titleMedium,
            ),
            const Gap(AppSpacing.xs),
            Text(
              'Les familles voient ces créneaux avant de réserver. '
              'Au moins $minTutoringDays jours par semaine.',
              style: text.bodyMedium,
            ),

            const Gap(AppSpacing.xl),
            Text('Jours', style: text.titleSmall),
            const Gap(AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final day in Weekday.values)
                  FilterChip(
                    label: Text(day.label),
                    selected: _days.contains(day),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                      _error = null;
                    }),
                  ),
              ],
            ),

            const Gap(AppSpacing.xl),
            Text('Moments de la journée', style: text.titleSmall),
            const Gap(AppSpacing.sm),
            for (final slot in DaySlot.values)
              CheckboxListTile(
                value: _slots.contains(slot),
                onChanged: (on) => setState(() {
                  if (on ?? false) {
                    _slots.add(slot);
                  } else {
                    _slots.remove(slot);
                  }
                  _error = null;
                }),
                title: Text(slot.label),
                subtitle: Text(slot.hours),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

            if (_error != null) ...[
              const Gap(AppSpacing.md),
              InfoBanner(
                message: _error!,
                tone: StatusTone.danger,
                icon: Icons.error_outline,
              ),
            ] else if (problem != null) ...[
              const Gap(AppSpacing.md),
              InfoBanner(
                message: problem,
                tone: StatusTone.info,
                icon: Icons.info_outline,
              ),
            ],

            const Gap(AppSpacing.xl),
            FilledButton(
              onPressed: _busy || problem != null || teacherId == null
                  ? null
                  : () => _save(teacherId),
              child: Text(_busy ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String teacherId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(tutoringRepositoryProvider)
          .saveAvailability(teacherId: teacherId, days: _days, slots: _slots);
      refreshTutoring(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disponibilités enregistrées.')),
      );
      context.pop();
    } on TutoringException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
