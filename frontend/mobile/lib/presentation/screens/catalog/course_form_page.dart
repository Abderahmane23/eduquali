import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/document_pipeline.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/course_content_repository.dart';
import '../../../data/repositories/video_courses_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/type_ahead.dart';

/// Créer un cours vidéo (note du 21/09, chapitres le 02/10).
///
/// Le cours se construit en chapitres : chacun porte un titre, ce qu'il
/// traite, ses vidéos et ses ressources. C'est la forme sous laquelle l'élève
/// le lira, et la saisir autrement obligerait à deviner le découpage après
/// coup.
///
/// La commission de 20 % est affichée **avant** la publication, avec ce qui
/// reste au professeur : découvrir la retenue au moment du premier virement
/// est la meilleure façon de perdre quelqu'un.
class CourseFormPage extends ConsumerStatefulWidget {
  const CourseFormPage({super.key});

  @override
  ConsumerState<CourseFormPage> createState() => _CourseFormPageState();
}

/// Un fichier ou un lien posé dans un chapitre, avant publication.
class _Element {
  _Element({required this.kind, required this.title, this.path, this.url});

  final CourseItemKind kind;
  String title;

  /// Le fichier sur l'appareil — nul pour un lien.
  final String? path;

  /// L'adresse, pour un lien.
  final String? url;
}

/// Un chapitre en cours de saisie.
///
/// Porte ses propres contrôleurs : partager un contrôleur entre chapitres
/// ferait que taper dans l'un écrirait dans l'autre.
class _Chapitre {
  _Chapitre();

  final titre = TextEditingController();
  final description = TextEditingController();
  final List<_Element> elements = [];

  /// Ouvert à la création : un chapitre replié à la seconde où on l'ajoute
  /// donne l'impression que le bouton n'a rien fait.
  bool ouvert = true;

  List<_Element> get videos =>
      elements.where((e) => e.kind == CourseItemKind.video).toList();

  List<_Element> get ressources =>
      elements.where((e) => e.kind != CourseItemKind.video).toList();

  void dispose() {
    titre.dispose();
    description.dispose();
  }
}

