import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/scheduling/slots.dart';
import '../../../data/remote/live_api.dart';
import '../../../domain/entities/live_models.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../providers/session_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../../widgets/marque.dart';

/// Les cours en direct, sur le téléphone (02/10).
///
/// --- Ce que cet écran fait, et ce qu'il ne fait pas ----------------------
///
/// Il montre la grille, les séances de la famille et la rediffusion. Il
/// **n'ouvre pas la salle** : entrer dans une visioconférence demande
/// `livekit_client`, donc WebRTC, donc huit à douze mégaoctets par architecture
/// dans l'APK. Cet APK circule par Bluetooth et par Xender ; son poids est une
/// contrainte commerciale, pas un détail. La décision est séparée et assumée.
///
/// Tout ce qui est ici ne coûte **rien** en poids : le lecteur de rediffusion
/// est `video_player`, déjà embarqué, et HLS est lu nativement par ExoPlayer.
///
/// --- L'ordre de lecture --------------------------------------------------
///
/// « Mes séances » d'abord. Quelqu'un qui a déjà payé vient retrouver son cours,
/// pas en chercher un autre — et c'est aussi là qu'il trouve la rediffusion
/// après une coupure de courant, qui est la première raison de rater un cours
/// ici.
class LiveGridPage extends ConsumerStatefulWidget {
  const LiveGridPage({super.key});

  @override
  ConsumerState<LiveGridPage> createState() => _LiveGridPageState();
}

class _LiveGridPageState extends ConsumerState<LiveGridPage> {
  SlotGrid? _grille;
  List<LiveSessionSummary> _seances = const [];
  List<MySession> _miennes = const [];
  String? _erreur;
  bool _horsLigne = false;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final api = ref.read(liveApiProvider);
    final connecte = ref.read(sessionProvider).value?.userId != null;

    try {
      // La grille en premier : elle est publique, et c'est elle qui doit
      // s'afficher même si la lecture des séances de la famille échoue.
      final grille = await SlotGrid.load();
      final seances = await api.sessions();

      // Les séances de la famille ne concernent pas un visiteur anonyme, et la
      // route répondrait 401. On ne la demande donc pas.
      final miennes = connecte ? await api.mySessions() : const <MySession>[];

      if (!mounted) return;
      setState(() {
        _grille = grille;
        _seances = seances;
        _miennes = miennes;
        _chargement = false;
      });
    } on LiveApiException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreur = erreur.message;
        _horsLigne = erreur.offline;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = backendUnavailableMessage;
        _horsLigne = true;
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cours en direct')),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Un professeur, quinze élèves au maximum, à heure fixe. Vous levez '
              'la main pour parler, et le professeur réexplique ce qui n’est pas '
              'passé avant de continuer.',
            ),
            const Gap(16),

            if (_erreur != null)
              InfoBanner(
                message: _erreur!,
                tone: _horsLigne ? StatusTone.warning : StatusTone.danger,
              ),

            if (_chargement) ...[
              const Gap(16),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_miennes.isNotEmpty) ...[
              const Gap(8),
              const SectionHeader(title: 'Mes séances'),
              for (final seance in _mesSeancesTriees)
                _MaSeanceCard(seance: seance, grille: _grille),
              const Gap(16),
            ],

            if (!_chargement && _erreur == null) ...[
              const SectionHeader(title: 'Prochaines séances'),
              if (_seances.isEmpty)
                const KitEmpty(
                  icon: Icons.event_busy_outlined,
                  message:
                      'Aucune séance programmée. Les professeurs n’ont pas '
                      'encore ouvert de créneau — revenez bientôt.',
                )
              else
                for (final jour in _parJour.entries) ...[
                  const Gap(8),
                  Text(
                    _titreDeJour(jour.key),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(8),
                  for (final seance in jour.value)
                    _SeanceCard(seance: seance, grille: _grille),
                ],
            ],
          ],
        ),
      ),
    );
  }

  /// Les séances à venir d'abord, puis les passées de la plus récente à la plus
  /// ancienne : c'est l'ordre dans lequel on les cherche. Le serveur les rend
  /// déjà ainsi ; on ne retrie que pour ne pas dépendre de cet ordre.
  List<MySession> get _mesSeancesTriees {
    final maintenant = DateTime.now();
    final liste = [..._miennes]
      ..sort((a, b) {
        final aVenirA = !a.isOverAt(maintenant);
        final aVenirB = !b.isOverAt(maintenant);
        if (aVenirA != aVenirB) return aVenirA ? -1 : 1;
        return aVenirA
            ? a.startsAt.compareTo(b.startsAt)
            : b.startsAt.compareTo(a.startsAt);
      });
    return liste;
  }

  /// Les séances groupées par journée.
  ///
  /// Par jour et non en liste plate : « jeudi, deux cours » se comprend d'un
  /// coup d'œil, une suite d'horodatages non.
  Map<DateTime, List<LiveSessionSummary>> get _parJour {
    final groupes = <DateTime, List<LiveSessionSummary>>{};
    for (final seance in _seances) {
      final jour = DateTime(
        seance.startsAt.year,
        seance.startsAt.month,
        seance.startsAt.day,
      );
      groupes.putIfAbsent(jour, () => []).add(seance);
    }
    final ordonne = groupes.keys.toList()..sort();
    return {
      for (final jour in ordonne)
        jour: groupes[jour]!..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
    };
  }

  /// « samedi 17 octobre ».
  ///
  /// La date etait ecrite « Samedi 17/10 ». Un quantieme en chiffres separes
  /// par une barre se lit a l'anglaise une fois sur deux — et la charte
  /// ecrit les dates en toutes lettres partout ailleurs.
  String _titreDeJour(DateTime jour) {
    final grille = _grille;
    final nom = grille == null ? '' : grille.dayLabel(grille.dayOf(jour));
    return '$nom ${jour.day} ${_mois[jour.month - 1]}';
  }

  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
}

