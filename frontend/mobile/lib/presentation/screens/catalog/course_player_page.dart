import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../../../data/repositories/course_content_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Le lecteur d'un cours vidéo (02/10).
///
/// Un cours était une liste plate de fichiers : six vidéos les unes sous les
/// autres, sans titre ni ordre, et rien pour dire ce que chacune traite. Un
/// élève qui reprenait le cours la semaine suivante ne retrouvait pas où il
/// s'était arrêté.
///
/// Trois choses à l'écran : le sommaire par chapitres, la vidéo, et ce qu'on
/// en dit. La description du chapitre vit sous la vidéo, là où l'on regarde.
///
/// **La disposition suit la largeur, pas le support.** Côte à côte demandé le
/// 02/10, et côte à côte sur un téléphone en portrait donnerait une vidéo de
/// cent soixante-dix points de large — moins qu'une vignette. Le sommaire
/// passe donc sous la vidéo en dessous de [_largeurPourDeuxColonnes], et à
/// gauche au-delà : tablette, téléphone couché, et le plein écran dans les
/// deux cas.
class CoursePlayerPage extends ConsumerStatefulWidget {
  const CoursePlayerPage({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CoursePlayerPage> createState() => _CoursePlayerPageState();
}

/// En dessous, une colonne ; au-delà, deux.
///
/// 600 points est la largeur d'un téléphone couché et d'une petite tablette.
/// En dessous, la moitié de l'écran ne suffit pas à une vidéo.
const double _largeurPourDeuxColonnes = 600;

class _CoursePlayerPageState extends ConsumerState<CoursePlayerPage> {
  List<CourseChapter> _chapitres = const [];
  CourseChapter? _chapitre;
  CourseItem? _element;
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
    _lecteur?.dispose();
    // Le plein écran change l'orientation et masque les barres du système :
    // quitter l'écran sans les rendre laisserait le reste de l'application
    // couché et sans barre d'état.
    if (_pleinEcran) _quitterLePleinEcran(rebuild: false);
    super.dispose();
  }

  Future<void> _charger() async {
    final chapitres = await ref
        .read(courseContentRepositoryProvider)
        .chaptersOf(widget.courseId);
    if (!mounted) return;

    final premier = chapitres.firstOrNull;
    setState(() {
      _chapitres = chapitres;
      _chapitre = premier;
      _chargement = false;
    });

    final video = premier?.videos.firstOrNull;
    if (video != null) await _ouvrir(premier!, video);
  }

  /// Ouvre un exercice, un corrigé ou un lien.
  ///
  /// Un fichier passe par l'application du téléphone — un lecteur PDF fait ce
  /// travail mieux qu'un écran écrit ici. Un lien est copié : sans
  /// `url_launcher`, le coller dans le navigateur reste le geste le plus
  /// court, et c'est déjà ce que fait la fiche d'un établissement.
  Future<void> _ouvrirLaRessource(CourseItem element) async {
    final source = element.source;
    if (source == null) return;

    if (element.kind == CourseItemKind.link || source.startsWith('http')) {
      await Clipboard.setData(ClipboardData(text: source));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien copié. Collez-le dans votre navigateur.'),
        ),
      );
      return;
    }

