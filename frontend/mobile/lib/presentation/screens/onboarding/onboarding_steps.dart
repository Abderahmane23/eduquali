import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/storage/document_pipeline.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/onboarding_spec.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../controllers/onboarding_flow_controller.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/type_ahead.dart';
import '../../widgets/typeform_kit.dart';

/// Composants de rendu, un par type d'étape declare dans le JSON.

/// Illustration d'étape.
///
/// Hauteur bornée et `BoxFit.contain` : les visuels n'ont pas tous le même
/// cadrage (3:2, 2:3, carré), et aucun ne doit être recadré — sur ceux en
/// pied, un recadrage centré coupe les têtes.
///
/// Le fond reprend celui des illustrations, si bien que le remplissage
/// latéral ne se voit pas.
class OnboardingIllustrationView extends StatelessWidget {
  const OnboardingIllustrationView({super.key, required this.image});

  final OnboardingIllustration image;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    // Au-dela, il ne reste plus assez de place pour le titre, le texte et
    // l'action sur un petit ecran.
    final box = (height * 0.22).clamp(104.0, 200.0);

    return Semantics(
      image: true,
      label: image.alt,
      child: Container(
        width: double.infinity,
        height: box,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // `papier`, le fond des ecrans de la charte. C'etait un bleu
          // pale ecrit a la main, hors palette : la seule teinte de fond que
          // la charte connaisse est celle-la.
          color: AppColors.papier,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          image.asset,
          fit: BoxFit.contain,
          // Une illustration manquante ne doit pas faire tomber l'ecran :
          // le cadre reste, la question passe.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Écran d'accroche : quelques chiffres, aucune saisie.
class StatementStepView extends StatelessWidget {
  const StatementStepView({super.key, required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final h in step.highlights)
        HighlightRow(value: h.value, label: h.label),
    ],
  );
}

/// Choix du profil.
///
/// Boutons empilés pleine largeur plutôt qu'une liste d'étiquettes : c'est la
/// décision qui oriente tout le reste du parcours, elle mérite la hauteur
/// d'un bouton et une phrase d'explication (§1 du design_skill — une
/// décision par écran sur mobile).
class RoleSelectStepView extends ConsumerWidget {
  const RoleSelectStepView({
    super.key,
    required this.spec,
    required this.step,
    required this.onAdvance,
  });

  final OnboardingFlowSpec spec;
  final OnboardingStep step;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final selected = ref.watch(
      onboardingFlowProvider(spec).select((s) => s.answers[step.fieldId]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in step.options) ...[
          _RoleButton(
            label: option.label,
            description: option.description,
            selected: selected == option.value,
            onTap: () {
              controller.setAnswer(step.fieldId!, option.value);
              onAdvance();
            },
          ),
          const Gap(AppSpacing.sm),
        ],
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          // 72 px : une cible confortable pour la question la plus lourde du
          // parcours (§7 — jamais moins de 44 px).
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
              if (description != null) ...[
                const Gap(AppSpacing.xs),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Enumeration des étapes du service.
class StepsPreviewStepView extends StatelessWidget {
  const StepsPreviewStepView({super.key, required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < step.items.length; i++)
        NumberedStep(
          index: i + 1,
          label: step.items[i],
          isLast: i == step.items.length - 1,
        ),
    ],
  );
}

/// Carrousel de profils mis en avant.
class CarouselStepView extends ConsumerWidget {
  const CarouselStepView({super.key, required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(teacherSearchProvider);

    return candidates.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        final featured = items.take(3).toList();
        if (featured.isEmpty) return const SizedBox.shrink();

        /*
         * Profils empilés, pas un carrousel.
         *
         * Le défilement horizontal cachait les profils suivants derrière un
         * geste que rien n'annonce. Trois cartes visibles d'un coup disent
         * la même chose sans rien cacher.
         *
         * Le score en pourcentage a été retiré : il promettait une précision
         * que ces profils mis en avant n'ont pas.
         */
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final candidate in featured) ...[
              _FeaturedTeacherCard(profile: candidate.profile),
              const Gap(AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _FeaturedTeacherCard extends StatelessWidget {
  const _FeaturedTeacherCard({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final certification = profile.certifications.isEmpty
        ? null
        : profile.certifications.first;

    return AppCard(
      child: Row(
        children: [
          ProfileAvatar(
            firstName: profile.firstName,
            lastName: profile.lastName,
            photoPath: profile.photoPath,
            size: 44,
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  certification?.title ?? profile.displayHeadline,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            profile.city ?? '—',
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Plusieurs champs sur un meme ecran.
class FormStepView extends ConsumerWidget {
  const FormStepView({super.key, required this.spec, required this.step});

  final OnboardingFlowSpec spec;
  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final state = ref.watch(onboardingFlowProvider(spec));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in step.fields) ...[
          _FieldView(
            field: field,
            value: state.answers[field.id],
            answers: state.answers,
            filterLabel: step.filterLabelFor(field),
            countryValue: field.dependsOn == null
                ? null
                : state.answers[field.dependsOn!] as String?,
            onChanged: (value) => controller.setAnswerAndClear(
              field.id,
              value,
              dependents: step.dependentFields(field.id),
            ),
          ),
          const Gap(AppSpacing.lg),
        ],
      ],
    );
  }
}

class _FieldView extends ConsumerWidget {
  const _FieldView({
    required this.field,
    required this.value,
    required this.onChanged,
    this.answers = const {},
    this.filterLabel,
    this.countryValue,
  });

  final OnboardingField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  /// Reponses deja donnees — un champ en cascade y lit celle dont il depend.
  final Map<String, dynamic> answers;

  /// Libelle du champ dont celui-ci depend, quand il y en a un.
  final String? filterLabel;

  final String? countryValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (field.type) {
      case FieldType.text:
        return TextFormField(
          initialValue: value as String?,
          autofocus: field.autofocus,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: field.label),
          onChanged: onChanged,
        );

      case FieldType.phone:
        // La Guinee est le seul pays servi : l'indicatif est donc fixe, et
        // la saisie bornee a neuf chiffres. Laisser taper plus laissait
        // croire qu'un numero etranger passerait, alors que la validation
        // le refusait deux ecrans plus loin.
        return TextFormField(
          initialValue: value as String?,
          keyboardType: TextInputType.phone,
          maxLength: 9,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: field.label,
            prefixText: '${AppConstants.phonePrefix} ',
            counterText: '',
            helperText: '9 chiffres, après l’indicatif',
            // Le champ dit lui-meme qu'il est bon, plutot que de laisser
            // chercher le bouton pour decouvrir qu'il est encore gris.
            suffixIcon: ValidatedSuffix(
              valid: Validators.phone(value as String?) == null,
              visible: (value as String?)?.isNotEmpty ?? false,
            ),
          ),
          onChanged: onChanged,
          validator: Validators.phone,
        );

      case FieldType.password:
        return _PasswordField(
          label: field.label,
          hint: field.hint,
          minLength: field.minLength ?? 8,
          autofocus: field.autofocus,
          value: value as String?,
          onChanged: onChanged,
        );

      case FieldType.month:
        return _MonthField(
          label: field.label,
          value: value as String?,
          nullableLabel: field.nullableLabel,
          onChanged: onChanged,
        );

      case FieldType.dropdown:
      case FieldType.combo:
        // Options ecrites dans le parcours, ou tirees d'une source nommee.
        // Jamais les deux : une liste qui vient de deux endroits finit par
        // en contredire un.
        final options = field.optionsSource == null
            ? AsyncValue<List<OnboardingOption>>.data(field.options)
            : ref.watch(onboardingOptionsProvider(field.optionsSource!));

        // Cascade : tant que la reponse dont ce champ depend manque, la
        // liste complete n'a aucun sens — les 13 communes de Conakry n'ont
        // rien a faire devant un professeur de Labe.
        final parent = field.optionsFilter?.field;
        final waiting = parent != null && answers[parent] == null;

        return options.when(
          loading: () => const LinearProgressIndicator(),
          // Faire disparaitre le champ serait le pire des cas : la question
          // devient impossible a repondre, « Continuer » reste gris, et
          // rien n'explique pourquoi. On garde un champ visible et on dit
          // ce qui ne va pas.
          error: (error, _) => InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              errorText: 'Liste indisponible. Redémarrez l’application.',
            ),
            child: const Text('—'),
          ),
          data: (all) {
            final items = waiting
                ? const <OnboardingOption>[]
                : field.optionsFilter?.apply(all, answers) ?? all;

            // Une valeur libre ne figure pas dans la liste : la garder
            // afficherait un choix que la feuille ne propose plus.
            final known = items.any((o) => o.value == value);

            // Feuille du bas plutot qu'un menu flottant : les prefectures
            // sont 57, les etablissements de Conakry seront des centaines,
            // et un menu sans recherche devient inutilisable bien avant.
            return PickerField(
              label: field.label,
              // `allowCustom` etait declare dans les parcours depuis le
              // debut et n'etait lu nulle part : la liste restait fermee, et
              // un parent dont l'ecole manque ne pouvait pas finir son
              // inscription.
              allowCustom: field.allowCustom,
              value: known || field.allowCustom ? value as String? : null,
              enabled: !waiting,
              helperText: waiting
                  ? 'Choisissez d’abord : ${filterLabel ?? "la réponse précédente"}'
                  : null,
              options: [
                for (final option in items)
                  PickerOption(
                    value: option.value,
                    label: option.label,
                    description: option.description,
                  ),
              ],
              onChanged: onChanged,
            );
          },
        );
    }
  }
}

/// Mot de passe, avec un oeil pour reveler.
///
/// Un seul champ et pas de confirmation : « retapez votre mot de passe »
/// double la saisie sur un clavier de telephone et fait echouer une
/// inscription sur deux. Pouvoir relire ce qu'on a tape rend le meme service
/// pour un geste.
///
/// Ce qui manque s'affiche pendant la saisie et non apres l'envoi : a ce
/// moment-la le compte existe deja, et le refus laisse un numero pris sans
/// compte utilisable.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.minLength,
    required this.autofocus,
    required this.onChanged,
    this.hint,
    this.value,
  });

  final String label;
  final String? hint;
  final int minLength;
  final bool autofocus;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final saisi = widget.value ?? '';
    final manque = saisi.isNotEmpty && saisi.length < widget.minLength;

    return TextFormField(
      initialValue: widget.value,
      autofocus: widget.autofocus,
      obscureText: !_visible,
      // Ni correction ni suggestion : le clavier reecrirait le mot de passe en
      // un mot du dictionnaire sans le dire.
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 128,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: manque
            ? 'Encore ${widget.minLength - saisi.length} caractère(s)'
            : widget.hint,
        counterText: '',
        suffixIcon: IconButton(
          onPressed: () => setState(() => _visible = !_visible),
          tooltip: _visible
              ? 'Masquer le mot de passe'
              : 'Afficher le mot de passe',
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
        ),
      ),
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.nullableLabel,
  });

  final String label;
  final String? value;
  final ValueChanged<dynamic> onChanged;
  final String? nullableLabel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [for (var y = now.year; y >= now.year - 40; y--) y];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              for (final year in years)
                DropdownMenuItem(value: '$year', child: Text('$year')),
            ],
            onChanged: onChanged,
          ),
        ),
        if (nullableLabel != null) ...[
          const Gap(AppSpacing.md),
          TextButton(
            onPressed: () => onChanged(null),
            child: Text(nullableLabel!),
          ),
        ],
      ],
    );
  }
}

