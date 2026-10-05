import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Primitives visuelles des parcours d'inscription.
///
/// Un écran = une question. Pas de texte explicatif : le libelle porte seul la
/// demande, les options sont assez explicites pour se passer de commentaire.
/// L'action principale reste toujours au même endroit, en bas a droite.

/// Coquille commune : progression en haut, question au centre, action en bas.
class TypeformScaffold extends StatelessWidget {
  const TypeformScaffold({
    super.key,
    required this.title,
    this.body,
    this.illustration,
    required this.child,
    required this.onContinue,
    this.onBack,
    this.progress,
    this.sectionLabel,
    this.continueLabel = 'Continuer',
    this.secondary,
    this.canContinue = true,
  });

  final String title;

  /// Paragraphe d'explication sous le titre, quand la question en demande un.
  final String? body;

  /// Illustration posée au-dessus du titre : elle pose la scène avant qu'on
  /// demande quoi que ce soit.
  final Widget? illustration;

  final Widget child;

  /// `null` desactive l'action : la question attend une réponse.
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final double? progress;
  final String? sectionLabel;
  final String continueLabel;

  /// Action discrete sous le bouton principal (refus d'une formule).
  final Widget? secondary;
  final bool canContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Retour',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.touchTarget,
                        minHeight: AppSpacing.touchTarget,
                      ),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: progress == null
                        ? const SizedBox.shrink()
                        : ThinProgressBar(value: progress!, height: 4),
                  ),
                  const Gap(AppSpacing.md),
                  SizedBox(
                    width: 40,
                    child: sectionLabel == null
                        ? null
                        : Text(
                            sectionLabel!,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.section,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (illustration != null) ...[
                      illustration!,
                      const Gap(AppSpacing.lg),
                    ],
                    Text(
                      title,
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (body != null) ...[
                      const Gap(AppSpacing.sm),
                      Text(
                        body!,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const Gap(AppSpacing.xxl),
                    child,
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (secondary != null) ...[
                    secondary!,
                    const Gap(AppSpacing.sm),
                  ],
                  FilledButton(
                    onPressed: canContinue ? onContinue : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.lg,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(continueLabel),
                        const Gap(AppSpacing.sm),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
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
}

/// Etiquette selectionnable — selection unique ou multiple.
class SelectableTag extends StatelessWidget {
  const SelectableTag({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille d'etiquettes.
class TagWrap extends StatelessWidget {
  const TagWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: children,
  );
}

/// Grande option en pleine largeur, pour un choix unique structurant.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Oui / Non.
class YesNoChoice extends StatelessWidget {
  const YesNoChoice({super.key, required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ChoiceRow(
          label: 'Oui',
          selected: value == true,
          onTap: () => onChanged(true),
        ),
      ),
      const Gap(AppSpacing.md),
      Expanded(
        child: ChoiceRow(
          label: 'Non',
          selected: value == false,
          onTap: () => onChanged(false),
        ),
      ),
    ],
  );
}

/// Curseur avec valeur et estimation dérivée.
class RangeChoice extends StatelessWidget {
  const RangeChoice({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.unit,
    this.estimate,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String? unit;
  final String? estimate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final divisions = ((max - min) / step).round().clamp(1, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.round().toString(),
              style: text.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            if (unit != null) ...[
              const Gap(AppSpacing.sm),
              Text(
                unit!,
                style: text.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const Spacer(),
            if (estimate != null)
              Text(
                estimate!,
                style: text.bodyMedium?.copyWith(color: AppColors.textTertiary),
              ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Carte d'une formule payante.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.price,
    required this.currency,
    required this.highlight,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final String name;
  final double price;
  final String currency;
  final String highlight;
  final bool selected;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
                      Row(
                        children: [
                          Text(
                            name,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (recommended) ...[
                            const Gap(AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                'Conseille',
                                style: text.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        highlight,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.md),
                // « 100 000 GNF », et non « GNF100000.00 ».
                //
                // La devise passe à droite du montant, comme elle s'écrit et
                // se dit en Guinée. Les décimales tombent : le franc
                // guinéen n'a pas de subdivision en usage, et « ,00 »
                // allongeait un nombre déjà long de six chiffres.
                Text(
                  '${Fmt.money(price, withCurrency: false)} $currency',
                  maxLines: 1,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chiffre cle d'un écran d'accroche.
class HighlightRow extends StatelessWidget {
  const HighlightRow({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              value,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const Gap(AppSpacing.lg),
          Expanded(
            child: Text(
              label,
              style: text.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Étape numerotee de l'écran « comment ca marche ».
class NumberedStep extends StatelessWidget {
  const NumberedStep({
    super.key,
    required this.index,
    required this.label,
    required this.isLast,
  });

  final int index;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: AppColors.border)),
            ],
          ),
          const Gap(AppSpacing.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
