import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kit.dart';

/// Une semaine de revenus, deux sources empilées par jour.
///
/// Dessiné à la main plutôt qu'avec une bibliothèque : sept barres de deux
/// segments ne valent pas les quelques mégaoctets d'un moteur de graphiques
/// dans un APK qui circule par Bluetooth.
///
/// Deux séries seulement, et chacune porte son nom dans la légende : la
/// couleur ne dit jamais seule de quoi il s'agit. Pas d'axe des ordonnées —
/// c'est la forme de la semaine qu'on lit ici, pas une valeur exacte ; celui
/// qui veut le chiffre ouvre la liste des paiements.
class WeeklyIncomeChart extends StatelessWidget {
  const WeeklyIncomeChart({
    super.key,
    required this.title,
    required this.days,
    required this.firstLabel,
    required this.secondLabel,
  });

  final String title;

  /// Sept jours, dans l'ordre, les jours vides compris.
  final List<({String label, int first, int second})> days;

  final String firstLabel;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    final plafond = days.fold<int>(
      0,
      (max, d) => (d.first + d.second) > max ? d.first + d.second : max,
    );

    return KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _Legend(color: AppColors.primary, label: firstLabel),
              const SizedBox(width: AppSpacing.md),
              _Legend(color: AppColors.success, label: secondLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (plafond == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'Rien d’encaissé cette semaine.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: _Bar(
                        label: day.label,
                        first: day.first,
                        second: day.second,
                        ceiling: plafond,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs + 1),
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.first,
    required this.second,
    required this.ceiling,
  });

  final String label;
  final int first;
  final int second;
  final int ceiling;

  /// Hauteur utile de la colonne, le libellé du jour déduit.
  static const double _height = 100;

  /// Un segment non nul garde au moins deux pixels : sinon une journée à
  /// 5 000 GNF paraît identique à une journée sans rien.
  double _part(int value) =>
      value == 0 ? 0 : (value / ceiling * _height).clamp(2.0, _height);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            if (second > 0)
              Container(
                height: _part(second),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            // Deux pixels de fond entre les deux segments : sans cela, le
            // violet et le vert se touchent et la limite se devine mal.
            if (second > 0 && first > 0) const SizedBox(height: 2),
            if (first > 0)
              Container(
                height: _part(first),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(second > 0 ? 0 : 4),
                  ),
                ),
              ),
            if (first == 0 && second == 0)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    ],
  );
}