/// Choix unique — la selection fait avancer immediatement.
class SingleChoiceStepView extends ConsumerWidget {
  const SingleChoiceStepView({
    super.key,
    required this.spec,
    required this.step,
    required this.onAdvance,
  });

  final OnboardingFlowSpec spec;
  final OnboardingStep step;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingFlowProvider(spec));

    // `single_choice` ignorait `optionsSource` : une etape comme « Il est en
    // quelle classe ? » n'affichait aucune option et bloquait le parcours.
    if (step.options.isEmpty && step.optionsSource != null) {
      final options = ref.watch(onboardingOptionsProvider(step.optionsSource!));
      return options.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) => _rows(ref, state, items),
      );
    }

    return _rows(ref, state, step.options);
  }

  Widget _rows(
    WidgetRef ref,
    OnboardingFlowState state,
    List<OnboardingOption> options,
  ) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final selected = state.answers[step.fieldId] as String?;
    // Le filtre s'applique apres resolution : la liste vient du referentiel,
    // la restriction vient d'une reponse deja donnee.
    final shown = step.optionsFilter?.apply(options, state.answers) ?? options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in shown)
          ChoiceRow(
            label: option.label,
            selected: selected == option.value,
            onTap: () => controller.setAnswer(step.fieldId!, option.value),
          ),
      ],
    );
  }
}