    final resultat = await OpenFilex.open(source);
    if (!mounted || resultat.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aucune application ne peut ouvrir ce fichier sur cet appareil.',
        ),
      ),
    );
  }

  /// Ouvre une vidéo. Le lecteur précédent est libéré avant, pas après : deux
  /// contrôleurs vivants jouent deux bandes-son en même temps.
  Future<void> _ouvrir(CourseChapter chapitre, CourseItem element) async {
    final source = element.source;
    if (source == null) return;

    await _lecteur?.dispose();
    final lecteur = source.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.file(File(source));

    setState(() {
      _chapitre = chapitre;
      _element = element;
      _lecteur = lecteur;
    });

    try {
      await lecteur.initialize();
      if (!mounted) return;
      setState(() {});
      await lecteur.play();
    } catch (erreur) {
      if (!mounted) return;
      // Un fichier absent ou illisible est fréquent : la vidéo a pu être
      // supprimée du téléphone depuis l'achat. On le dit au lieu de laisser
      // un cadre noir.
      setState(() => _lecteur = null);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Lecture impossible : $erreur')));
    }
  }

  void _basculerLePleinEcran() {
    if (_pleinEcran) {
      _quitterLePleinEcran();
    } else {
      setState(() => _pleinEcran = true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _quitterLePleinEcran({bool rebuild = true}) {
    if (rebuild) setState(() => _pleinEcran = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  Widget build(BuildContext context) {
    if (_pleinEcran) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _Video(
            controller: _lecteur,
            onFullscreen: _basculerLePleinEcran,
            fullscreen: true,
          ),
        ),
      );
    }

    final cours = ref.watch(videoCourseProvider(widget.courseId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(cours?.title ?? 'Cours'),
      ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : _chapitres.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: KitEmpty(
                  icon: Icons.play_circle_outline,
                  message:
                      'Ce cours n’a pas encore de chapitre. Le professeur est '
                      'en train de le construire.',
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= _largeurPourDeuxColonnes
                    ? _deuxColonnes()
                    : _uneColonne(),
              ),
      ),
    );
  }

  /// Téléphone debout : la vidéo d'abord, le sommaire dessous.
  Widget _uneColonne() => ListView(
    padding: EdgeInsets.zero,
    children: [
      _Video(
        controller: _lecteur,
        onFullscreen: _basculerLePleinEcran,
        fullscreen: false,
      ),
      _SousLaVideo(chapitre: _chapitre, element: _element),
      const Divider(height: 1, color: AppColors.border),
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _Sommaire(
          chapitres: _chapitres,
          courant: _element,
          onChoisir: _ouvrir,
          onRessource: _ouvrirLaRessource,
        ),
      ),
      if (_element != null) _Commentaires(item: _element!),
    ],
  );

  /// Écran large : le sommaire à gauche, la vidéo à droite.
  Widget _deuxColonnes() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 320,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Sommaire(
              chapitres: _chapitres,
              courant: _element,
              onChoisir: _ouvrir,
              onRessource: _ouvrirLaRessource,
            ),
          ],
        ),
      ),
      const VerticalDivider(width: 1, color: AppColors.border),
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Video(
              controller: _lecteur,
              onFullscreen: _basculerLePleinEcran,
              fullscreen: false,
            ),
            _SousLaVideo(chapitre: _chapitre, element: _element),
            if (_element != null) _Commentaires(item: _element!),
          ],
        ),
      ),
    ],
  );
}

/// La vidéo et ses commandes.
class _Video extends StatelessWidget {
  const _Video({
    required this.controller,
    required this.onFullscreen,
    required this.fullscreen,
  });