/// Une séance de la grille publique.
class _SeanceCard extends StatelessWidget {
  const _SeanceCard({required this.seance, this.grille});

  final LiveSessionSummary seance;
  final SlotGrid? grille;

  @override
  Widget build(BuildContext context) {
    final complet = seance.isFull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seance.subject?.name ?? seance.title ?? 'Cours',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                MoneyText(Fmt.money(seance.price)),
              ],
            ),
            const Gap(4),
            MetaText(
              [
                if (grille != null) grille!.labelOf(seance.slotId),
                if (seance.level != null) seance.level!.name,
                if (seance.teacherName.isNotEmpty) seance.teacherName,
              ].join(' · '),
            ),
            const Gap(8),
            Row(
              children: [
                /*
                 * La classe de quinze, le cinquieme signe de la marque.
                 *
                 * Quinze places, trois rangs de cinq. Le nombre etait ecrit
                 * — « 2 places » — et c'etait deja mieux que « disponible »,
                 * qui laisse remettre a demain. Le dessin dit en plus
                 * **combien il en reste sur combien**, ce qu'un nombre seul
                 * ne dit pas : deux places sur quinze et deux sur trois ne
                 * se decident pas de la meme facon.
                 *
                 * La phrase reste a cote : la charte l'exige, et un carre de
                 * couleur seul ne dit pas combien.
                 */
                Quinze(
                  prises: seance.seats - seance.seatsLeft,
                  libelle: complet
                      ? 'Complet : 15 places prises sur 15'
                      : '${seance.seatsLeft} place'
                            '${seance.seatsLeft > 1 ? 's' : ''} libre'
                            '${seance.seatsLeft > 1 ? 's' : ''} sur ${seance.seats}',
                  mini: true,
                ),
                const Gap(AppSpacing.espace3),
                StatusPill(
                  label: complet
                      ? 'Complet'
                      // Le nombre et non « des places disponibles » : « 2 places »
                      // décide d'agir maintenant, « disponible » laisse remettre.
                      : '${seance.seatsLeft} place${seance.seatsLeft > 1 ? 's' : ''}',
                  tone: complet ? StatusTone.neutral : StatusTone.success,
                ),
              ],
            ),

            /*
             * La mention passe sous la rangee, et non a sa droite.
             *
             * Elle y etait, poussee par un `Spacer`. Sur un telephone de 390
             * points — la largeur la plus repandue — « 11 places » et
             * « Reservation sur le site » ne tiennent pas sur la meme ligne :
             * la rangee debordait de deux a huit points selon le nombre.
             *
             * Un debordement de Flutter ne casse rien en production : il
             * rogne le texte et peint des hachures jaunes en mode debogage,
             * invisibles dans l'APK. Il a fallu rendre l'ecran hors
             * telephone pour le voir.
             *
             * L'inscription et le paiement vivent sur le site : porter le
             * choix du portefeuille, la redirection Djomy et le retour de
             * webhook dans l'application doublerait un parcours qui marche,
             * pour une fonction qu'on utilise une fois par semaine.
             */
            if (!complet) ...[
              const Gap(AppSpacing.espace2),
              Text(
                'Réservation sur le site',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une séance que la famille a réservée.
class _MaSeanceCard extends StatelessWidget {
  const _MaSeanceCard({required this.seance, this.grille});

  final MySession seance;
  final SlotGrid? grille;

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final passee = seance.isOverAt(maintenant);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seance.subject?.name ?? seance.title ?? 'Cours',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (seance.childName != null) TagChip(label: seance.childName!),
              ],
            ),
            const Gap(4),
            MetaText(
              [
                if (grille != null)
                  '${grille!.dayLabel(grille!.dayOf(seance.startsAt))} ${seance.startsAt.day}/${seance.startsAt.month}',
                _heure(seance.startsAt),
              ].where((part) => part.isNotEmpty).join(' · '),
            ),

            if (!seance.isPaid) ...[
              const Gap(8),
              // La réservation expire au bout de vingt minutes. Sans ce message,
              // quelqu'un qui croit avoir payé se présente à 18 h devant une
              // porte fermée.
              const InfoBanner(
                message:
                    'Place réservée, paiement non confirmé. Elle sera relâchée si '
                    'le paiement n’aboutit pas.',
                tone: StatusTone.warning,
              ),
            ],

            if (seance.status == 'CANCELLED') ...[
              const Gap(8),
              const InfoBanner(
                message: 'Cette séance a été annulée.',
                tone: StatusTone.warning,
              ),
            ] else if (passee && seance.isPaid) ...[
              /*
               * La preuve de presence.
               *
               * --- Ce qu'elle remplace ----------------------------------
               *
               * Rien. Le total de la semaine existait — « 90 minutes cette
               * semaine » — mais un total ne repond pas a « etait-il la
               * mardi ». C'est pourtant la seule question qu'un parent se
               * pose, et la promesse du produit : « Votre enfant etait la.
               * Vous le voyez. »
               *
               * --- Pourquoi un chiffre et non un pourcentage ------------
               *
               * « 52 minutes sur 60 » se verifie ; « taux d'assiduite 87 % »
               * demande de croire un calcul. Et le premier se raconte a
               * l'enfant le soir.
               *
               * Le surligneur montre les minutes suivies ; les traits sont
               * les points de controle, un par quart d'heure. On n'affiche
               * rien quand la seance n'a pas ete suivie du tout : une ligne
               * vide se lirait comme un reproche, et le message juste
               * en dessous dit deja quoi faire.
               */
              /*
                La preuve de presence, resumee ici et entiere la-bas.
                
                La ligne du temps etait posee en entier sur cette carte. Elle
                y tenait, mais la carte d'une seance sert a retrouver un
                cours — l'heure, la matiere, la rediffusion — et la preuve
                merite un ecran a elle : « c'est le coeur de la promesse, il
                paie et il sait ».
                
                Ce qui reste ici est la phrase et le chiffre, qui suffisent a
                savoir. Le reste — l'heure d'arrivee, les points de controle,
                ce qui a ete travaille, le bouton pour reserver la suivante —
                vit sur `/direct/<id>/presence`.
              */
              if (seance.minutesAttended > 0) ...[
                const Gap(AppSpacing.espace3),
                KitCard(
                  onTap: () => context.push(
                    Routes.presenceProof(seance.sessionId),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seance.childName == null
                                  ? 'Vous avez suivi '
                                        '${seance.minutesAttended} minutes '
                                        'sur ${seance.durationMinutes}.'
                                  : '${seance.childName} a suivi '
                                        '${seance.minutesAttended} minutes '
                                        'sur ${seance.durationMinutes}.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Gap(AppSpacing.espace1),
                            Text(
                              'Voir la preuve de presence',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.violette),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.crayon,
                      ),
                    ],
                  ),
                ),
              ],
              const Gap(8),
              if (seance.replay == 'FAILED')
                Text(
                  'L’enregistrement de cette séance n’a pas abouti.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
              else
                // Proposée dès que la séance est passée, même si le transfert
                // n'est pas fini : l'écran de rediffusion sait dire « dans
                // quelques minutes », et il le dit mieux qu'un lien absent.
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.push(Routes.sessionReplay(seance.sessionId)),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(
                    seance.replay == 'READY'
                        ? 'Voir la rediffusion'
                        : 'Rediffusion en préparation',
                  ),
                ),
            ] else if (seance.isPaid && seance.canJoinAt(maintenant)) ...[
              const Gap(8),
              // La salle existe sur le téléphone depuis le 03/10 : c'est
              // l'appareil que l'élève a vraiment, et renvoyer vers un
              // ordinateur revenait à vendre un cours qu'il ne pouvait pas
              // suivre.
              FilledButton.icon(
                onPressed: () =>
                    context.push(Routes.liveRoom(seance.sessionId)),
                icon: const Icon(Icons.sensors),
                label: Text(
                  seance.status == 'LIVE'
                      ? 'Rejoindre maintenant'
                      : 'Entrer dans la salle',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _heure(DateTime quand) =>
      '${quand.hour.toString().padLeft(2, '0')}:'
      '${quand.minute.toString().padLeft(2, '0')}';
}