/// Choix multiple sous forme d'etiquettes.
class MultiChoiceStepView extends ConsumerWidget {
  const MultiChoiceStepView({
    super.key,
    required this.spec,
    required this.step,
  });

  final OnboardingFlowSpec spec;
  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    ref.watch(onboardingFlowProvider(spec));

    final answers = ref.watch(onboardingFlowProvider(spec)).answers;

    final inline = step.options;
    if (inline.isNotEmpty) {
      return _tags(controller, inline, answers);
    }

    final options = ref.watch(onboardingOptionsProvider(step.optionsSource!));
    return options.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('$error'),
      data: (items) => _tags(controller, items, answers),
    );
  }

  Widget _tags(
    OnboardingFlowController controller,
    List<OnboardingOption> options,
    Map<String, dynamic> answers,
  ) {
    final all = step.allOption;
    final pertinentes = step.optionsFilter?.apply(options, answers) ?? options;

    // Les longues listes se tapent, les courtes se lisent.
    if (step.searchable) {
      // Sur un champ de saisie, le filtre **ordonne** au lieu de restreindre.
      //
      // Il restreignait : un professeur de primaire ne voyait que 6 des 24
      // matières, un professeur de lycée 15. Les autres n'étaient pas
      // seulement rangées plus loin, elles étaient introuvables — et celui
      // qui enseigne la philosophie au lycée mais aussi en L1 ne pouvait pas
      // le déclarer.
      //
      // Restreindre avait un sens sur une nappe d'étiquettes, où tout
      // s'affiche d'un bloc. Sur un champ qu'on interroge, ce qui compte est
      // que les matières de ses classes viennent en tête ; les autres
      // restent à une frappe.
      final ids = {for (final o in pertinentes) o.value};
      final autres = [
        for (final option in options)
          if (!ids.contains(option.value)) option,
      ];

      return TypeAheadTags(
        options: [
          if (all != null) PickerOption(value: all.value, label: all.label),
          for (final option in pertinentes)
            PickerOption(value: option.value, label: option.label),
          for (final option in autres)
            PickerOption(
              value: option.value,
              label: option.label,
              // Dit pourquoi elle vient après, plutôt que de la cacher.
              description: 'Hors des classes choisies',
            ),
        ],
        selected: [
          for (final value
              in (answers[step.fieldId!] as List<dynamic>? ?? const []))
            value as String,
        ],
        onToggle: (value) =>
            controller.toggleMulti(step.fieldId!, value, allValue: all?.value),
        hint: step.searchHint ?? 'Tapez pour chercher…',
      );
    }

    // Sur une nappe d'etiquettes, le filtre restreint pour de bon : tout
    // s'affiche d'un bloc, et il n'y a pas de champ pour aller chercher ce
    // qui manque.
    return TagWrap(
      children: [
        if (all != null)
          SelectableTag(
            label: all.label,
            selected: controller.isSelected(step.fieldId!, all.value),
            onTap: () => controller.toggleMulti(
              step.fieldId!,
              all.value,
              allValue: all.value,
            ),
          ),
        for (final option in pertinentes)
          SelectableTag(
            label: option.label,
            selected: controller.isSelected(step.fieldId!, option.value),
            onTap: () => controller.toggleMulti(
              step.fieldId!,
              option.value,
              allValue: all?.value,
            ),
          ),
      ],
    );
  }
}

