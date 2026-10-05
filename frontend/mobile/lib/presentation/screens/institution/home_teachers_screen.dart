import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/dashboard.dart';

/// Les professeurs qui donnent des cours à domicile, sur leur propre page
/// (note du 21/09).
///
/// Ils étaient mélangés aux candidats à un poste, alors qu'un établissement
/// ne les cherche pas pour la même raison : un répétiteur vient quelques
/// heures par semaine, un enseignant occupe un poste à l'année. Les
/// confondre faisait passer des profils à côté des deux besoins.
class HomeTeachersScreen extends ConsumerWidget {
  const HomeTeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(allTutoringOffersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Cours à domicile'),
      ),
      body: AsyncGate(
        value: offers,
        placeholder: const SkeletonDashboard(cards: [5]),
        error: (_) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Liste indisponible',
          message: 'Réessayez dans un instant.',
        ),
        data: (items) => ListView(
          padding: AppSpacing.page,
          children: [
            DashboardCard(
              title: 'Répétiteurs disponibles',
              emptyMessage:
                  'Aucun professeur ne propose de cours à domicile pour le '
                  'moment.',
              rows: [
                for (final offer in items)
                  DashboardRow(
                    label: offer.teacherName,
                    columns: [
                      offer.subjectName,
                      Fmt.money(offer.hourlyRate ?? 0),
                    ],
                    onTap: () => context.push('/teachers/${offer.teacherId}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
