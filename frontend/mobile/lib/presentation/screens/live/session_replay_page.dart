import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../data/remote/live_api.dart';
import '../../../domain/entities/live_models.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// La rediffusion d'une séance, sur le téléphone (02/10).
///
/// --- Pourquoi cet écran compte plus ici que sur le site ------------------
///
/// Une coupure de courant pendant le cours est la première raison de rater une
/// séance en Guinée, et elle n'a rien à voir avec l'élève. Sans rediffusion, un
/// cours payé est un cours perdu — et c'est au deuxième incident que la famille
/// arrête de payer.
///
/// Le téléphone est l'appareil que l'élève a vraiment. C'est donc ici que la
/// rediffusion sera regardée, pas sur l'ordinateur de la maison.
///
/// --- Pourquoi `video_player` suffit, alors que le site prend un `iframe` --
///
/// Le flux est en HLS. Sur Android, `video_player` le lit nativement par
/// ExoPlayer : rien à ajouter, **aucun poids supplémentaire dans l'APK**. Le
/// site, lui, doit passer par le lecteur de Cloudflare Stream parce que Chrome
/// et Firefox ne
/// lisent pas HLS sans bibliothèque. Les deux clients prennent donc le chemin le
/// moins coûteux de leur plateforme, et le serveur rend les deux adresses.
class SessionReplayPage extends ConsumerStatefulWidget {
  const SessionReplayPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionReplayPage> createState() => _SessionReplayPageState();
}

class _SessionReplayPageState extends ConsumerState<SessionReplayPage> {
  SessionReplay? _etat;
  String? _erreur;
  bool _chargement = true;

  VideoPlayerController? _lecteur;
  bool _pleinEcran = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    // Un lecteur non libéré garde le décodeur matériel et le haut-parleur : la
    // vidéo continue de s'entendre après le retour en arrière.
    _lecteur?.dispose();
    if (_pleinEcran) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final etat = await ref.read(liveApiProvider).replay(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _etat = etat;
        _chargement = false;
      });
      final flux = etat.hls;
      if (etat.available && flux != null) await _ouvrir(flux);
    } on LiveApiException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreur = erreur.message;
        _chargement = false;
      });
    }
  }

  Future<void> _ouvrir(String url) async {
    final ancien = _lecteur;
    final lecteur = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await lecteur.initialize();
    } catch (_) {
      await lecteur.dispose();
      if (!mounted) return;
      setState(() {
        _erreur =
            'La vidéo n’a pas pu être lue. Vérifiez votre connexion et '
            'réessayez.';
      });
      return;
    }
    if (!mounted) {
      await lecteur.dispose();
      return;
    }
    setState(() => _lecteur = lecteur);
    await ancien?.dispose();
    // Pas de lecture automatique : 90 minutes de vidéo sur une connexion payée
    // au mégaoctet se déclenchent sur un geste, jamais toutes seules.
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;

    if (_pleinEcran && _lecteur != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _lecteur!.value.aspectRatio,
                child: VideoPlayer(_lecteur!),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Quitter le plein écran',
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  onPressed: _basculerPleinEcran,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(etat?.title ?? 'Rediffusion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erreur != null)
            InfoBanner(message: _erreur!, tone: StatusTone.danger),

          if (_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_lecteur != null) ...[
            _Lecteur(controller: _lecteur!, onPleinEcran: _basculerPleinEcran),
            const Gap(12),

            // Les quatre modules, quand la séance a eu ses points de contrôle.
            //
            // Un élève qui a manqué le module 3 ne fait pas défiler 90 minutes.
            // Le repère est une seconde, pas un fichier : `seekTo` suffit, et il
            // n'y a ni ré-encodage, ni quatre vidéos à stocker et à signer.
            if (etat != null && etat.chapters.isNotEmpty) ...[
              Text(
                'Reprendre à',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chapitre in etat.chapters)
                    OutlinedButton(
                      onPressed: () async {
                        await _lecteur!.seekTo(chapitre.start);
                        await _lecteur!.play();
                      },
                      child: Text(chapitre.label),
                    ),
                ],
              ),
              const Gap(12),
            ],
            if (etat?.startsAt != null)
              Text(
                'Séance du ${_date(etat!.startsAt!)}.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            const Gap(4),
            // Le lien est signé et temporaire : le dire évite qu'on le partage
            // en croyant offrir le cours, et qu'on s'étonne qu'il expire.
            Text(
              'Cette vidéo vous est réservée. Le lien expire au bout de '
              'quelques heures.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ] else if (etat != null && !etat.available)
            _Attente(status: etat.status, onRelire: _charger),
        ],
      ),
    );
  }

  void _basculerPleinEcran() {
    setState(() => _pleinEcran = !_pleinEcran);
    if (_pleinEcran) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  String _date(DateTime quand) => '${quand.day}/${quand.month}/${quand.year}';
}