/// Oui / Non.
class BooleanStepView extends ConsumerWidget {
  const BooleanStepView({
    super.key,
    required this.spec,
    required this.step,
    required this.onAdvance,
  });

  final OnboardingFlowSpec spec;
  final OnboardingStep step;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final state = ref.watch(onboardingFlowProvider(spec));

    return YesNoChoice(
      value: state.answers[step.fieldId] as bool?,
      onChanged: (value) => controller.setAnswer(step.fieldId!, value),
    );
  }
}

/// Curseur numérique avec estimation de trajet.
class RangeStepView extends ConsumerWidget {
  const RangeStepView({super.key, required this.spec, required this.step});

  final OnboardingFlowSpec spec;
  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final state = ref.watch(onboardingFlowProvider(spec));
    final raw = state.answers[step.fieldId];
    final value =
        (raw is num ? raw.toDouble() : step.defaultValue?.toDouble()) ??
        step.min;

    return RangeChoice(
      value: value,
      min: step.min,
      max: step.max,
      step: step.stepSize,
      unit: step.unit,
      estimate: step.estimate?.describe(value),
      onChanged: (v) => controller.setAnswer(step.fieldId!, v.round()),
    );
  }
}

/// Choix d'une formule (§35 — Visibilité+).
class PlanStepView extends ConsumerWidget {
  const PlanStepView({super.key, required this.spec, required this.step});

