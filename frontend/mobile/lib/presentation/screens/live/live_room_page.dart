import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../providers/session_providers.dart';
import 'live_chat_overlay.dart';

import '../../../data/remote/live_api.dart';
import '../../../domain/entities/live_models.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// La salle d'un cours en direct, sur le téléphone (03/10).
///
/// --- Ce que cet écran coûte, et pourquoi on l'a quand même ---------------
///
/// `livekit_client` entraîne `flutter_webrtc`, qui embarque la bibliothèque
/// WebRTC native : **8 à 12 Mo par architecture**, soit un APK qui passe
/// d'environ 56 Mo à 75–80 Mo. Cet APK circule par Bluetooth et par Xender ; son
/// poids est une contrainte commerciale, pas un détail d'ingénierie.
///
/// Ce qui justifie la dépense : le téléphone est l'appareil que l'élève a
/// vraiment. Sans cet écran, un cours payé ne se suit que depuis un ordinateur —
/// et la grille, la réservation et la rediffusion du téléphone menaient à une
/// porte qu'il fallait ouvrir ailleurs.
///
/// --- Les mêmes règles que sur le site ------------------------------------
///
/// LiveKit n'a aucune notion de compte : il fait confiance au jeton que le
/// serveur signe. Tout le contrôle d'accès est donc côté serveur, et cet écran
/// n'essaie pas de le refaire. Il se contente de ne pas mentir :
///
///   * un élève **ne publie pas** en entrant. Le serveur le lui a refusé dans
///     le jeton, donc tenter puis échouer afficherait une erreur de permission à
///     quelqu'un qui n'a rien demandé ;
///   * le mode **audio seul** est un bouton, pas un réglage caché : c'est lui qui
///     sauve un cours sur une mauvaise ligne ;
///   * la salle **dit qu'elle enregistre**, à tout le monde.
class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

enum _Etape { sas, connexion, salle, fini }