/// La vidéo et ses commandes.
class _Lecteur extends StatelessWidget {
  const _Lecteur({required this.controller, required this.onPleinEcran});

  final VideoPlayerController controller;
  final VoidCallback onPleinEcran;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                // La barre de progression est indispensable sur une
                // rediffusion : on y revient pour un passage précis, pas pour
                // tout revoir.
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(8),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, valeur, _) => Row(
            children: [
              IconButton(
                tooltip: valeur.isPlaying ? 'Pause' : 'Lire',
                icon: Icon(valeur.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () =>
                    valeur.isPlaying ? controller.pause() : controller.play(),
              ),
              // Reculer de dix secondes : le geste qu'on fait quand une phrase
              // n'est pas passée, et la raison pour laquelle on regarde une
              // rediffusion plutôt que de redemander au professeur.
              IconButton(
                tooltip: 'Reculer de 10 secondes',
                icon: const Icon(Icons.replay_10),
                onPressed: () => controller.seekTo(
                  valeur.position - const Duration(seconds: 10),
                ),
              ),
              IconButton(
                tooltip: 'Avancer de 10 secondes',
                icon: const Icon(Icons.forward_10),
                onPressed: () => controller.seekTo(
                  valeur.position + const Duration(seconds: 10),
                ),
              ),
              Expanded(
                child: Text(
                  '${_duree(valeur.position)} / ${_duree(valeur.duration)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Plein écran',
                icon: const Icon(Icons.fullscreen),
                onPressed: onPleinEcran,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _duree(Duration duree) {
    final minutes = duree.inMinutes;
    final secondes = duree.inSeconds % 60;
    return '$minutes:${secondes.toString().padLeft(2, '0')}';
  }
}

/// Ce qu'on affiche quand il n'y a pas encore de vidéo.
///
/// Quatre états et quatre phrases, parce que « indisponible » ne dit pas s'il
/// faut attendre deux minutes, revenir demain, ou prévenir quelqu'un. Une seule
/// phrase pour les quatre produirait exactement l'appel au support qu'on essaie
/// d'éviter.
class _Attente extends StatelessWidget {
  const _Attente({required this.status, required this.onRelire});

  final String status;
  final VoidCallback onRelire;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'RECORDING' => const InfoBanner(
        message:
            'La séance est en cours. La rediffusion sera prête peu après la '
            'fin.',
        tone: StatusTone.info,
      ),
      'TRANSFERRING' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            message:
                'La rediffusion est en préparation. Comptez quelques minutes '
                'après la fin du cours.',
            tone: StatusTone.info,
          ),
          const Gap(12),
          OutlinedButton(
            onPressed: onRelire,
            child: const Text('Vérifier à nouveau'),
          ),
        ],
      ),
      'FAILED' => const InfoBanner(
        message:
            'L’enregistrement de cette séance n’a pas abouti. Votre professeur '
            'peut reprendre les points manqués au prochain cours — '
            'signalez-le-lui.',
        tone: StatusTone.warning,
      ),
      _ => const InfoBanner(
        message: 'Cette séance n’a pas d’enregistrement.',
        tone: StatusTone.info,
      ),
    };
  }
}
