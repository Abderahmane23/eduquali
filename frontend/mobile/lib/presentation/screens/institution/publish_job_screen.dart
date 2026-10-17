import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Ecrans 10 et 11 établissement — Publier une offre, publique ou privee
/// (§29).
class PublishJobScreen extends ConsumerStatefulWidget {
  const PublishJobScreen({super.key});

  @override
  ConsumerState<PublishJobScreen> createState() => _PublishJobScreenState();
}

class _PublishJobScreenState extends ConsumerState<PublishJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();

  String? _subjectId;
  final Set<String> _levelIds = {};
  String? _city;
  ContractType _contractType = ContractType.permanent;
  JobVisibility _visibility = JobVisibility.public;
  bool _salaryPublished = true;
  bool _requiresCertification = false;
  int _minExperience = 0;
  DateTime? _startDate;
  final Set<String> _invited = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_title, _description, _salaryMin, _salaryMax]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];
    final cities = ref.watch(citiesProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    /*
     * Ce que l'établissement a déjà dit de lui-même.
     *
     * Sa ville est obligatoire et connue depuis son inscription, et les
     * matières qu'il cherche aussi (migration 0026). Le formulaire redemandait
     * les deux à chaque offre, la ville dans une liste déroulante partant de
     * rien.
     *
     * Dérivé plutôt qu'écrit dans l'état : la fiche arrive du dépôt, donc
     * après le premier rendu, et appeler `setState` depuis `build` lève. Un
     * choix de l'utilisateur gagne toujours, puisqu'il est lu en premier.
     *
     * La ville est préremplie sans réserve — un établissement en a une seule.
     * La matière ne l'est que s'il n'en cherche qu'une : en proposer une parmi
     * cinq serait un choix fait à sa place, et c'est le genre de valeur qu'on
     * valide sans la relire.
     */
    final defauts = _defaults(ref.watch(institutionRecordProvider).valueOrNull);
    final ville = _city ?? defauts.ville;
    final matiere = _subjectId ?? defauts.matiere;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publier une offre'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visibilité : publique ou privee (§29).
                    Text('Visibilité de l’offre', style: text.titleMedium),
                    const Gap(AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _VisibilityOption(
                            label: 'Publique',
                            description: 'Visible par tous les enseignants',
                            icon: Icons.public,
                            selected: _visibility == JobVisibility.public,
                            onTap: () => setState(
                              () => _visibility = JobVisibility.public,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _VisibilityOption(
                            label: 'Privee',
                            description: 'Reservee aux profils invites',
                            icon: Icons.lock_outline,
                            selected: _visibility == JobVisibility.private,
                            onTap: () => setState(
                              () => _visibility = JobVisibility.private,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_visibility == JobVisibility.private) ...[
                      const Gap(AppSpacing.md),
                      const InfoBanner(
                        message:
                            'L’offre privee n’apparait pas publiquement. Le '
                            'recrutement reste gere sur EduQuali : '
                            'invitation, candidature, entretien, offre, '
                            'contrat.',
                        tone: StatusTone.info,
                      ),
                      const Gap(AppSpacing.md),
                      _InvitePicker(
                        selected: _invited,
                        onChanged: (ids) => setState(
                          () => _invited
                            ..clear()
                            ..addAll(ids),
                        ),
                      ),
                    ],

                    const Gap(AppSpacing.xl),
                    Text('Le poste', style: text.titleMedium),
                    const Gap(AppSpacing.md),

                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Intitule du poste',
                        hintText: 'Professeur de Mathématiques',
                      ),
                      validator: (v) => Validators.required(v, 'L’intitule'),
                    ),
                    const Gap(AppSpacing.lg),

                    DropdownButtonFormField<String>(
                      initialValue: matiere,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Matière'),
                      items: [
                        for (final subject in subjects)
                          DropdownMenuItem(
                            value: subject.id,
                            child: Text(subject.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _subjectId = value),
                      validator: (value) =>
                          value == null ? 'Selectionnez la matière' : null,
                    ),
                    const Gap(AppSpacing.lg),

                    Text('Niveaux concernes', style: text.titleSmall),
                    const Gap(AppSpacing.sm),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final level in levels)
                          FilterChip(
                            label: Text(level.name),
                            selected: _levelIds.contains(level.id),
                            showCheckmark: false,
                            selectedColor: AppColors.primarySurface,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _levelIds.add(level.id);
                              } else {
                                _levelIds.remove(level.id);
                              }
                            }),
                            side: BorderSide(
                              color: _levelIds.contains(level.id)
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                    const Gap(AppSpacing.lg),

                    DropdownButtonFormField<String>(
                      initialValue: ville,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      items: [
                        for (final city in cities)
                          DropdownMenuItem(value: city, child: Text(city)),
                      ],
                      onChanged: (value) => setState(() => _city = value),
                      validator: (value) =>
                          value == null ? 'Selectionnez la ville' : null,
                    ),
                    const Gap(AppSpacing.lg),

                    DropdownButtonFormField<ContractType>(
                      initialValue: _contractType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type de contrat',
                      ),
                      items: [
                        for (final type in ContractType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _contractType = value ?? ContractType.permanent,
                      ),
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _description,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description du poste',
                        alignLabelWithHint: true,
                        hintText:
                            'Missions, charge horaire, conditions '
                            'particulieres…',
                      ),
                    ),

                    const Gap(AppSpacing.xl),
                    Text('Rémunération', style: text.titleMedium),
                    const Gap(AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMin,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimum',
                              suffixText: 'GNF',
                            ),
                            validator: (v) =>
                                Validators.positiveAmount(v, required: false),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMax,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Maximum',
                              suffixText: 'GNF',
                            ),
                            validator: (v) =>
                                Validators.positiveAmount(v, required: false),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      value: _salaryPublished,
                      onChanged: (value) =>
                          setState(() => _salaryPublished = value),
                      title: Text(
                        'Afficher la rémunération',
                        style: text.bodyLarge,
                      ),
                      subtitle: Text(
                        'Les offres avec rémunération affichee recoivent '
                        'davantage de candidatures.',
                        style: text.labelSmall,
                      ),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                    ),

                    const Gap(AppSpacing.lg),
                    Text('Exigences', style: text.titleMedium),
                    const Gap(AppSpacing.md),

                    Text(
                      'Expérience minimale : $_minExperience an(s)',
                      style: text.titleSmall,
                    ),
                    Slider(
                      value: _minExperience.toDouble(),
                      max: 15,
                      divisions: 15,
                      activeColor: AppColors.primary,
                      label: '$_minExperience an(s)',
                      onChanged: (value) =>
                          setState(() => _minExperience = value.round()),
                    ),

                    SwitchListTile(
                      value: _requiresCertification,
                      onChanged: (value) =>
                          setState(() => _requiresCertification = value),
                      title: Text(
                        'Certification exigee',
                        style: text.bodyLarge,
                      ),
                      subtitle: Text(
                        'Seuls les enseignants ayant réussi le test de la '
                        'matière et du niveau seront bien classes.',
                        style: text.labelSmall,
                      ),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                    ),

                    const Gap(AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        _startDate == null
                            ? 'Date de prise de poste'
                            : Fmt.date(_startDate!),
                        style: text.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickStartDate,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _saving ? null : _publish,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _visibility == JobVisibility.private
                            ? 'Publier l’offre privee'
                            : 'Publier l’offre',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('fr'),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// Ce que la fiche de l'etablissement fournit sans qu'on le redemande.
  ///
  /// Prend la fiche en argument plutot que de la lire : `build` doit s'y
  /// **abonner** (`watch`) pour se redessiner quand le depot repond, alors que
  /// la publication se contente de la lire. Derive a chaque fois et jamais
  /// ecrit dans l'etat, parce qu'appeler `setState` depuis `build` leve.
  ({String? ville, String? matiere}) _defaults(InstitutionRow? fiche) {
    final cherchees = [
      for (final id in (fiche?.neededSubjectIds ?? '').split(','))
        if (id.trim().isNotEmpty) id.trim(),
    ];
    return (
      ville: fiche?.city,
      // Une seule matiere cherchee : on la propose. Une parmi cinq serait un
      // choix fait a sa place, et c'est le genre de valeur qu'on valide sans
      // la relire.
      matiere: cherchees.length == 1 ? cherchees.first : null,
    );
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_levelIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectionnez au moins un niveau.')),
      );
      return;
    }

    final institutionId = ref.read(currentInstitutionIdProvider);
    if (institutionId == null) return;

    // Les mêmes valeurs par défaut que celles affichées : la ville et la
    // matière peuvent n'avoir jamais été touchées parce qu'elles étaient déjà
    // bonnes. Les relire ici évite de publier une offre sans ville au seul
    // motif que personne n'a ouvert la liste déroulante.
    final defauts = _defaults(ref.read(institutionRecordProvider).valueOrNull);
    final matiere = _subjectId ?? defauts.matiere;
    final ville = _city ?? defauts.ville;
    if (matiere == null || ville == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez la matière et la ville.')),
      );
      return;
    }

    setState(() => _saving = true);
    await ref
        .read(jobRepositoryProvider)
        .publishJob(
          institutionId: institutionId,
          title: _title.text.trim(),
          subjectId: matiere,
          levelIds: _levelIds.toList(),
          city: ville,
          contractType: _contractType,
          visibility: _visibility,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          salaryMin: int.tryParse(_salaryMin.text.trim()),
          salaryMax: int.tryParse(_salaryMax.text.trim()),
          salaryPublished: _salaryPublished,
          minExperience: _minExperience,
          requiresCertification: _requiresCertification,
          startDate: _startDate,
          invitedTeacherIds: _visibility == JobVisibility.private
              ? _invited.toList()
              : const [],
        );

    ref.invalidate(institutionJobsProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySurface : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? AppColors.primary : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(description, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}

/// Selection des enseignants invites sur une offre privee (§29).
class _InvitePicker extends ConsumerWidget {
  const _InvitePicker({required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(teacherSearchProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    if (candidates.isEmpty) {
      return AppCard(
        child: Text(
          'Aucun enseignant disponible pour l’invitation. Affinez d’abord '
          'votre recherche dans l’onglet Enseignants.',
          style: text.bodySmall,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inviter des enseignants (${selected.length} selectionne(s))',
            style: text.titleSmall,
          ),
          const SizedBox(height: 10),
          for (final candidate in candidates.take(8))
            CheckboxListTile(
              value: selected.contains(candidate.profile.teacherId),
              onChanged: (checked) {
                final next = {...selected};
                if (checked ?? false) {
                  next.add(candidate.profile.teacherId);
                } else {
                  next.remove(candidate.profile.teacherId);
                }
                onChanged(next);
              },
              title: Text(candidate.profile.fullName, style: text.bodyLarge),
              subtitle: Text(
                candidate.profile.displayHeadline,
                style: text.labelSmall,
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
            ),
        ],
      ),
    );
  }
}
