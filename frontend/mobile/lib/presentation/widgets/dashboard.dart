import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// Les briques des trois tableaux de bord, dessinées d'après la maquette
/// du 21/09.
///
/// Un tableau de bord y tient en trois formes et rien d'autre : une **carte
/// titrée** qui contient un **tableau**, et des **actions en texte**. Toute
/// autre forme ajoutée ici se retrouverait sur les trois espaces, et c'est
/// précisément l'encombrement qu'on vient de retirer.

/// Une carte titrée, contenant un tableau et sa ligne d'ajout.
///
/// ```
/// ┌ Mes contrats ─────────────┐
/// │ Lycée Excellence        → │
/// │ Aïcha                   → │
/// │        ajouter            │
/// └───────────────────────────┘
/// ```
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.rows,
    this.addLabel,
    this.onAdd,
    this.emptyMessage,
  });

  final String title;
  final List<Widget> rows;

  /// L'action d'ajout, en texte et pleine largeur — la maquette la place
  /// sous le tableau, pas en bouton flottant.
  final String? addLabel;
  final VoidCallback? onAdd;

  /// Ce qu'on lit quand le tableau est vide. Une carte vide sans phrase
  /// laisse croire à un écran cassé.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const Gap(AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (rows.isEmpty && emptyMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(emptyMessage!, style: text.bodySmall),
                  )
                else
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    rows[i],
                  ],
                if (onAdd != null) ...[
                  const Divider(height: 1),
                  InkWell(
                    onTap: onAdd,
                    child: SizedBox(
                      width: double.infinity,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppSpacing.touchTarget,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          addLabel ?? 'ajouter',
                          textAlign: TextAlign.center,
                          style: text.titleSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de tableau : un libellé, des colonnes, un chevron.
///
/// ```
/// │ Seydou   Maths              → │
/// ```
class DashboardRow extends StatelessWidget {
  const DashboardRow({
    super.key,
    required this.label,
    this.columns = const [],
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String label;

  /// Les colonnes de droite, dans l'ordre de la maquette.
  final List<String> columns;

  /// La coche « démarré » ou l'ondulation « en attente ».
  final Widget? leading;

  /// Remplace le chevron : une pastille d'état, par exemple.
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final column in columns)
              Expanded(
                flex: 3,
                child: Text(
                  column,
                  style: text.bodySmall,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            trailing ??
                (onTap == null
                    ? const SizedBox(width: 18)
                    : const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textTertiary,
                      )),
          ],
        ),
      ),
    );
  }
}

/// Une action rapide : du texte et une flèche, sans cadre.
///
/// La maquette les écrit à la suite, sous un titre. Les habiller en boutons
/// leur donnerait le même poids visuel que les cartes, alors qu'elles sont
/// secondaires.
class DashboardAction extends StatelessWidget {
  const DashboardAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(
              Icons.arrow_forward,
              size: AppSpacing.lg,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un groupe d'actions rapides, sous son titre.
class DashboardActions extends StatelessWidget {
  const DashboardActions({super.key, required this.title, required this.items});

  final String title;
  final List<({String label, VoidCallback onTap})> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const Gap(AppSpacing.xs),
      for (final item in items)
        DashboardAction(label: item.label, onTap: item.onTap),
    ],
  );
}

/// La coche verte d'un contrat démarré, l'ondulation d'un contrat en attente.
class ContractMark extends StatelessWidget {
  const ContractMark({super.key, required this.started});

  final bool started;

  @override
  Widget build(BuildContext context) => Icon(
    started ? Icons.check : Icons.more_horiz,
    size: 17,
    color: started ? AppColors.success : AppColors.warning,
  );
}

/// Une rangée de tuiles.
///
/// Deux, parfois trois. Au-delà, plus rien ne ressort — et c'est justement
/// ce qu'on cherchait à obtenir en les mettant là.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    // `IntrinsicHeight` mesure la plus haute des deux tuiles et donne cette
    // hauteur-la aux deux.
    //
    // Sans lui, `stretch` imposait aux tuiles la hauteur disponible — infinie
    // dans une liste. Elles etaient dessinees hors de l'ecran en gardant leur
    // zone de clic : le tableau de bord paraissait vide, debordait, et un
    // doigt pose dans le vide ouvrait « Paiements ».
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    ),
  );
}
