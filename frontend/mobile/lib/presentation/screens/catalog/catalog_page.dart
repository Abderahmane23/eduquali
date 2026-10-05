import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/video_courses_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Le catalogue de cours vidéo, d'après la maquette du 23/09.
///
/// Le même écran des deux côtés : le professeur y voit son atelier et ce
/// qu'il a gagné, la famille y voit ce qu'elle peut acheter. Deux écrans
/// auraient fini par ne plus afficher le même prix.
///
/// La maquette montrait des vignettes, des notes et des durées. Rien de tout
/// cela n'existe encore dans le modèle ; plutôt que d'inventer des étoiles,
/// chaque carte porte ce qu'on sait vraiment : la matière, le nombre de
/// vidéos, le prix, et — côté professeur — le nombre de ventes.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _search = TextEditingController();
  String _query = '';
  String? _subject;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(VideoCourseItem course) {
    if (_subject != null && course.subjectName != _subject) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return course.title.toLowerCase().contains(q) ||
        (course.subjectName ?? '').toLowerCase().contains(q) ||
        course.teacherName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final teacher = ref.watch(currentSessionProvider)?.role == UserRole.teacher;
    // Côté famille, le catalogue arrive classé : la classe et les matières
    // déclarées à l'inscription remontent ce qui correspond. Un tri, pas un
    // filtre — un cours d'une autre classe sert à réviser l'année passée, et
    // une liste qui rétrécit en silence fait croire qu'il n'y a que trois
    // cours. L'atelier du professeur garde son propre ordre.
    final catalog = teacher
        ? ref.watch(teacherVideoCoursesProvider)
        : ref.watch(sortedCatalogProvider);

    return RefreshIndicator(
      onRefresh: () async => refreshVideoCourses(ref),
      child: AsyncGate(
        value: catalog,
        placeholder: const SkeletonDashboard(cards: [2, 4]),
        error: (_) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Catalogue indisponible',
          message: 'Réessayez dans un instant.',
        ),
        data: (all) {
          // Les matières présentes, et elles seules : une puce « Chimie »
          // sans un seul cours de chimie ne mène qu'à une page vide.
          final subjects = <String>{
            for (final c in all)
              if (c.subjectName != null) c.subjectName!,
          }.toList()..sort();

          final shown = [
            for (final c in all)
              if (_matches(c)) c,
          ];
          final mine = [
            for (final c in shown)
              if (c.purchased) c,
          ];
          final rest = [
            for (final c in shown)
              if (!c.purchased) c,
          ];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              GradientHero(
                title: 'Catalogue',
                subtitle: teacher
                    ? 'Vos cours vidéo en vente'
                    : 'Cours vidéo par nos professeurs',
                actions: [
                  if (teacher)
                    HeroPillButton(
                      icon: Icons.add,
                      label: 'Créer',
                      onPressed: () => context.push(Routes.courseNew),
                    ),
                ],
                search: HeroSearchField(
                  hint: 'Rechercher un cours…',
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),

              if (subjects.isNotEmpty) ...[
                const Gap(AppSpacing.lg),
                FilterChipsRow(
                  selected: _subject == null
                      ? 0
                      : subjects.indexOf(_subject!) + 1,
                  onSelected: (i) => setState(
                    () => _subject = i == 0 ? null : subjects[i - 1],
                  ),
                  items: [
                    (label: 'Tous', icon: null),
                    for (final s in subjects) (label: s, icon: null),
                  ],
                ),
              ],
              const Gap(AppSpacing.xl),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (teacher) ...[
                      PromoCard(
                        icon: Icons.videocam_outlined,
                        title: 'Créer un cours',
                        subtitle:
                            'Une vidéo se vend une fois et se regarde autant '
                            'de fois qu’on veut',
                        onTap: () => context.push(Routes.courseNew),
                      ),
                      _Earnings(),
                    ],

                    if (!teacher && mine.isNotEmpty) ...[
                      const KitSectionTitle(title: 'Mes cours'),
                      for (final course in mine)
                        _CourseCard(
                          course: course,
                          owned: true,
                          onTap: () => _watch(course),
                        ),
                      const Gap(AppSpacing.lg),
                    ],

                    KitSectionTitle(
                      title: teacher ? 'Mes cours' : 'Cours disponibles',
                    ),
                    if (all.isEmpty)
                      KitEmpty(
                        icon: Icons.play_circle_outline,
                        message: teacher
                            ? 'Aucun cours en vente. Une vidéo atteint un '
                                  'élève de Nzérékoré sans bouger de Conakry.'
                            : 'Aucun cours en vente pour le moment. Les '
                                  'professeurs en publient régulièrement.',
                        actionLabel: teacher ? 'Créer un cours' : null,
                        onAction: teacher
                            ? () => context.push(Routes.courseNew)
                            : null,
                      )
                    else if (rest.isEmpty)
                      KitEmpty(
                        icon: Icons.search_off,
                        message: 'Rien ne correspond à cette recherche.',
                        actionLabel: 'Tout afficher',
                        onAction: () => setState(() {
                          _subject = null;
                          _query = '';
                          _search.clear();
                        }),
                      )
                    else
                      for (final course in rest)
                        _CourseCard(
                          course: course,
                          owned: false,
                          teacherSide: teacher,
                          onTap: () => teacher ? _manage(course) : _buy(course),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Ouvre le lecteur.
  ///
  /// L'ecran repondait « la lecture arrive bientot » : un cours achete ne se
  /// regardait pas. Elle est branchee depuis le 02/10.
  void _watch(VideoCourseItem course) =>
      context.push(Routes.coursePlayer(course.id));

  Future<void> _manage(VideoCourseItem course) async {
    final enVente = course.status == VideoCourseStatus.published;
    final retirer = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(course.title),
        content: Text(
          '${Fmt.money(course.price)} — il vous revient '
          '${Fmt.money(course.net)}.\n'
          '${course.videos.length} vidéo'
          '${course.videos.length > 1 ? "s" : ""}, '
          '${course.row.purchaseCount} vente'
          '${course.row.purchaseCount > 1 ? "s" : ""}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Fermer'),
          ),
          // Regarder son propre cours est la seule facon de verifier qu'il se
          // lit comme chez l'eleve.
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              _watch(course);
            },
            child: const Text('Voir le cours'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(enVente ? 'Retirer de la vente' : 'Remettre en vente'),
          ),
        ],
      ),
    );
    if (retirer != true) return;

    await ref
        .read(videoCoursesRepositoryProvider)
        .setStatus(
          course.id,
          enVente ? VideoCourseStatus.hidden : VideoCourseStatus.published,
        );
    refreshVideoCourses(ref);
  }

  Future<void> _buy(VideoCourseItem course) async {
    final parentId = ref.read(currentSessionProvider)?.parentId;
    if (parentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(course.title),
        content: Text(
          'Par ${course.teacherName}\n'
          '${course.videos.length} vidéo'
          '${course.videos.length > 1 ? "s" : ""}\n\n'
          '${Fmt.money(course.price)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Acheter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(videoCoursesRepositoryProvider)
          .purchase(courseId: course.id, parentId: parentId);
      refreshVideoCourses(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cours ajouté à vos cours.')),
      );
    } on VideoCourseException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Ce que le professeur a encaissé sur ses ventes.
class _Earnings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(teacherVideoEarningsProvider).valueOrNull ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: KitCard(
        child: Row(
          children: [
            const IconTile(
              icon: Icons.savings_outlined,
              tone: StatusTone.success,
              size: 46,
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'Total encaissé sur les ventes',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ),
            MoneyText(Fmt.money(earnings), tone: StatusTone.success),
          ],
        ),
      ),
    );
  }
}