class _CourseFormPageState extends ConsumerState<CourseFormPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();

  /// Un chapitre d'avance : un professeur qui vend une seule vidéo n'a pas à
  /// comprendre ce qu'est un chapitre avant de pouvoir commencer.
  final List<_Chapitre> _chapitres = [_Chapitre()];

  String? _subjectId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    for (final chapitre in _chapitres) {
      chapitre.dispose();
    }
    super.dispose();
  }

  int get _amount => int.tryParse(_price.text.trim()) ?? 0;

  int get _nombreDeVideos =>
      _chapitres.fold(0, (total, c) => total + c.videos.length);

  /// Ce qui manque, en une phrase. `null` = publiable.
  String? get _blocking {
    if (_title.text.trim().isEmpty) return 'Donnez un titre à votre cours.';
    if (_nombreDeVideos == 0) return 'Ajoutez au moins une vidéo.';
    for (var i = 0; i < _chapitres.length; i++) {
      if (_chapitres[i].titre.text.trim().isEmpty) {
        return 'Donnez un titre au chapitre ${i + 1}.';
      }
    }
    // Un chapitre vide s'afficherait dans le sommaire de l'élève comme une
    // ligne sur laquelle on ne peut pas cliquer.
    for (var i = 0; i < _chapitres.length; i++) {
      if (_chapitres[i].elements.isEmpty) {
        return 'Le chapitre ${i + 1} est vide : ajoutez une vidéo ou '
            'supprimez-le.';
      }
    }
    if (_amount <= 0) return 'Indiquez le prix de votre cours.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Créer un cours'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                // `AppSpacing.page` ne borde que les côtés : le premier
                // champ collait à la barre de titre et le dernier à la
                // barre d'action, comme si le formulaire était tronqué.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  TextField(
                    controller: _title,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Les fonctions affines, de A à Z',
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ce que l’élève va apprendre (facultatif)',
                    ),
                  ),

                  const Gap(AppSpacing.lg),
                  Text('Matière', style: text.titleSmall),
                  const Gap(AppSpacing.sm),
                  TypeAheadTags(
                    options: [
                      for (final subject in subjects)
                        PickerOption(value: subject.id, label: subject.name),
                    ],
                    // Une seule matière par cours : réappuyer sur
                    // l'étiquette la retire, c'est le seul moyen de revenir
                    // en arrière.
                    selected: _subjectId == null ? const [] : [_subjectId!],
                    hint: 'Tapez une matière…',
                    emptyMessage: 'Aucune matière ne correspond',
                    onToggle: (id) => setState(
                      () => _subjectId = _subjectId == id ? null : id,
                    ),
                  ),

                  const Gap(AppSpacing.xl),
                  Text('Programme du cours', style: text.titleSmall),
                  const Gap(4),
                  Text(
                    'Un chapitre par partie du cours. L’élève les voit dans '
                    'cet ordre.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  for (var i = 0; i < _chapitres.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _CarteChapitre(
                        chapitre: _chapitres[i],
                        rang: i + 1,
                        // Le seul chapitre ne se supprime pas : un cours sans
                        // chapitre n'aurait plus d'endroit où déposer une
                        // vidéo.
                        onSupprimer: _chapitres.length == 1
                            ? null
                            : () => _supprimerChapitre(i),
                        onVideo: () => _ajouterFichier(
                          _chapitres[i],
                          CourseItemKind.video,
                        ),
                        onRessource: () => _ajouterFichier(
                          _chapitres[i],
                          CourseItemKind.document,
                        ),
                        onLien: () => _ajouterLien(_chapitres[i]),
                        onRetirer: (element) => setState(
                          () => _chapitres[i].elements.remove(element),
                        ),
                        onChange: () => setState(() {}),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _ajouterChapitre,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter un chapitre'),
                  ),

                  const Gap(AppSpacing.xl),
                  TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Prix du cours',
                      suffixText: 'GNF',
                    ),
                  ),
                  if (_amount > 0) ...[
                    const Gap(AppSpacing.md),
                    _Commission(price: _amount),
                  ],

                  if (_error != null) ...[
                    const Gap(AppSpacing.lg),
                    InfoBanner(
                      message: _error!,
                      tone: StatusTone.danger,
                      icon: Icons.error_outline,
                    ),
                  ],
                ],
              ),
            ),

            // Le bouton ne defile plus avec le formulaire : sa raison
            // d'etre desactive — ce qui manque encore — s'affiche juste
            // au-dessus, la ou on la lira.
            StickyActionBar(
              label: 'Mettre en vente',
              busy: _busy,
              note: _blocking,
              onPressed: _blocking != null ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }

  void _ajouterChapitre() {
    setState(() {
      // Les précédents se replient : dix chapitres ouverts font un formulaire
      // de trois écrans de haut, et on perd celui qu'on vient d'ajouter.
      for (final chapitre in _chapitres) {
        chapitre.ouvert = false;
      }
      _chapitres.add(_Chapitre());
    });
  }

  void _supprimerChapitre(int index) {
    setState(() => _chapitres.removeAt(index).dispose());
  }

  /// Choisit une vidéo ou une ressource et la pose dans le chapitre.
  Future<void> _ajouterFichier(_Chapitre chapitre, CourseItemKind kind) async {
    final pipeline = ref.read(documentPipelineProvider);
    try {
      final fichier = kind == CourseItemKind.video
          ? await pipeline.pickCourseVideo()
          : await pipeline.pickCourseResource();
      if (fichier == null || !mounted) return;
      setState(
        () => chapitre.elements.add(
          _Element(kind: kind, title: fichier.name, path: fichier.path),
        ),
      );
    } on MediaTooLarge catch (refus) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$refus')));
    }
  }

  /// Ajoute un lien — une vidéo déjà en ligne, un document partagé.
  ///
  /// Un professeur dont la vidéo est déjà sur Internet n'a pas à la
  /// retélécharger pour la redéposer, sur une connexion qui se paie au mégaoctet.
  Future<void> _ajouterLien(_Chapitre chapitre) async {
    final titre = TextEditingController();
    final adresse = TextEditingController();
    final ajoute = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Ajouter un lien'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titre,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Intitulé',
                hintText: 'Exercices du chapitre 1',
              ),
            ),
            const Gap(AppSpacing.md),
            TextField(
              controller: adresse,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                hintText: 'https://…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    final url = adresse.text.trim();
    final intitule = titre.text.trim();
    titre.dispose();
    adresse.dispose();
    if (ajoute != true || url.isEmpty || !mounted) return;

    setState(
      () => chapitre.elements.add(
        _Element(
          kind: CourseItemKind.link,
          title: intitule.isEmpty ? url : intitule,
          url: url,
        ),
      ),
    );
  }

  Future<void> _publish() async {
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final courseId = await ref
          .read(videoCoursesRepositoryProvider)
          .create(
            teacherId: teacherId,
            title: _title.text,
            price: _amount,
            description: _description.text,
            subjectId: _subjectId,
            // La liste plate reste celle du cours comme objet de vente : elle
            // dit « ce cours contient des vidéos ». Le découpage en chapitres
            // est écrit juste après.
            videoPaths: [
              for (final chapitre in _chapitres)
                for (final video in chapitre.videos)
                  video.path ?? video.url ?? '',
            ].where((c) => c.isNotEmpty).toList(),
          );

      await ref
          .read(courseContentRepositoryProvider)
          .writeChapters(
            courseId: courseId,
            chapters: [
              for (final chapitre in _chapitres)
                ChapterDraft(
                  title: chapitre.titre.text,
                  description: chapitre.description.text,
                  items: [
                    for (final element in chapitre.elements)
                      ItemDraft(
                        kind: element.kind,
                        title: element.title,
                        localPath: element.path,
                        remoteUrl: element.url,
                      ),
                  ],
                ),
            ],
          );

      refreshVideoCourses(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre cours est en vente.')),
      );
      context.pop();
    } on VideoCourseException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Un chapitre, replié ou ouvert.
