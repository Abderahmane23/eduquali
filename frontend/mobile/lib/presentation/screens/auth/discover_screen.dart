import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/teacher_profile.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Les résultats de la recherche, avant tout compte.
///
/// C'est la promesse de l'écran d'accueil : on regarde d'abord. La liste
/// montre ce qu'un professeur publie de lui-même — nom, matières, ville,
/// expérience. Les coordonnées restent masquées, exactement comme pour un
/// établissement qui n'a pas encore recruté (§30).
///
/// Le compte n'est demandé qu'au moment de contacter quelqu'un, parce que
/// c'est le premier geste qui engage une autre personne.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key, required this.query, this.home = true});

  final String query;

  /// Vrai : des répétiteurs qui se déplacent. Faux : des professeurs
  /// disponibles pour un poste.
  final bool home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = ref.watch(availableTeachersProvider(null));
    final connecte = ref.watch(currentSessionProvider) != null;
    // Côté cours à domicile, seuls les professeurs qui ont publié une offre
    // se déplacent. Les autres sont disponibles pour un poste, ce qui n'est
    // pas la même chose — et une famille qui les contacte se fait refuser.
    final offres = ref.watch(allTutoringOffersProvider).valueOrNull ?? const [];
    final aDomicile = {for (final o in offres) o.teacherId};

    // Le texte cherché vise une matière ou une ville. On ne devine pas :
    // on regarde dans les deux, et on le dit dans le libellé du résultat.
    final q = query.trim().toLowerCase();

    return Scaffold(
      body: AsyncGate(
        value: teachers,
        placeholder: const SkeletonDashboard(cards: [1, 4]),
        error: (_) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Recherche indisponible',
          message: 'Réessayez dans un instant.',
        ),
        data: (all) {
          String subjectNames(TeacherProfile p) =>
              p.capabilities.map((c) => c.subject.name).join(' · ');

          final dansLeMode = home
              ? [
                  for (final t in all)
                    if (aDomicile.contains(t.profile.teacherId)) t,
                ]
              : all;

          final shown = q.isEmpty
              ? dansLeMode
              : [
                  for (final t in dansLeMode)
                    if (t.profile.fullName.toLowerCase().contains(q) ||
                        (t.profile.city ?? '').toLowerCase().contains(q) ||
                        subjectNames(t.profile).toLowerCase().contains(q))
                      t,
                ];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              GradientHero(
                onBack: () => Navigator.of(context).maybePop(),
                title: query.isEmpty
                    ? (home ? 'Cours à domicile' : 'Professeurs à recruter')
                    : query,
                subtitle: shown.length == 1
                    ? '1 professeur disponible'
                    : '${shown.length} professeurs disponibles',
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shown.isEmpty)
                      KitEmpty(
                        icon: Icons.search_off,
                        message: q.isEmpty
                            ? 'Aucun professeur disponible pour le moment.'
                            : 'Aucun professeur ne correspond à « $query ». '
                                  'Essayez une autre matière ou une autre '
                                  'ville.',
                        actionLabel: 'Voir tous les professeurs',
                        onAction: () =>
                            context.pushReplacement(Routes.discoverFor('')),
                      )
                    else
                      for (final teacher in shown)
                        PersonRow(
                          name: teacher.profile.fullName,
                          photoPath: teacher.profile.photoPath,
                          subtitle: subjectNames(teacher.profile),
                          chips: [
                            if (teacher.profile.city != null)
                              TagChip(
                                label: teacher.profile.city!,
                                icon: Icons.place_outlined,
                                tone: StatusTone.neutral,
                              ),
                            if (teacher.profile.yearsExperience > 0)
                              TagChip(
                                label:
                                    '${teacher.profile.yearsExperience} ans '
                                    'd’expérience',
                                tone: StatusTone.primary,
                              ),
                          ],
                          onTap: () => _open(
                            context,
                            teacher.profile.teacherId,
                            connecte: connecte,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // Le compte n'est reclamé qu'ici, et on dit pourquoi.
      bottomNavigationBar: connecte
          ? null
          : StickyActionBar(
              label: 'CRÉER MON COMPTE',
              note: 'Nécessaire pour contacter un professeur',
              secondaryLabel: 'Connexion',
              onSecondary: () => context.push(Routes.login),
              onPressed: () => context.push(Routes.signup),
            ),
    );
  }

  void _open(BuildContext context, String teacherId, {required bool connecte}) {
    if (connecte) {
      context.push('/teachers/$teacherId');
      return;
    }
    // Ouvrir la fiche complète reviendrait à donner accès à ce que le compte
    // protège. On le dit plutôt que de laisser un appui sans effet.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Créez un compte pour voir la fiche complète et contacter ce '
          'professeur.',
        ),
      ),
    );
  }
}