/// Un cours dans la liste.
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.owned,
    required this.onTap,
    this.teacherSide = false,
  });

  final VideoCourseItem course;
  final bool owned;
  final bool teacherSide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gratuit = course.price == 0;
    final retire = course.status != VideoCourseStatus.published;

    return ListItemCard(
      onTap: onTap,
      leading: const IconTile(icon: Icons.play_arrow_rounded, size: 52),
      title: course.title,
      subtitle: teacherSide ? null : course.teacherName,
      chips: [
        if (course.subjectName != null)
          TagChip(label: course.subjectName!, tone: StatusTone.primary),
        if (owned) const TagChip(label: 'Acheté', tone: StatusTone.success),
        if (teacherSide && retire)
          const TagChip(label: 'Retiré de la vente', tone: StatusTone.neutral),
      ],
      meta: [
        MetaText(
          '${course.videos.length} vidéo'
          '${course.videos.length > 1 ? "s" : ""}',
          icon: Icons.play_circle_outline,
        ),
        if (teacherSide)
          MetaText(
            '${course.row.purchaseCount} vendu'
            '${course.row.purchaseCount > 1 ? "s" : ""}',
          ),
        if (owned)
          const MetaText('Vous l’avez')
        else if (gratuit)
          const MoneyText('Gratuit', tone: StatusTone.success)
        else
          MoneyText(Fmt.money(course.price)),
      ],
    );
  }
}
