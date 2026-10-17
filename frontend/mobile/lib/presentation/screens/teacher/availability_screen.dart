import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'subjects_screen.dart';

/// Écran 17 — Disponibilité et preferences (§15).
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  Availability? _availability;
  Set<InstitutionType>? _types;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;
    final text = Theme.of(context).textTheme;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _availability ??= profile.availability;
    _types ??= profile.preferredInstitutionTypes.toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilité'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Votre disponibilité influence directement votre position '
                  'dans les résultats de recherche des établissements.',
                  style: text.bodyMedium,
                ),
                const Gap(AppSpacing.xl),

                Text('Je suis actuellement', style: text.titleMedium),
                const Gap(AppSpacing.md),
                for (final option in Availability.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SelectableTile(
                      label: option.label,
                      subtitle: switch (option) {
                        Availability.available =>
                          'Vous pouvez prendre un poste immediatement',
                        Availability.availableSoon =>
                          'Vous serez disponible prochainement',
                        Availability.unavailable =>
                          'Vous ne souhaitez pas etre contacte pour le moment',
                      },
                      selected: _availability == option,
                      onTap: () => setState(() => _availability = option),
                    ),
                  ),

                const Gap(AppSpacing.xl),

                // Types d'établissements souhaites (§15).
                Text('Types d’établissements', style: text.titleMedium),
                const SizedBox(height: 4),
                Text('Ou souhaitez-vous enseigner ?', style: text.bodySmall),
                const Gap(AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in InstitutionType.values)
                      FilterChip(
                        label: Text(type.label),
                        selected: _types!.contains(type),
                        showCheckmark: false,
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _types!.add(type);
                          } else {
                            _types!.remove(type);
                          }
                        }),
                        selectedColor: AppColors.primarySurface,
                        side: BorderSide(
                          color: _types!.contains(type)
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _types!.contains(type)
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          BottomActionBar(
            label: 'Enregistrer mes disponibilités',
            enabled: _availability != null && !_saving,
            busy: _saving,
            onPressed: () => _save(profile.teacherId),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String teacherId) async {
    setState(() => _saving = true);
    final repository = ref.read(teacherRepositoryProvider);

    await repository.setAvailability(teacherId, _availability!);
    await repository.setPreferredInstitutionTypes(teacherId, _types!.toList());

    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }
}
