import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/live_models.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// « Fatoumata suit Mathématiques — en direct depuis 23 min ».
///
/// --- Pourquoi ce bandeau existe ------------------------------------------
///
/// C'est la fonction qui justifie l'abonnement d'un parent. Il ne demande pas un
/// tableau de bord : il demande, à 18 h 20, si son enfant est bien en cours. Une
/// phrase à laquelle il répond d'un regard vaut mieux qu'un écran de
/// statistiques qu'il n'ouvrira pas.
///
/// --- La limite, tenue ici comme dans le schéma ---------------------------
///
/// **Jamais la caméra de l'enfant.** C'est une présence, pas une surveillance
/// vidéo. Le serveur ne rend aucune image — `/live/presence` ne renvoie qu'un
/// prénom, une matière et des minutes — et ce composant n'en demande aucune. Un
/// parent qui pourrait regarder son enfant pendant le cours changerait la nature
/// de ce qu'on vend, et les adolescents cesseraient de lever la main.
///
/// --- Pourquoi un sondage et non du temps réel ----------------------------
///
/// Une connexion permanente pour une information qui change toutes les quelques
/// minutes coûte plus sur une ligne payée au mégaoctet, et ne se reprend pas
/// toute seule après une coupure. Trente secondes suffisent, et la minuterie
/// s'arrête quand l'écran disparaît.
class LivePresenceStrip extends ConsumerStatefulWidget {
  const LivePresenceStrip({super.key});

  @override
  ConsumerState<LivePresenceStrip> createState() => _LivePresenceStripState();
}

const Duration _intervalle = Duration(seconds: 30);

class _LivePresenceStripState extends ConsumerState<LivePresenceStrip> {
  List<LivePresence> _presences = const [];
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _relire();
    _minuterie = Timer.periodic(_intervalle, (_) => _relire());
  }

  @override
  void dispose() {
    // Une minuterie laissée en vie continue d'appeler le serveur après le
    // démontage, et consomme des données sur un écran que personne ne regarde.
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _relire() async {
    try {
      final presences = await ref.read(liveApiProvider).presence();
      if (!mounted) return;
      setState(() => _presences = presences);
    } catch (_) {
      // Silence volontaire. Ce bandeau est un supplément : un compte
      // enseignant, un serveur absent ou une coupure réseau le font échouer, et
      // aucune de ces situations ne mérite un message d'erreur en tête du
      // tableau de bord. L'absence d'information est l'affichage correct.
      if (!mounted) return;
      setState(() => _presences = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_presences.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (final presence in _presences)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InfoBanner(
                // Un ton d'information et non d'alerte : c'est une bonne
                // nouvelle. Un bandeau orange à chaque cours ferait croire à un
                // problème.
                tone: StatusTone.info,
                icon: Icons.sensors,
                message:
                    '${presence.childName ?? 'Votre place'} suit '
                    '${presence.subjectName ?? presence.courseTitle ?? 'un cours'}'
                    ' — ${_duree(presence.minutes)}',
                actionLabel: 'Voir la séance',
                onAction: () => context.push('/direct'),
              ),
            ),
        ],
      ),
    );
  }
}

/// « en direct depuis 23 min », « en direct depuis 1 h 05 ».
///
/// Les minutes viennent du serveur et non de l'horloge du téléphone : celle d'un
/// appareil guinéen n'est pas toujours juste, et c'est le chiffre sur lequel un
/// parent juge si l'abonnement sert à quelque chose.
String _duree(int minutes) {
  if (minutes < 1) return 'vient d’entrer';
  if (minutes < 60) return 'en direct depuis $minutes min';
  final heures = minutes ~/ 60;
  final reste = minutes % 60;
  return 'en direct depuis $heures h ${reste.toString().padLeft(2, '0')}';
}

/// « Temps de cours cette semaine ».
///
/// Le chiffre qui dit à un parent si l'abonnement sert. Il ne demande pas un
/// graphique : il demande si son enfant travaille.
///
/// Rien ne s'affiche tant qu'il n'y a rien à montrer — une semaine à zéro sur le
/// tableau de bord d'une famille qui vient de s'inscrire se lit comme un
/// reproche.
/// L'objectif hebdomadaire, en minutes : une séance de 90 minutes.
///
/// Volontairement atteignable. Un objectif qu'on n'atteint jamais cesse d'être
/// un objectif et devient un reproche, et on arrête de regarder l'écran qui le
/// porte — l'inverse exact de ce qu'un compteur de progression doit produire.
const int objectifHebdoMinutes = 90;

class WeeklyStudyCard extends ConsumerStatefulWidget {
  const WeeklyStudyCard({super.key});

  @override
  ConsumerState<WeeklyStudyCard> createState() => _WeeklyStudyCardState();
}

class _WeeklyStudyCardState extends ConsumerState<WeeklyStudyCard> {
  StudySummary _resume = StudySummary.vide;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final resume = await ref.read(liveApiProvider).studyMinutes();
      if (!mounted) return;
      setState(() => _resume = resume);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resume = StudySummary.vide);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resume.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cette semaine', style: theme.textTheme.labelLarge),
                      const Gap(AppSpacing.xs),
                      Text(
                        dureeLongue(_resume.totalMinutes),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'de cours en direct, sur ${_resume.sessions} '
                        'séance${_resume.sessions > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                /*
                 * L'anneau hebdomadaire.
                 *
                 * Un nombre de minutes ne dit pas si l'on progresse ; un
                 * anneau qui se remplit le dit d'un coup d'œil. L'objectif est
                 * **une séance par semaine**, pas un quota ambitieux : il doit
                 * se boucler, sinon l'anneau reste un reproche permanent.
                 *
                 * Une seule couleur, celle du thème, et pas de rouge quand
                 * c'est incomplet — l'écran rend compte, il ne gronde pas.
                 */
                const Gap(AppSpacing.md),
                ProgressRing(
                  value: (_resume.totalMinutes / objectifHebdoMinutes).clamp(
                    0.0,
                    1.0,
                  ),
                  size: 62,
                  child: Text(
                    '${((_resume.totalMinutes / objectifHebdoMinutes) * 100).clamp(0, 100).round()} %',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            // Par enfant d'abord : c'est la question posée. Une seule ligne ne
            // s'affiche pas — elle répéterait le total juste au-dessus.
            if (_resume.perChild.length > 1) ...[
              const Gap(AppSpacing.md),
              for (final ligne in _resume.perChild)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ligne.label,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        dureeLongue(ligne.minutes),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            if (_resume.perSubject.isNotEmpty) ...[
              const Gap(AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final ligne in _resume.perSubject)
                    TagChip(
                      label: '${ligne.label} · ${dureeLongue(ligne.minutes)}',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// « 45 min », « 3 h 30 ».
@visibleForTesting
String dureeLongue(int minutes) {
  if (minutes < 60) return '$minutes min';
  final heures = minutes ~/ 60;
  final reste = minutes % 60;
  return reste == 0
      ? '$heures h'
      : '$heures h ${reste.toString().padLeft(2, '0')}';
}