class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  /// La discussion de la seance. **Jamais ecrite en base** : elle se lit
  /// pendant le cours, et un historique conserve sur une classe d'adolescents
  /// est une responsabilite, pas une fonction.
  final List<LiveChatMessage> _messages = [];

  _Etape _etape = _Etape.sas;
  String? _erreur;
  String _role = 'student';
  String? _enregistrement;

  Room? _salle;
  final List<RemoteParticipant> _participants = [];
  final List<String> _mainsLevees = [];
  bool _maMain = false;
  bool _micro = true;
  bool _camera = true;

  Checkpoint? _pointOuvert;
  String? _maReponse;
  String? _maPlace;
  Timer? _rattrapage;
  EventsListener<RoomEvent>? _ecouteur;

  @override
  void dispose() {
    _rattrapage?.cancel();
    // L'ecouteur garde une souscription sur le flux d'evenements de la salle :
    // ne pas le liberer fait fuir un abonnement par entree dans un cours.
    _ecouteur?.dispose();
    // Quitter sans se déconnecter laisse la caméra allumée et le flux facturé :
    // LiveKit compte les minutes participant.
    _salle?.disconnect();
    _salle?.dispose();
    super.dispose();
  }

  // --- Entrer ---------------------------------------------------------------

  Future<void> _rejoindre({required bool avecCamera}) async {
    setState(() {
      _etape = _Etape.connexion;
      _erreur = null;
    });

    final api = ref.read(liveApiProvider);
    try {
      final acces = await api.roomToken(widget.sessionId);
      _role = acces.role;
      _enregistrement = acces.recording;
      _maPlace = acces.enrolmentId;

      final salle = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _ecouter(salle);
      await salle.connect(acces.url, acces.token);

      // Le professeur publie d'emblée ; un élève n'y a pas droit, et le serveur
      // l'a déjà décidé dans le jeton.
      if (_role == 'teacher') {
        await salle.localParticipant?.setMicrophoneEnabled(true);
        await salle.localParticipant?.setCameraEnabled(avecCamera);
        try {
          final ouverte = await api.openRoom(widget.sessionId);
          _enregistrement = ouverte.recording;
        } catch (cause) {
          // L'enregistrement est un confort, pas la séance : son échec ne doit
          // pas empêcher le cours.
          debugPrint('[salle] ouverture serveur : $cause');
        }
      }

      if (!mounted) {
        await salle.disconnect();
        return;
      }
      setState(() {
        _salle = salle;
        _camera = _role == 'teacher' ? avecCamera : false;
        _etape = _Etape.salle;
      });
      _lancerRattrapage();
    } on LiveApiException catch (cause) {
      if (!mounted) return;
      setState(() {
        _erreur = cause.message;
        _etape = _Etape.sas;
      });
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        _erreur = 'La salle n’a pas pu s’ouvrir. $cause';
        _etape = _Etape.sas;
      });
    }
  }

  void _ecouter(Room salle) {
    // `listen` avec un aiguillage sur le type, et non une chaine de `.on<T>()` :
    // c'est la forme que le SDK emploie lui-meme (`agent/session.dart`), et elle
    // ne depend pas d'une extension qui pourrait bouger d'une version a l'autre.
    final ecouteur = salle.createListener();
    _ecouteur = ecouteur;
    ecouteur.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ParticipantConnectedEvent():
        case ParticipantDisconnectedEvent():
        case TrackSubscribedEvent():
        case TrackUnsubscribedEvent():
          _rafraichir(salle);
        case RoomDisconnectedEvent():
          setState(() => _etape = _Etape.fini);
        case DataReceivedEvent(:final data, :final participant):
          _surDonnees(data, participant?.identity);
        default:
          break;
      }
    });
  }

  void _rafraichir(Room salle) {
    if (!mounted) return;
    setState(() {
      _participants
        ..clear()
        ..addAll(salle.remoteParticipants.values);
    });
  }

  /// Les messages de la salle : main levée, ouverture et fermeture d'un point de
  /// contrôle. Tous éphémères — les stocker créerait des lignes qu'on ne
  /// relirait jamais.
  void _surDonnees(List<int> data, String? expediteur) {
    Map<String, dynamic> message;
    try {
      message = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      // Un message illisible n'est pas une panne de la salle.
      return;
    }
    if (!mounted) return;

    final type = message['type'];

    if (type == 'hand' && expediteur != null) {
      setState(() {
        _mainsLevees.remove(expediteur);
        // On ajoute à la fin : la file se lit dans l'ordre d'arrivée, et trois
        // mains levées en même temps doivent se départager.
        if (message['up'] == true) _mainsLevees.add(expediteur);
      });
      return;
    }

    if (type == 'checkpoint' && message['id'] is String) {
      setState(() {
        _pointOuvert = Checkpoint(
          id: message['id'] as String,
          moduleIndex: switch (message['moduleIndex']) {
            final int i => i,
            final num n => n.round(),
            _ => 0,
          },
        );
        _maReponse = null;
      });
      return;
    }

    if (type == 'checkpoint-closed') {
      setState(() => _pointOuvert = null);
      return;
    }

    if (type == 'chat' && message['text'] is String) {
      final texte = (message['text'] as String).trim();
      if (texte.isEmpty) return;
      setState(() {
        _messages.add(
          LiveChatMessage(
            // Le nom vient de l'expediteur declare dans son message : son
            // identite LiveKit est l'identifiant d'une place, pas un prenom.
            author: (message['from'] as String?)?.trim().isNotEmpty == true
                ? message['from'] as String
                : 'Quelqu’un',
            text: texte,
            at: DateTime.now(),
            fromTeacher: message['teacher'] == true,
          ),
        );
        // Le fil ne grandit pas sans fin : une seance de 90 minutes dans une
        // classe bavarde tiendrait des milliers de messages en memoire, pour
        // une douzaine affichee.
        if (_messages.length > 80) {
          _messages.removeRange(0, _messages.length - 80);
        }
      });
    }
  }

  /// Envoie un message a la classe.
  ///
  /// Affiche d'abord chez soi : LiveKit ne renvoie pas a l'expediteur ce qu'il
  /// publie, et attendre un echo qui ne vient jamais donnerait l'impression que
  /// le message n'est pas parti.
  Future<void> _envoyerMessage(String texte) async {
    final nom = ref.read(currentSessionProvider)?.firstName ?? 'Moi';
    setState(() {
      _messages.add(
        LiveChatMessage(
          author: nom,
          text: texte,
          at: DateTime.now(),
          fromTeacher: _role == 'teacher',
          mine: true,
        ),
      );
    });
    await _publier({
      'type': 'chat',
      'text': texte,
      'from': nom,
      'teacher': _role == 'teacher',
    });
  }

  /// Rattrapage toutes les vingt secondes : l'élève entré après l'ouverture d'un
  /// module ne reçoit pas le message de données, et resterait aveugle.
  void _lancerRattrapage() {
    _rattrapage?.cancel();
    _relirePoints();
    _rattrapage = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _relirePoints(),
    );
  }

  Future<void> _relirePoints() async {
    try {
      final vue = await ref.read(liveApiProvider).checkpoints(widget.sessionId);
      if (!mounted) return;
      final ouvert = vue.checkpoints
          .where((p) => p.closedAt == null)
          .firstOrNull;
      setState(() {
        _pointOuvert = ouvert;
        _maReponse = ouvert?.myAnswer;
      });
    } catch (_) {
      // Un point de contrôle indisponible ne doit pas interrompre le cours.
    }
  }

  // --- Gestes ---------------------------------------------------------------

  Future<void> _publier(Map<String, Object?> message) async {
    final local = _salle?.localParticipant;
    if (local == null) return;
    await local.publishData(utf8.encode(jsonEncode(message)), reliable: true);
  }

  Future<void> _basculerMain() async {
    final suivant = !_maMain;
    setState(() => _maMain = suivant);
    await _publier({'type': 'hand', 'up': suivant});
  }

  Future<void> _repondre(String reponse) async {
    final point = _pointOuvert;
    if (point == null) return;
    // Affiché tout de suite : sur une ligne lente, attendre le serveur ferait
    // croire que le bouton n'a pas pris.
    setState(() => _maReponse = reponse);
    try {
      await ref
          .read(liveApiProvider)
          .answerCheckpoint(point.id, reponse, enrolmentId: _maPlace);
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        _maReponse = null;
        _erreur = cause is LiveApiException
            ? cause.message
            : 'La réponse n’est pas partie.';
      });
    }
  }

  // --- Écrans ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return switch (_etape) {
      _Etape.sas || _Etape.connexion => _sas(),
      _Etape.salle => _salleEnCours(),
      _Etape.fini => _fini(),
    };
  }

  Widget _sas() {
    final connexion = _etape == _Etape.connexion;
    return Scaffold(
      appBar: AppBar(title: const Text('Avant d’entrer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erreur != null)
            InfoBanner(message: _erreur!, tone: StatusTone.warning),
          const Gap(12),
          const Text(
            'Vous allez rejoindre le cours. Le professeur vous donnera la parole '
            'quand vous lèverez la main.',
          ),
          const Gap(24),
          FilledButton(
            onPressed: connexion ? null : () => _rejoindre(avecCamera: true),
            child: Text(connexion ? 'Connexion…' : 'Entrer dans la salle'),
          ),
          const Gap(8),
          // Le mode audio seul est un bouton, pas un réglage : c'est lui qui
          // sauve un cours sur une mauvaise ligne.
          OutlinedButton(
            onPressed: connexion ? null : () => _rejoindre(avecCamera: false),
            child: const Text('Entrer en audio seulement'),
          ),
          const Gap(8),
          Text(
            'L’audio seul consomme beaucoup moins de données et tient sur une '
            'connexion faible.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _fini() {
    return Scaffold(
      appBar: AppBar(title: const Text('Séance terminée')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoBanner(
            message: 'Vous avez quitté la salle.',
            tone: StatusTone.info,
          ),
          const Gap(12),
          FilledButton.tonalIcon(
            // `Navigator.pushReplacementNamed` attendait un nom de route : il
            // n'en existe aucun, donc ce bouton levait au lieu d'ouvrir la
            // rediffusion. go_router remplace la salle par le lecteur.
            onPressed: () =>
                context.pushReplacement(Routes.sessionReplay(widget.sessionId)),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Voir la rediffusion'),
          ),
          const Gap(8),
          Text(
            'Elle apparaît quelques minutes après la fin du cours.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _salleEnCours() {
    final professeur = _role == 'teacher';
    return Scaffold(
      appBar: AppBar(
        title: Text(professeur ? 'Votre cours' : 'Cours en direct'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dire qu'on enregistre, à tout le monde et sans le cacher dans un
          // réglage : quinze élèves mineurs filmés pendant 90 minutes doivent le
          // savoir. L'information vient du serveur.
          if (_enregistrement == 'RECORDING')
            const InfoBanner(
              message:
                  'Cette séance est enregistrée. La rediffusion sera disponible '
                  'pour les élèves inscrits.',
              tone: StatusTone.info,
            ),

          if (_erreur != null) ...[
            const Gap(8),
            InfoBanner(message: _erreur!, tone: StatusTone.warning),
          ],

          const Gap(12),
          _Scene(
            participants: _participants,
            overlay: LiveChatOverlay(
              messages: _messages,
              onSend: _envoyerMessage,
            ),
          ),

          const Gap(12),
          Text(
            _participants.isEmpty
                ? (professeur
                      ? 'Aucun élève connecté pour l’instant.'
                      : 'Le professeur n’est pas encore entré.')
                : '${_participants.length} participant'
                      '${_participants.length > 1 ? 's' : ''} en ligne',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),

          // Le point de contrôle : trois gros boutons chez l'élève.
          if (!professeur && _pointOuvert != null) ...[
            const Gap(16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Module ${_pointOuvert!.moduleIndex + 1} — est-ce passé ?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(8),
                  if (_maReponse != null)
                    Text(
                      'Réponse enregistrée. Le professeur la voit, pas la '
                      'classe.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        for (final (valeur, libelle) in const [
                          ('YES', 'Oui'),
                          ('PARTLY', 'Pas assez'),
                          ('NO', 'Non'),
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilledButton.tonal(
                                onPressed: () => _repondre(valeur),
                                child: Text(libelle),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Gap(8),
                    // Anonyme pour la classe, et le dire : c'est la seule raison
                    // pour laquelle la réponse sera vraie.
                    Text(
                      'Personne dans la classe ne voit votre réponse.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // La file des mains levées, dans l'ordre d'arrivée.
          if (professeur && _mainsLevees.isNotEmpty) ...[
            const Gap(16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_mainsLevees.length} main'
                    '${_mainsLevees.length > 1 ? 's' : ''} levée'
                    '${_mainsLevees.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Gap(8),
                  for (final (rang, identity) in _mainsLevees.indexed)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${rang + 1}. '
                            '${_participants.firstWhere((p) => p.identity == identity, orElse: () => _participants.first).name.isEmpty ? 'Élève' : _participants.firstWhere((p) => p.identity == identity, orElse: () => _participants.first).name}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _publier({'type': 'floor', 'to': identity});
                            setState(() => _mainsLevees.remove(identity));
                          },
                          child: const Text('Donner la parole'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],

          const Gap(16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (professeur) ...[
                OutlinedButton(
                  onPressed: () async {
                    await _salle?.localParticipant?.setMicrophoneEnabled(
                      !_micro,
                    );
                    setState(() => _micro = !_micro);
                  },
                  child: Text(_micro ? 'Couper le micro' : 'Activer le micro'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await _salle?.localParticipant?.setCameraEnabled(!_camera);
                    setState(() => _camera = !_camera);
                  },
                  child: Text(
                    _camera ? 'Couper la caméra' : 'Activer la caméra',
                  ),
                ),
              ] else
                FilledButton.tonal(
                  onPressed: _basculerMain,
                  child: Text(_maMain ? 'Baisser la main' : 'Lever la main'),
                ),
              OutlinedButton(
                onPressed: () => _salle?.disconnect(),
                child: const Text('Quitter'),
              ),
              // Terminer n'est pas quitter : le professeur peut sortir et
              // revenir pendant une pause sans clore la séance pour quinze
              // élèves.
              if (professeur)
                OutlinedButton(
                  onPressed: () async {
                    final confirme = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Terminer la séance ?'),
                        content: const Text(
                          'Tous les élèves seront déconnectés.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Terminer'),
                          ),
                        ],
                      ),
                    );
                    if (confirme != true) return;
                    try {
                      await ref
                          .read(liveApiProvider)
                          .closeRoom(widget.sessionId);
                    } catch (cause) {
                      debugPrint('[salle] fermeture : $cause');
                    }
                    await _salle?.disconnect();
                  },
                  child: const Text('Terminer la séance'),
                ),
            ],
          ),

          if (!professeur && _maMain) ...[
            const Gap(8),
            Text(
              'Main levée. Le professeur vous donnera la parole.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Les flux vidéo des participants.
///
/// Le premier occupe la place — le professeur —, les suivants tiennent dans un
/// bandeau. Quinze vignettes de même taille ne servent personne sur un écran de
/// téléphone.
class _Scene extends StatelessWidget {
  const _Scene({required this.participants, this.overlay});

  /// Ce qui se pose par-dessus l'image principale : la discussion.
  final Widget? overlay;

  final List<RemoteParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final pistes = <VideoTrack>[];
    for (final participant in participants) {
      for (final publication in participant.videoTrackPublications) {
        final piste = publication.track;
        if (piste != null) pistes.add(piste);
      }
    }

    if (pistes.isEmpty) {
      return AspectRatio(
        aspectRatio: MediaQuery.sizeOf(context).width >= 720 ? 1 : 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B10),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'En attente de la vidéo…',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    /*
     * Vertical sur un telephone, carre sur un grand ecran.
     *
     * Un cours se suit sur un telephone tenu a la verticale : le 16/9 y
     * occupait un bandeau au milieu de l'ecran, avec du vide au-dessus et en
     * dessous, et la discussion n'avait nulle part ou tenir. Le 9/16 remplit la
     * main.
     *
     * Sur un ecran large, le 9/16 ferait l'inverse — une colonne etroite entre
     * deux marges enormes. Le carre tient les deux : il reste haut sans devenir
     * une meurtriere.
     *
     * Le seuil est celui d'une tablette en largeur ; en dessous, on est tenu a
     * la main.
     */
    final large = MediaQuery.sizeOf(context).width >= 720;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: large ? 1 : 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoTrackRenderer(pistes.first),
                // La discussion par-dessus l'image, jamais a cote : voir
                // `live_chat_overlay.dart`.
                if (overlay != null) Positioned.fill(child: overlay!),
              ],
            ),
          ),
        ),
        if (pistes.length > 1) ...[
          const Gap(8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pistes.length - 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: VideoTrackRenderer(pistes[i + 1]),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