///
/// Replié, l'en-tête dit ce qu'il contient : sans ce décompte, refermer un
/// chapitre reviendrait à le perdre de vue.
class _CarteChapitre extends StatelessWidget {
  const _CarteChapitre({
    required this.chapitre,
    required this.rang,
    required this.onVideo,
    required this.onRessource,
    required this.onLien,
    required this.onRetirer,
    required this.onChange,
    this.onSupprimer,
  });

  final _Chapitre chapitre;
  final int rang;
  final VoidCallback onVideo;
  final VoidCallback onRessource;
  final VoidCallback onLien;
  final ValueChanged<_Element> onRetirer;
  final VoidCallback onChange;
  final VoidCallback? onSupprimer;

  /// « 2 vidéos · 1 ressource », ou ce qui manque.
  String get _resume {
    final videos = chapitre.videos.length;
    final ressources = chapitre.ressources.length;
    if (videos == 0 && ressources == 0) return 'Aucun contenu';
    final parties = <String>[
      if (videos > 0) '$videos vidéo${videos > 1 ? 's' : ''}',
      if (ressources > 0) '$ressources ressource${ressources > 1 ? 's' : ''}',
    ];
    return parties.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titre = chapitre.titre.text.trim();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Le trait par défaut d'ExpansionTile coupe la carte en deux dans le
        // sens de la largeur, juste au-dessus de son propre bord.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(chapitre),
          initiallyExpanded: chapitre.ouvert,
          onExpansionChanged: (ouvert) => chapitre.ouvert = ouvert,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          title: Text(
            titre.isEmpty ? 'Chapitre $rang' : 'Chapitre $rang · $titre',
            style: text.titleSmall,
          ),
          subtitle: Text(
            _resume,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          children: [
            TextField(
              controller: chapitre.titre,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => onChange(),
              decoration: const InputDecoration(
                labelText: 'Titre du chapitre',
                hintText: 'Reconnaître une fonction affine',
              ),
            ),
            const Gap(AppSpacing.md),
            TextField(
              controller: chapitre.description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'De quoi parle ce chapitre (facultatif)',
                // Ce texte s'affiche sous la vidéo, dans le lecteur : le dire
                // ici évite d'y écrire un résumé du cours entier.
                helperText: 'Affiché sous la vidéo',
              ),
            ),

            const Gap(AppSpacing.md),
            for (final element in chapitre.elements)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LigneElement(
                  element: element,
                  onRetirer: () => onRetirer(element),
                ),
              ),

            const Gap(4),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: onVideo,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Vidéo'),
                ),
                OutlinedButton.icon(
                  onPressed: onRessource,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Ressource'),
                ),
                OutlinedButton.icon(
                  onPressed: onLien,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Lien'),
                ),
                if (onSupprimer != null)
                  TextButton.icon(
                    onPressed: onSupprimer,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de contenu : son genre, son nom, et de quoi la retirer.
class _LigneElement extends StatelessWidget {
  const _LigneElement({required this.element, required this.onRetirer});

  final _Element element;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icone, couleur) = switch (element.kind) {
      CourseItemKind.video => (Icons.videocam_outlined, AppColors.success),
      CourseItemKind.document => (
        Icons.description_outlined,
        AppColors.primary,
      ),
      CourseItemKind.link => (Icons.link, AppColors.info),
    };

    return Row(
      children: [
        Icon(icone, size: 20, color: couleur),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            element.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium,
          ),
        ),
        IconButton(
          onPressed: onRetirer,
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Retirer',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// Ce que la plateforme retient, et ce qui reste au professeur.
class _Commission extends StatelessWidget {
  const _Commission({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final net = AppConstants.videoCourseNet(price);
    final part = (AppConstants.videoCourseCommission * 100).round();

    return AppCard(
      color: AppColors.infoSurface,
      borderColor: AppColors.infoSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sur ${Fmt.money(price)}, il vous revient ${Fmt.money(net)}.',
            style: text.titleSmall,
          ),
          const SizedBox(height: 3),
          Text(
            'La plateforme retient $part % — hébergement des vidéos et '
            'encaissement. Le prix affiché à l’élève est celui que vous '
            'fixez.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