  final VideoPlayerController? controller;
  final VoidCallback onFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final lecteur = controller;
    if (lecteur == null || !lecteur.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 48,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: fullscreen ? lecteur.value.aspectRatio : 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: lecteur.value.aspectRatio,
                child: VideoPlayer(lecteur),
              ),
            ),

            // Le fil de lecture : c'est ce qu'on cherche en premier quand on
            // reprend une vidéo.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                lecteur,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.accent,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),

            ValueListenableBuilder(
              valueListenable: lecteur,
              builder: (context, valeur, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Commande(
                    icon: valeur.isPlaying ? Icons.pause : Icons.play_arrow,
                    tooltip: valeur.isPlaying ? 'Pause' : 'Lire',
                    onTap: () =>
                        valeur.isPlaying ? lecteur.pause() : lecteur.play(),
                  ),
                  _Commande(
                    icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    tooltip: fullscreen
                        ? 'Quitter le plein écran'
                        : 'Plein écran',
                    onTap: onFullscreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Commande extends StatelessWidget {
  const _Commande({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    // Le nom passe par `tooltip` et non par un `Tooltip` autour : c'est le
    // meme texte pour le lecteur d'ecran, et c'est celui que la regle
    // d'accessibilite sait verifier.
    child: IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 30),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black38,
        // La cible reste à 48 points même quand l'icône est plus petite :
        // une commande de lecteur se touche d'un pouce, en mouvement.
        minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
      ),
    ),
  );
}

/// Le titre de la vidéo et la description du chapitre.
class _SousLaVideo extends StatelessWidget {
  const _SousLaVideo({required this.chapitre, required this.element});

  final CourseChapter? chapitre;
  final CourseItem? element;

  @override
  Widget build(BuildContext context) {
    final ch = chapitre;
    if (ch == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            element?.title ?? ch.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MetaText('Chapitre ${ch.position + 1} · ${ch.title}'),

          // La description du chapitre, sous la vidéo : demandée le 02/10, et
          // c'est le bon endroit — on la lit en regardant, pas dans un
          // sommaire qu'on a déjà quitté.
          if ((ch.description ?? '').isNotEmpty) ...[
            const Gap(AppSpacing.md),
            Text(
              ch.description!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Le sommaire : un chapitre par tiroir, vidéos et ressources dedans.
class _Sommaire extends StatelessWidget {
  const _Sommaire({
    required this.chapitres,
    required this.courant,
    required this.onChoisir,
    required this.onRessource,
  });

  final List<CourseChapter> chapitres;
  final CourseItem? courant;
  final void Function(CourseChapter, CourseItem) onChoisir;

  /// Ouvrir un exercice ou un lien. Separe de [onChoisir] : une ressource ne
  /// remplace pas la video a l'ecran, elle s'ouvre a cote.
  final void Function(CourseItem) onRessource;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const KitSectionTitle(title: 'Sommaire'),
      for (final chapitre in chapitres)
        KitCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            // Le chapitre en cours s'ouvre seul : reprendre un cours ne doit
            // pas commencer par déplier dix tiroirs.
            initiallyExpanded: chapitre.items.any((i) => i.id == courant?.id),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            title: Text(
              '${chapitre.position + 1}. ${chapitre.title}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              [
                if (chapitre.videos.isNotEmpty)
                  '${chapitre.videos.length} vidéo'
                      '${chapitre.videos.length > 1 ? 's' : ''}',
                if (chapitre.resources.isNotEmpty)
                  '${chapitre.resources.length} ressource'
                      '${chapitre.resources.length > 1 ? 's' : ''}',
              ].join(' · '),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            children: [
              for (final element in chapitre.items)
                ListTile(
                  leading: Icon(
                    switch (element.kind) {
                      CourseItemKind.video => Icons.play_circle_outline,
                      CourseItemKind.document => Icons.description_outlined,
                      CourseItemKind.link => Icons.link,
                    },
                    size: 22,
                    color: element.id == courant?.id
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                  title: Text(
                    element.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: element.id == courant?.id
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: element.id == courant?.id
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  // Une ligne grisee sans raison se lit comme une panne. Dire
                  // « Bientot disponible » dit la verite : le professeur n'a
                  // pas encore depose ce fichier.
                  subtitle: element.source == null
                      ? Text(
                          element.durationSeconds == null
                              ? 'Bientôt disponible'
                              : '${_duree(element.durationSeconds!)} · '
                                    'Bientôt disponible',
                        )
                      : element.durationSeconds == null
                      ? null
                      : Text(_duree(element.durationSeconds!)),
                  // Une vidéo sans fichier ne se joue pas : le signaler par
                  // une ligne grisée vaut mieux qu'un cadre noir au clic.
                  enabled: element.source != null,
                  onTap: switch (element.kind) {
                    CourseItemKind.video =>
                      element.isPlayable
                          ? () => onChoisir(chapitre, element)
                          : null,
                    // Une ressource qui ne fait rien au clic se lit comme une
                    // panne : le professeur l'a deposee, elle doit s'ouvrir.
                    _ =>
                      element.source == null
                          ? null
                          : () => onRessource(element),
                  },
                ),
            ],
          ),
        ),
    ],
  );

  static String _duree(int secondes) {
    final m = secondes ~/ 60;
    final s = secondes % 60;
    return '$m min ${s.toString().padLeft(2, '0')}';
  }
}

/// Les commentaires sous la vidéo.
class _Commentaires extends ConsumerStatefulWidget {
  const _Commentaires({required this.item});

  final CourseItem item;

  @override
  ConsumerState<_Commentaires> createState() => _CommentairesState();
}

class _CommentairesState extends ConsumerState<_Commentaires> {
  final _champ = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final texte = _champ.text.trim();
    final session = ref.read(currentSessionProvider);
    if (texte.isEmpty || session == null) return;

    setState(() => _envoi = true);
    try {
      await ref
          .read(courseContentRepositoryProvider)
          .comment(
            itemId: widget.item.id,
            authorId: session.userId,
            body: texte,
          );
      _champ.clear();
      ref.invalidate(courseCommentsProvider(widget.item.id));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentaires =
        ref.watch(courseCommentsProvider(widget.item.id)).valueOrNull ??
        const [];
    final connecte = ref.watch(currentSessionProvider) != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitSectionTitle(
            title: commentaires.isEmpty
                ? 'Questions'
                : 'Questions (${commentaires.length})',
          ),

          if (commentaires.isEmpty)
            const Text(
              'Aucune question sur cette vidéo. Posez la première : le '
              'professeur reçoit la notification.',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),

          for (final commentaire in commentaires)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: KitCard(
                // La réponse du professeur se distingue : sur une question de
                // cours, qui répond change tout.
                color: commentaire.fromTeacher
                    ? AppColors.primarySurface
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            commentaire.authorName.isEmpty
                                ? 'Participant'
                                : commentaire.authorName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (commentaire.fromTeacher)
                          const StatusPill(
                            label: 'Professeur',
                            tone: StatusTone.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      commentaire.body,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (connecte) ...[
            const Gap(AppSpacing.md),
            TextField(
              controller: _champ,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Posez votre question…',
                suffixIcon: IconButton(
                  onPressed: _envoi ? null : _envoyer,
                  tooltip: 'Envoyer',
                  icon: const Icon(Icons.send, size: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