  final OnboardingFlowSpec spec;
  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final state = ref.watch(onboardingFlowProvider(spec));
    final selected = state.answers[step.fieldId] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final plan in step.plans)
          PlanCard(
            name: plan.name,
            price: plan.price,
            currency: spec.currency,
            highlight: plan.highlight,
            recommended: plan.recommended,
            selected: selected == plan.value,
            onTap: () => controller.setAnswer(step.fieldId!, plan.value),
          ),
      ],
    );
  }
}

/// Dépôt du CV et des diplômes.
///
/// La seule étape du parcours qui garde « Passer » : un candidat n'a pas
/// toujours son diplôme sous la main, et le lui réclamer avant de l'inscrire
/// le ferait abandonner. Il le déposera depuis son profil.
class UploadStepView extends ConsumerWidget {
  const UploadStepView({super.key, required this.spec, required this.step});

  final OnboardingFlowSpec spec;
  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final answers = ref.watch(onboardingFlowProvider(spec)).answers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final upload in step.uploads) ...[
          _UploadTile(
            label: upload.label,
            path: answers[upload.id] as String?,
            // Un vrai fichier depuis le 02/10. Le pas precedent enregistrait
            // le texte « cv_path.pdf » : le parcours se terminait, la fiche
            // affichait un CV, et il n'y avait aucun fichier derriere.
            //
            // Le chemin seulement est garde dans les reponses : le compte
            // n'existe pas encore a cette etape, donc rien ne peut etre
            // rattache a une fiche professeur. C'est la creation du compte
            // qui enregistrera les documents.
            onPick: () => _choisir(context, ref, controller, upload),
            onClear: () => controller.setAnswer(upload.id, null),
          ),
          const Gap(AppSpacing.md),
        ],
      ],
    );
  }
}

