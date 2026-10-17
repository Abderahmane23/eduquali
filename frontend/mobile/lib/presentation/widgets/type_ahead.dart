import 'package:flutter/material.dart';

import '../../core/utils/text_search.dart';
import '../theme/app_theme.dart';
import 'picker_sheet.dart';

/// Un champ de saisie assistée, et ce qui a été retenu en dessous.
///
/// Remplace les nappes d'étiquettes. Vingt-quatre matières affichées d'un
/// bloc, c'est un mur : il faut les lire toutes pour trouver « Physique »,
/// l'écran défile, et la liste grandira encore. Ici on tape « phy », il
/// reste une ligne.
///
/// Ce qui est choisi descend en bas sous forme d'étiquette et le champ se
/// vide, prêt pour la suivante — on peut en ajouter dix sans jamais quitter
/// le clavier.
class TypeAheadTags extends StatefulWidget {
  const TypeAheadTags({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.hint = 'Tapez pour chercher…',
    this.emptyMessage = 'Aucun résultat',
    this.allowCustom = false,
    this.onCustom,
    this.maxVisible = 6,
    this.enabled = true,
  });

  final List<PickerOption> options;

  /// Les valeurs déjà retenues, dans l'ordre où elles l'ont été.
  final List<String> selected;

  /// Appelée pour ajouter comme pour retirer : une seule porte, donc pas de
  /// désynchronisation possible entre l'étiquette et la liste.
  final ValueChanged<String> onToggle;

  final String hint;
  final String emptyMessage;

  /// Autorise une valeur absente de la liste — un référentiel n'est jamais
  /// complet.
  final bool allowCustom;
  final ValueChanged<String>? onCustom;

  /// Combien de suggestions au repos. Au-delà, la liste redevient le mur
  /// qu'on remplace.
  final int maxVisible;

  final bool enabled;

  @override
  State<TypeAheadTags> createState() => _TypeAheadTagsState();
}

class _TypeAheadTagsState extends State<TypeAheadTags> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Ce qui reste à proposer : ce qui correspond à la saisie, moins ce qui
  /// est déjà en bas. Reproposer un choix déjà fait invite au double appui,
  /// qui le retirerait.
  List<PickerOption> get _suggestions {
    final q = _query.text.trim();
    return [
      for (final option in widget.options)
        if (!widget.selected.contains(option.value) &&
            (matchesSearch(option.label, q) ||
                (q.isNotEmpty && matchesSearch(option.description ?? '', q))))
          option,
    ];
  }

  /// La saisie libre, quand elle ne correspond à rien d'existant.
  String? get _libre {
    if (!widget.allowCustom) return null;
    final saisi = _query.text.trim();
    if (saisi.isEmpty) return null;
    final existe = widget.options.any(
      (o) => foldText(o.label) == foldText(saisi),
    );
    return existe ? null : saisi;
  }

  /// Le libellé d'une valeur retenue. Une valeur saisie librement n'est dans
  /// aucune liste : elle s'affiche telle qu'elle a été tapée.
  String _labelOf(String value) =>
      widget.options
          .where((o) => o.value == value)
          .map((o) => o.label)
          .firstOrNull ??
      value;

  void _choisir(String value) {
    widget.onToggle(value);
    _query.clear();
    setState(() {});
  }

  void _ajouterLibre(String saisi) {
    (widget.onCustom ?? widget.onToggle).call(saisi);
    _query.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final suggestions = _suggestions;
    final libre = _libre;
    // Au repos on montre quelques pistes ; en tapant, tout ce qui colle.
    final ouvert = _focus.hasFocus || q.isNotEmpty;
    final shown = q.isEmpty
        ? suggestions.take(widget.maxVisible).toList()
        : suggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _query,
          focusNode: _focus,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (libre != null) {
              _ajouterLibre(libre);
            } else if (shown.isNotEmpty) {
              _choisir(shown.first.value);
            }
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Effacer',
                    onPressed: () {
                      _query.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),

        if (ouvert) ...[
          const SizedBox(height: AppSpacing.sm),
          _Suggestions(
            options: shown,
            libre: libre,
            emptyMessage: widget.emptyMessage,
            onChoose: _choisir,
            onCustom: _ajouterLibre,
          ),
        ],

        // Ce qui est retenu, en bas : la réponse en train de se construire.
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in widget.selected)
                _ChosenTag(
                  label: _labelOf(value),
                  onRemove: widget.enabled
                      ? () => widget.onToggle(value)
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// La liste qui se réduit à mesure qu'on tape.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.options,
    required this.libre,
    required this.emptyMessage,
    required this.onChoose,
    required this.onCustom,
  });

  final List<PickerOption> options;
  final String? libre;
  final String emptyMessage;
  final ValueChanged<String> onChoose;
  final ValueChanged<String> onCustom;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty && libre == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      // Quatre lignes et demie : on voit qu'il y en a d'autres sans que la
      // liste reprenne tout l'écran.
      constraints: const BoxConstraints(maxHeight: 232),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (libre != null)
            _Row(
              icon: Icons.add,
              label: 'Ajouter « $libre »',
              highlight: true,
              onTap: () => onCustom(libre!),
            ),
          for (final option in options)
            _Row(
              icon: Icons.north_west,
              label: option.label,
              description: option.description,
              onTap: () => onChoose(option.value),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                    color: highlight
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                if (description != null && description!.isNotEmpty)
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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

/// Une étiquette retenue, avec sa croix.
class _ChosenTag extends StatelessWidget {
  const _ChosenTag({required this.label, required this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Semantics(
              button: true,
              label: 'Retirer $label',
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}
