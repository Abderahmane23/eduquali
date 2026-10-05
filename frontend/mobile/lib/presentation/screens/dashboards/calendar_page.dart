import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/tutoring_sessions_repository.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';

/// Le calendrier, d'après la maquette du 21/09.
///
/// Les jours en haut, la prochaine séance dessous, puis ce qu'on peut en
/// faire : voir, changer, résilier. Professeur et parent voient le même
/// agenda — c'est le même rendez-vous, et deux versions finiraient par ne
/// plus dire la même heure.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// Le jour mis en avant. Nul = toute la semaine.
  Weekday? _day;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentSessionProvider)?.role;
    // `followsAStudent` et non `== parent` : un etudiant majeur suit ses
    // propres cours. Compare au seul role parent, il recevait l'agenda d'un
    // professeur — donc un calendrier vide, sans explication.
    final suitUnEleve = role?.followsAStudent ?? false;
    final sessions = ref.watch(
      suitUnEleve ? parentSessionsProvider : teacherSessionsProvider,
    );

    return AsyncGate(
      value: sessions,
      placeholder: const SkeletonCalendar(),
      error: (_) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Calendrier indisponible',
        message: 'Réessayez dans un instant.',
      ),
      data: (all) {
        final now = DateTime.now();
        final upcoming = [
          for (final s in all)
            if (!s.isCancelled && s.startsAt.isAfter(now)) s,
        ];
        // Les jours où il se passe quelque chose : proposer un jour vide
        // ferait cliquer pour rien.
        final busyDays = {
          for (final s in upcoming) Weekday.values[s.startsAt.weekday - 1],
        };
        final shown = _day == null
            ? upcoming
            : [
                for (final s in upcoming)
                  if (s.startsAt.weekday == _day!.index + 1) s,
              ];

        // Les jours ou il se passe quelque chose, dans l'ordre de la
        // semaine. « Tout » d'abord.
        final jours = [
          for (final day in Weekday.values)
            if (busyDays.contains(day)) day,
        ];

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHero(
              title: 'Calendrier',
              subtitle: upcoming.isEmpty
                  ? 'Aucune séance programmée'
                  : upcoming.length == 1
                  ? '1 séance à venir'
                  : '${upcoming.length} séances à venir',
            ),

            if (jours.isNotEmpty) ...[
              const Gap(AppSpacing.lg),
              FilterChipsRow(
                selected: _day == null ? 0 : jours.indexOf(_day!) + 1,
                onSelected: (i) =>
                    setState(() => _day = i == 0 ? null : jours[i - 1]),
                items: [
                  (label: 'Tout', icon: null),
                  for (final day in jours) (label: day.label, icon: null),
                ],
              ),
            ],
            const Gap(AppSpacing.xl),

            // --- La prochaine ----------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: const KitSectionTitle(title: 'Prochaine séance'),
            ),
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
                  if (shown.isEmpty)
                    const KitEmpty(
                      icon: Icons.event_busy_outlined,
                      message:
                          'Aucune séance programmée. Elles apparaissent dès '
                          'qu’un professeur accepte une demande.',
                    )
                  else
                    _NextSession(item: shown.first, role: role),

                  if (shown.length > 1) ...[
                    const Gap(AppSpacing.xl),
                    const KitSectionTitle(title: 'Ensuite'),
                    for (final s in shown.skip(1).take(8))
                      ListItemCard(
                        leading: const IconTile(
                          icon: Icons.event_outlined,
                          size: 46,
                        ),
                        title: s.subjectName,
                        subtitle: suitUnEleve
                            ? s.teacherName
                            : (s.childName ?? s.teacherName),
                        meta: [
                          MetaText(
                            Fmt.dateShort(s.startsAt),
                            icon: Icons.calendar_today_outlined,
                          ),
                          MetaText(Fmt.time(s.startsAt)),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// La séance mise en avant, avec ses trois actions.
class _NextSession extends ConsumerWidget {
  const _NextSession({required this.item, required this.role});

  final TutoringSessionItem item;
  final UserRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final fin = item.startsAt.add(
      Duration(minutes: item.session.durationMinutes),
    );
    // Le professeur voit l'élève ; la famille voit le professeur.
    final other = (role?.followsAStudent ?? false)
        ? item.teacherName
        : (item.childName ?? item.teacherName);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$other · ${item.subjectName}', style: text.titleMedium),
          const SizedBox(height: 3),
          Text(
            '${Fmt.date(item.startsAt)} · '
            '${Fmt.time(item.startsAt)} – ${Fmt.time(fin)}',
            style: text.bodyMedium,
          ),
          const Gap(AppSpacing.md),
          const Divider(height: 1),
          Row(
            children: [
              // « Voir » a ete retire : la boite qu'il ouvrait repetait ce
              // que la carte affiche deja, au prix d'une etape.
              Expanded(
                child: TextButton(
                  onPressed: () => _reschedule(context),
                  child: const Text('Changer'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _cancel(context, ref),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _reschedule(BuildContext context) {
    // Déplacer une séance engage l'autre partie : tant que la demande ne lui
    // parvient pas, annoncer que c'est fait serait un mensonge.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Le changement d’horaire demande l’accord de l’autre partie. '
          'Bientôt disponible.',
        ),
      ),
    );
  }

  /// Annuler, sans demander deux fois.
  ///
  /// La boite « Etes-vous sur ? » posait la question au mauvais moment : avant
  /// que la seance ait disparu de l'agenda, donc avant qu'on voie ce qu'on
  /// perd. Elle part maintenant tout de suite, et cinq secondes suffisent a la
  /// remettre. « Retablir » et non « Annuler » : ici, annuler est justement ce
  /// qu'on vient de faire.
  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(tutoringSessionsRepositoryProvider);
    final before = await repo.cancel(item.session.id);
    refreshTutoring(ref);
    if (!context.mounted || before == null) return;

    showUndo(
      context,
      message: 'Séance du ${Fmt.dateShort(item.startsAt)} annulée.',
      label: 'Rétablir',
      onUndo: () async {
        await repo.restore(item.session.id, before);
        refreshTutoring(ref);
      },
    );
  }
}
