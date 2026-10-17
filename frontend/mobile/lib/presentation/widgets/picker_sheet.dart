import 'package:flutter/material.dart';

import '../../core/utils/text_search.dart';
import '../theme/app_theme.dart';

/// Une entrée du sélecteur.
class PickerOption {
  const PickerOption({
    required this.value,
    required this.label,
    this.description,
  });

  final String value;
  final String label;

  /// Ligne d'explication sous le libellé — « Préfecture récente ».
  final String? description;
}

/// Choisir dans une longue liste, avec une recherche.
///
/// Remplace le menu flottant de `DropdownButtonFormField`. Celui-ci recouvrait
/// l'écran, n'avait pas de recherche, et devenait inutilisable dès qu'une
/// liste dépassait une dizaine d'entrées : les préfectures en comptent 57, et
/// la base des établissements de Conakry en comptera des centaines.
///
/// La feuille s'ouvre en bas, à portée du pouce, et garde le contexte visible
/// au-dessus — on voit toujours la question à laquelle on répond.
Future<String?> showPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerOption> options,
  String? selected,

  /// En dessous de ce nombre, la recherche encombre plus qu'elle n'aide.
  int searchFrom = 8,

  /// Permet de saisir une valeur absente de la liste.
  ///
  /// Le referentiel des etablissements ne contient pas toutes les ecoles de
  /// Guinee et n'y parviendra jamais : sans cette porte, un parent dont
  /// l'ecole manque ne peut pas finir son inscription.
  bool allowCustom = false,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PickerSheet(
    title: title,
    options: options,
    selected: selected,
    searchFrom: searchFrom,
    allowCustom: allowCustom,
  ),
);

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchFrom,
    required this.allowCustom,
  });

  final String title;
  final List<PickerOption> options;
  final String? selected;
  final int searchFrom;
  final bool allowCustom;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Ce que l'on vient de taper, s'il ne figure pas deja dans la liste.
  ///
  /// Nul quand le champ est vide ou quand une option porte exactement ce
  /// nom : proposer « Ajouter Lycee Donka » sous « Lycee Donka » creerait un
  /// doublon d'un simple appui de travers.
  String? get _libre {
    final saisi = _query.text.trim();
    if (saisi.isEmpty) return null;
    final existe = widget.options.any(
      (o) => foldText(o.label) == foldText(saisi),
    );
    return existe ? null : saisi;
  }

  List<PickerOption> get _shown {
    final q = foldText(_query.text.trim());
    if (q.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if (foldText(option.label).contains(q) ||
            foldText(option.description ?? '').contains(q))
          option,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final withSearch =
        widget.allowCustom || widget.options.length >= widget.searchFrom;
    final shown = _shown;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          // La feuille ne monte jamais jusqu'en haut : voir ce qu'elle
          // recouvre rappelle à quelle question on répond.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.md),
                child: Text(widget.title, style: text.titleLarge),
              ),

              if (withSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.sm),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(_query.clear),
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Effacer',
                            ),
                      isDense: true,
                    ),
                  ),
                ),

              // Ajouter ce qu'on vient de taper, quand la liste ne le
              // contient pas. Propose avant la liste et non apres : c'est la
              // reponse a « je ne trouve pas la mienne », et la chercher au
              // fond d'une liste de deux cents ecoles serait absurde.
              if (widget.allowCustom && _libre != null)
                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Ajouter « $_libre »',
                    style: text.titleSmall?.copyWith(color: AppColors.primary),
                  ),
                  onTap: () => Navigator.pop(context, _libre),
                ),

              if (shown.isEmpty && _libre == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, AppSpacing.lg, 20, 32),
                  child: Text(
                    widget.allowCustom
                        ? 'Tapez le nom pour l’ajouter.'
                        : 'Aucun résultat pour « ${_query.text.trim()} ».',
                    style: text.bodyMedium,
                  ),
                )
              else if (shown.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final option = shown[i];
                      final isSelected = option.value == widget.selected;
                      return ListTile(
                        title: Text(
                          option.label,
                          style: isSelected
                              ? text.titleSmall?.copyWith(
                                  color: AppColors.primary,
                                )
                              : text.titleSmall,
                        ),
                        subtitle: option.description == null
                            ? null
                            : Text(option.description!),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 20,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, option.value),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un champ qui ouvre le sélecteur au lieu d'un menu flottant.
///
/// Il ressemble à un champ de formulaire pour ne pas dérouter : c'est bien
/// une valeur qu'on saisit, pas une page qu'on ouvre.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.allowCustom = false,
  });

  final String label;
  final List<PickerOption> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? helperText;
  final String? errorText;
  final bool enabled;

  /// Permet de saisir une valeur absente de la liste.
  final bool allowCustom;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chosen = options.where((o) => o.value == value).firstOrNull;
    // Une valeur saisie librement n'a pas d'option correspondante : sans
    // cela, le champ resterait vide apres l'avoir ajoutee.
    final affiche = chosen?.label ?? (allowCustom ? value : null);

    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showPickerSheet(
                context: context,
                title: label,
                options: options,
                selected: value,
                allowCustom: allowCustom,
              );
              if (picked != null) onChanged(picked);
            }
          : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        isEmpty: affiche == null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText ?? chosen?.description,
          errorText: errorText,
          enabled: enabled,
          suffixIcon: Icon(
            Icons.expand_more,
            size: 20,
            color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
        child: affiche == null ? null : Text(affiche, style: text.bodyLarge),
      ),
    );
  }
}
