import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Écran 16 — Expérience professionnelle (§15).
class ExperienceScreen extends ConsumerWidget {
  const ExperienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentTeacherProfileProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expérience professionnelle'),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          if (profile.experiences.isEmpty) {
            return EmptyState(
              icon: Icons.work_history_outlined,
              title: 'Aucune experience',
              message:
                  'Renseignez vos postes precedents : ils construisent votre '
                  'reputation professionnelle.',
              actionLabel: 'Ajouter une experience',
              onAction: () => _openForm(context, ref),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              AppCard(
                color: AppColors.surfaceMuted,
                borderColor: AppColors.surfaceMuted,
                child: Row(
                  children: [
                    const Icon(
                      Icons.timeline_outlined,
                      size: 19,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Total : ${Fmt.experience(profile.yearsExperience)}',
                        style: text.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),

              for (final experience in profile.experiences)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ExperienceCard(
                    experience: experience,
                    onDelete: () async {
                      await ref
                          .read(teacherRepositoryProvider)
                          .deleteExperience(profile.teacherId, experience.id);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ExperienceForm(),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.experience, required this.onDelete});

  final ExperienceItem experience;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(experience.position, style: text.titleMedium),
                    const SizedBox(height: 3),
                    Text(experience.institutionName, style: text.bodyMedium),
                  ],
                ),
              ),
              if (experience.verificationStatus.isVerified)
                const TagChip(
                  label: 'Vérifiée',
                  icon: Icons.verified,
                  tone: StatusTone.success,
                ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.date_range_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                Fmt.period(experience.startDate, experience.endDate),
                style: text.bodySmall,
              ),
              if (experience.city != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 3),
                Text(experience.city!, style: text.bodySmall),
              ],
            ],
          ),

          if (experience.description != null) ...[
            const SizedBox(height: 10),
            Text(experience.description!, style: text.bodySmall),
          ],

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulaire d'ajout d'une experience.
class _ExperienceForm extends ConsumerStatefulWidget {
  const _ExperienceForm();

  @override
  ConsumerState<_ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends ConsumerState<_ExperienceForm> {
  final _formKey = GlobalKey<FormState>();
  final _institution = TextEditingController();
  final _position = TextEditingController();
  final _startYear = TextEditingController();
  final _endYear = TextEditingController();
  final _description = TextEditingController();
  final _contactPhone = TextEditingController();
  final _contactEmail = TextEditingController();

  String? _city;
  bool _current = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _institution,
      _position,
      _startYear,
      _endYear,
      _description,
      _contactPhone,
      _contactEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(citiesProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
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
                Text(
                  'Ajouter une experience',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Gap(AppSpacing.xl),

                TextFormField(
                  controller: _position,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Poste occupe',
                    hintText: 'Professeur de Mathématiques',
                  ),
                  validator: (v) => Validators.required(v, 'Le poste'),
                ),
                const Gap(AppSpacing.lg),

                TextFormField(
                  controller: _institution,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Établissement'),
                  validator: (v) => Validators.required(v, 'L’établissement'),
                ),
                const Gap(AppSpacing.lg),

                DropdownButtonFormField<String>(
                  initialValue: _city,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ville'),
                  items: [
                    for (final city in cities)
                      DropdownMenuItem(value: city, child: Text(city)),
                  ],
                  onChanged: (value) => setState(() => _city = value),
                ),
                const Gap(AppSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startYear,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Année de début',
                        ),
                        validator: Validators.year,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _endYear,
                        keyboardType: TextInputType.number,
                        enabled: !_current,
                        decoration: InputDecoration(
                          labelText: 'Année de fin',
                          hintText: _current ? 'En cours' : null,
                        ),
                        validator: (value) =>
                            _current ? null : Validators.year(value),
                      ),
                    ),
                  ],
                ),

                SwitchListTile(
                  value: _current,
                  onChanged: (value) => setState(() => _current = value),
                  title: const Text('Poste actuel'),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                ),
                const Gap(AppSpacing.sm),

                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (facultatif)',
                    alignLabelWithHint: true,
                  ),
                ),

                // --- Qui peut confirmer -----------------------------------
                //
                // Un justificatif se falsifie ; un appel a l'etablissement,
                // non. C'est ce contact qui fait passer l'experience de
                // « declaree » a « verifiee », et c'est la verification qui
                // porte le badge qu'une ecole regarde en premier.
                const Gap(AppSpacing.xl),
                const FieldLabel('Qui peut confirmer ce poste ?'),
                const Text(
                  'Le numero ou le courriel de l’etablissement. Nous le '
                  'contactons pour verifier, et votre fiche porte alors le '
                  'badge correspondant.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Gap(AppSpacing.md),
                TextFormField(
                  controller: _contactPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telephone de l’etablissement (facultatif)',
                    prefixIcon: Icon(Icons.call_outlined, size: 20),
                  ),
                  // Facultatif : un professeur qui ne l'a pas sous la main
                  // doit pouvoir enregistrer et completer plus tard. Mais mal
                  // saisi, il ne sert a rien — d'ou le controle de forme des
                  // qu'il y a quelque chose.
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? null : Validators.phone(v),
                ),
                const Gap(AppSpacing.md),
                TextFormField(
                  controller: _contactEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Courriel de l’etablissement (facultatif)',
                    prefixIcon: Icon(Icons.mail_outline, size: 20),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? null : Validators.email(v),
                ),

                const Gap(AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ajouter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() => _saving = true);
    // Une experience court de septembre a juillet — année scolaire.
    await ref
        .read(teacherRepositoryProvider)
        .addExperience(
          teacherId: teacherId,
          institutionName: _institution.text.trim(),
          position: _position.text.trim(),
          startDate: DateTime(int.parse(_startYear.text.trim()), 9),
          endDate: _current
              ? null
              : DateTime(int.parse(_endYear.text.trim()), 7),
          city: _city,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          contactPhone: _contactPhone.text.trim().isEmpty
              ? null
              : _contactPhone.text.trim(),
          contactEmail: _contactEmail.text.trim().isEmpty
              ? null
              : _contactEmail.text.trim(),
        );

    if (!mounted) return;
    Navigator.pop(context);
  }
}
