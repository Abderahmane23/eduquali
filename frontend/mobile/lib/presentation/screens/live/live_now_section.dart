import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/live_models.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../../widgets/marque.dart';

/// « En direct » — la bande en tête de tous les accueils.
///
/// --- Ce que la carte montre, et ce qu'elle ne montre pas ----------------
///
/// Elle annonce une séance en cours : la matière, le professeur, l'heure de
/// début et de fin, et le bouton pour entrer. Elle **ne diffuse pas** le flux
/// vidéo du professeur, et c'est une décision, pas un raccourci :
///
///   * **Le flux est payant.** Le serveur ne délivre un jeton de salle qu'au
///     professeur ou à quelqu'un dont la place est confirmée et réglée
///     (`/live/sessions/:id/token`). Afficher la vidéo dans une carte ouverte à
///     tous donnerait le cours gratuitement à qui ne l'a pas payé.
///   * **La bande passante.** Un accueil qui affiche quatre cartes
///     s'abonnerait à quatre flux vidéo simultanés. Sur une connexion
///     guinéenne, cela consomme le forfait de la journée en quelques minutes et
///     rend l'accueil inutilisable — pour une vignette qu'on regarde une
///     seconde.
///
/// La carte porte donc l'identité du professeur et un repère « EN DIRECT ».
/// Toucher la carte ouvre la salle, où la vidéo est à sa place : en grand, une
/// seule à la fois, et pour quelqu'un qui y a droit.
///
/// Un aperçu public de quelques secondes reste possible — c'est un échantillon
/// commercial, à décider et à doter de son propre jeton restreint, pas un effet
/// de bord d'une carte d'accueil.
class LiveNowSection extends ConsumerStatefulWidget {
  const LiveNowSection({super.key});

  @override
  ConsumerState<LiveNowSection> createState() => _LiveNowSectionState();
}

class _LiveNowSectionState extends ConsumerState<LiveNowSection> {
  List<MySession> _miennes = const [];
  List<LiveSessionSummary> _publiques = const [];
  bool _charge = false;
  Timer? _horloge;

  @override
  void initState() {
    super.initState();
    _charger();
    /*
     * Une séance commence et se termine pendant qu'on regarde l'écran.
     *
     * Sans ce rappel, « Rejoindre » n'apparaît qu'au prochain passage sur
     * l'accueil : quelqu'un qui attend le début de son cours le verrait rester
     * grisé indéfiniment. Une minute suffit — la fenêtre d'entrée dure quinze
     * minutes — et ne coûte rien puisqu'on ne redemande rien au serveur.
     */
    _horloge = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _horloge?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final api = ref.read(liveApiProvider);
    try {
      // Les deux ensemble : sans la liste publique on ne découvre rien, sans la
      // sienne on ne sait pas lesquelles on peut rejoindre.
      final resultats = await Future.wait([
        api.mySessions().catchError((_) => <MySession>[]),
        api.sessions(days: 1).catchError((_) => <LiveSessionSummary>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _miennes = resultats[0] as List<MySession>;
        _publiques = resultats[1] as List<LiveSessionSummary>;
        _charge = true;
      });
    } catch (_) {
      // Sans serveur, la bande disparaît au lieu d'afficher une erreur :
      // l'accueil reste utilisable, et les cours en direct ont de toute façon
      // besoin du réseau.
      if (mounted) setState(() => _charge = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_charge) return const SizedBox.shrink();

    final maintenant = DateTime.now();

    // Les miennes d'abord : on peut y entrer, c'est le geste le plus utile de
    // l'écran.
    final aRejoindre = [
      for (final s in _miennes)
        if (s.isPaid && !s.isOverAt(maintenant) && s.canJoinAt(maintenant)) s,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final dejaPrises = {for (final s in _miennes) s.sessionId};
    final aDecouvrir = [
      for (final s in _publiques)
        if (!dejaPrises.contains(s.id) &&
            s.seatsLeft > 0 &&
            s.startsAt.isBefore(maintenant.add(const Duration(hours: 3))) &&
            s.startsAt
                .add(Duration(minutes: s.durationMinutes))
                .isAfter(maintenant))
          s,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (aRejoindre.isEmpty && aDecouvrir.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: KitCarousel(
        title: 'En direct',
        actionLabel: 'Tout voir',
        onAction: () => context.push(Routes.live),
        children: [
          for (final seance in aRejoindre)
            _CarteDirect(
              matiere: seance.subject?.name ?? seance.title ?? 'Cours',
              professeur: seance.childName,
              debut: seance.startsAt,
              fin: seance.endsAt,
              enDirect: seance.status == 'LIVE',
              action: 'Rejoindre',
              onAction: () => context.push('/live/${seance.sessionId}'),
            ),
          for (final seance in aDecouvrir)
            _CarteDirect(
              matiere: seance.subject?.name ?? seance.title ?? 'Cours',
              professeur: seance.teacherName,
              debut: seance.startsAt,
              fin: seance.startsAt.add(
                Duration(minutes: seance.durationMinutes),
              ),
              enDirect: seance.status == 'LIVE',
              action: 'Réserver',
              places: seance.seatsLeft,
              onAction: () => context.push(Routes.live),
            ),
        ],
      ),
    );
  }
}

/// Une séance, telle qu'on la voit depuis l'accueil.
class _CarteDirect extends StatelessWidget {
  const _CarteDirect({
    required this.matiere,
    required this.debut,
    required this.fin,
    required this.enDirect,
    required this.action,
    required this.onAction,
    this.professeur,
    this.places,
  });

  final String matiere;
  final String? professeur;
  final DateTime debut;
  final DateTime fin;
  final bool enDirect;
  final String action;
  final VoidCallback onAction;
  final int? places;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            /*
             * L'affiche.
             *
             * Un aplat sombre et l'initiale du professeur, là où une vignette
             * vidéo se trouverait. Elle donne à la carte sa présence sans
             * ouvrir un flux : voir l'en-tête de ce fichier.
             */
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Un aplat, pas un degrade.
          color: AppColors.marqueViolette,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: InitialsTile(
                        name: professeur ?? matiere,
                        size: 52,
                      ),
                    ),
                    if (enDirect)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        /*
                         * La pastille de la charte, et non une pastille
                         * dessinee ici.
                         *
                         * Elle etait refaite a la main sur trois ecrans, avec
                         * trois tailles de point et trois graisses de texte.
                         * `rouge` plein n'a qu'un seul emploi autorise — « si
                         * la pastille est a l'ecran, la camera tourne » — et
                         * le tenir en un seul endroit est ce qui empeche le
                         * rouge de devenir decoratif.
                         */
                        child: const EnDirect(),
                      ),
                  ],
                ),
              ),
            ),

            const Gap(AppSpacing.md),
            Text(
              matiere,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (professeur != null) MetaText(professeur!),
            const Gap(AppSpacing.xs),
            // Début ET fin : « ça commence à 14 h » ne dit pas si l'on a le
            // temps d'y assister.
            MetaText('${Fmt.time(debut)} – ${Fmt.time(fin)}'),

            const Gap(AppSpacing.md),
            Row(
              children: [
                if (places != null && places! > 0)
                  StatusPill(
                    label: '$places place${places! > 1 ? 's' : ''}',
                    tone: StatusTone.neutral,
                  ),
                const Spacer(),
                FilledButton(onPressed: onAction, child: Text(action)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