/// Ouvre le selecteur de fichiers et retient le chemin choisi.
///
/// Les refus se disent a l'ecran : un fichier trop lourd que l'on ignore en
/// silence laisse croire que l'appui n'a pas marche, et la personne reessaie.
Future<void> _choisir(
  BuildContext context,
  WidgetRef ref,
  OnboardingFlowController controller,
  OnboardingUpload upload,
) async {
  // Le CV et le diplome sont deux types distincts cote serveur : c'est ce qui
  // permet de verifier le second sans toucher au premier.
  final type = upload.id.contains('cv')
      ? DocumentType.cv
      : DocumentType.diploma;
  try {
    final fichier = await ref
        .read(documentPipelineProvider)
        .pickDocumentFile(type);
    if (fichier == null) return;
    controller.setAnswer(upload.id, fichier.path);
  } on DocumentTooLarge catch (refus) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('$refus')));
  } catch (erreur) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Lecture du fichier impossible : $erreur')),
      );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.label,
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = path != null;

    return AppCard(
      onTap: done ? null : onPick,
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.upload_file_outlined,
            size: 20,
            color: done ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: text.titleSmall)),
          if (done)
            TextButton(onPressed: onClear, child: const Text('Retirer'))
          else
            Text(
              'télécharger',
              style: text.bodySmall?.copyWith(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

/// Les sept jours empilés ; toucher un jour ouvre ses heures.
///
/// Remplace les deux étapes « jours » puis « moments » : elles posaient la
/// même question en deux fois, et rien ne reliait un jour à l'heure qui lui
/// correspondait — un professeur libre le mardi soir et le samedi matin ne
/// pouvait pas le dire.
class DayHoursStepView extends ConsumerStatefulWidget {
  const DayHoursStepView({super.key, required this.spec, required this.step});

  final OnboardingFlowSpec spec;
  final OnboardingStep step;

  @override
  ConsumerState<DayHoursStepView> createState() => _DayHoursState();
}

class _DayHoursState extends ConsumerState<DayHoursStepView> {
  /// Le jour deplie. Un seul a la fois : sept listes ouvertes ne se lisent
  /// plus.
  Weekday? _open;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(onboardingFlowProvider(widget.spec).notifier);
    final answers = ref.watch(onboardingFlowProvider(widget.spec)).answers;
    final field = widget.step.fieldId!;
    final saved = Map<String, dynamic>.from(
      (answers[field] as Map?) ?? const {},
    );

    List<String> hoursOf(Weekday day) => [
      ...((saved[day.code] as List?) ?? const []).map((h) => '$h'),
    ];

    void write(Map<String, dynamic> next) => controller.setAnswer(field, next);

    void toggleSlot(Weekday day, DaySlot slot) {
      final current = hoursOf(day);
      current.contains(slot.code)
          ? current.remove(slot.code)
          : current.add(slot.code);
      final next = {...saved};
      // Un jour sans heure ne veut rien dire : on le retire plutot que de
      // garder une liste vide qui compterait comme une disponibilite.
      current.isEmpty ? next.remove(day.code) : next[day.code] = current;
      write(next);
    }

    /// Cocher un jour le prend en entier ; on retire ensuite les moments ou
    /// l'on n'est pas libre.
    ///
    /// L'inverse — cocher puis devoir choisir une heure — laissait des jours
    /// coches sans creneau, que le parcours refusait sans dire pourquoi.
    void toggleDay(Weekday day) {
      final next = {...saved};
      if (hoursOf(day).isEmpty) {
        next[day.code] = [for (final slot in DaySlot.values) slot.code];
        setState(() => _open = day);
      } else {
        next.remove(day.code);
      }
      write(next);
    }

    final choisis = saved.values.where((h) => h is List && h.isNotEmpty).length;
    final manquants = widget.step.minSelected - choisis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ce qu'il reste a faire, ecrit avant la liste : le bouton
        // « Continuer » desactive sans explication laissait chercher.
        if (manquants > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: InfoBanner(
              message: manquants == 1
                  ? 'Choisissez encore un jour.'
                  : 'Choisissez encore $manquants jours.',
              tone: StatusTone.info,
              icon: Icons.info_outline,
            ),
          ),

        for (final day in Weekday.values) ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _open = _open == day ? null : day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        // La case a cocher : sans elle, rien ne disait que le
                        // jour lui-meme se choisit — il fallait deviner qu'il
                        // se deplie.
                        Checkbox(
                          value: hoursOf(day).isNotEmpty,
                          onChanged: (_) => toggleDay(day),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.label,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                hoursOf(day).isEmpty
                                    ? 'Non disponible'
                                    : hoursOf(day)
                                          .map(
                                            (c) =>
                                                DaySlot.fromCode(c)?.label ?? c,
                                          )
                                          .join(', '),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: hoursOf(day).isEmpty
                                          ? AppColors.textTertiary
                                          : AppColors.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Icon(
                            _open == day
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 22,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_open == day) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final slot in DaySlot.values)
                          FilterChip(
                            label: Text('${slot.label} · ${slot.hours}'),
                            selected: hoursOf(day).contains(slot.code),
                            onSelected: (_) => toggleSlot(day, slot),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
        ],
      ],
    );
  }
}
