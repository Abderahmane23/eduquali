import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/remote/live_api.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Publier un cours en direct.
///
/// --- Le trou que cet écran comble ---------------------------------------
///
/// Il n'existait **aucun parcours de création**, ni ici ni sur le site. Les
/// cours en direct ne pouvaient venir que d'un semis manuel en base, et la
/// conséquence se lisait en chaîne : pas de cours, donc pas de séance, donc
/// pas de place payée, donc aucune présence, aucun groupe de discussion, et
/// rien dans « En direct ».
///
/// Trois fonctions terminées restaient invisibles, faute de ce formulaire.
///
/// --- Les quatre décisions, dans cet ordre -------------------------------
///
/// Matière et classe d'abord : elles décident à qui le cours est proposé. Puis
/// le prix, puis les créneaux. L'ordre n'est pas esthétique — un professeur
/// qui choisit son horaire avant de savoir pour quelle classe se trompe de
/// public.
class PublishCoursePage extends ConsumerStatefulWidget {
  const PublishCoursePage({super.key});

  @override
  ConsumerState<PublishCoursePage> createState() => _PublishCoursePageState();
}

class _PublishCoursePageState extends ConsumerState<PublishCoursePage> {
  final _titre = TextEditingController();
  final _description = TextEditingController();
  final _prix = TextEditingController(text: '45000');

  String? _matiereId;
  String? _niveauId;
  final _creneaux = <String>{};
  int _places = 15;
  bool _envoi = false;

  @override
  void dispose() {
    for (final c in [_titre, _description, _prix]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ce qui manque pour pouvoir publier, dit en clair.
  ///
  /// Un bouton grisé sans explication se lit comme une panne : on dit donc
  /// quoi faire, au lieu de laisser deviner.
  String? get _manque {
    if (_matiereId == null) return 'Choisissez la matière.';
    if (_niveauId == null) return 'Choisissez la classe.';
    final prix = int.tryParse(_prix.text.trim());
    if (prix == null) return 'Le prix doit être un nombre.';
    // Les mêmes bornes que la contrainte en base : les refuser ici donne un
    // message lisible plutôt qu'une erreur de serveur.
    if (prix < 1000) return 'Le prix minimum est de 1 000 GNF.';
    if (prix > 1000000) return 'Le prix maximum est de 1 000 000 GNF.';
    if (_creneaux.isEmpty) return 'Choisissez au moins un créneau.';
    return null;
  }

  Future<void> _publier() async {
    final probleme = _manque;
    final messenger = ScaffoldMessenger.of(context);
    if (probleme != null) {
      messenger.showSnackBar(SnackBar(content: Text(probleme)));
      return;
    }

    setState(() => _envoi = true);
    try {
      final cours = await ref
          .read(liveApiProvider)
          .createCourse(
            subjectId: _matiereId!,
            levelId: _niveauId!,
            price: int.parse(_prix.text.trim()),
            seats: _places,
            slotIds: _creneaux.toList(),
            title: _titre.text,
            description: _description.text,
          );
      if (!mounted) return;

      // Le nombre de séances est la vraie confirmation. « Cours publié » sans
      // séance ne veut rien dire : personne ne pourrait s'y inscrire.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            cours.sessionsCreated == 0
                ? 'Cours publié, mais aucune séance n’a pu être posée. '
                      'Vérifiez vos créneaux.'
                : '${cours.title} publié · ${cours.sessionsCreated} séance'
                      '${cours.sessionsCreated > 1 ? 's' : ''} programmée'
                      '${cours.sessionsCreated > 1 ? 's' : ''}',
          ),
        ),
      );
      ref.invalidate(myCoursesProvider);
      if (context.mounted) context.pop();
    } on LiveApiException catch (cause) {
      messenger.showSnackBar(SnackBar(content: Text(cause.message)));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matieres = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final niveaux = ref.watch(levelsProvider).valueOrNull ?? const [];
    final creneaux = ref.watch(liveSlotsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Publier un cours en direct'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // Ce que le professeur gagne, avant qu'il saisisse quoi que ce
            // soit : c'est la raison pour laquelle il remplit ce formulaire.
            _Gain(prix: int.tryParse(_prix.text.trim()) ?? 0, places: _places),

            const Gap(AppSpacing.xl),
            FormSection(
              title: 'Ce que vous enseignez',
              children: [
                const FieldLabel('Matière'),
                DropdownButtonFormField<String>(
                  initialValue: _matiereId,
                  isExpanded: true,
                  hint: const Text('Choisir une matière'),
                  items: [
                    for (final m in matieres)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) => setState(() => _matiereId = v),
                ),
                const Gap(AppSpacing.md),
                const FieldLabel('Classe'),
                DropdownButtonFormField<String>(
                  initialValue: _niveauId,
                  isExpanded: true,
                  hint: const Text('Choisir une classe'),
                  items: [
                    for (final n in niveaux)
                      DropdownMenuItem(value: n.id, child: Text(n.name)),
                  ],
                  onChanged: (v) => setState(() => _niveauId = v),
                ),
                const Gap(AppSpacing.sm),
                const MetaText(
                  'La classe décide à qui le cours est proposé : un collégien '
                  'ne verra pas un cours de licence.',
                ),
              ],
            ),

            const Gap(AppSpacing.lg),
            FormSection(
              title: 'Le prix et les places',
              children: [
                const FieldLabel('Prix par élève et par séance'),
                UnitField(
                  controller: _prix,
                  unit: 'GNF',
                  hint: '45000',
                  onChanged: (_) => setState(() {}),
                ),
                const Gap(AppSpacing.xs),
                const MetaText(
                  'Entre 40 000 et 50 000 GNF selon votre expérience. La '
                  'plateforme retient 40 %.',
                ),
                const Gap(AppSpacing.md),
                FieldLabel('Places : $_places'),
                Slider(
                  value: _places.toDouble(),
                  min: 1,
                  max: 15,
                  divisions: 14,
                  label: '$_places',
                  onChanged: (v) => setState(() => _places = v.round()),
                ),
                const MetaText(
                  'Quinze au maximum, et c’est voulu : au-delà, vous ne pouvez '
                  'plus répondre à chacun pendant les pauses — ce qui est '
                  'exactement ce que l’élève paie.',
                ),
              ],
            ),

            const Gap(AppSpacing.lg),
            FormSection(
              title: 'Quand',
              children: [
                const MetaText(
                  'Les séances se répètent chaque semaine sur les créneaux '
                  'choisis, quatre semaines à l’avance.',
                ),
                const Gap(AppSpacing.sm),
                if (creneaux.isEmpty)
                  const KitEmpty(
                    icon: Icons.schedule_outlined,
                    message: 'Créneaux en cours de lecture…',
                  )
                else
                  for (final creneau in creneaux)
                    CheckboxListTile(
                      value: _creneaux.contains(creneau.id),
                      onChanged: (coche) => setState(() {
                        if (coche == true) {
                          _creneaux.add(creneau.id);
                        } else {
                          _creneaux.remove(creneau.id);
                        }
                      }),
                      title: Text(creneau.resume),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
              ],
            ),

            const Gap(AppSpacing.lg),
            FormSection(
              title: 'Présentation (facultatif)',
              children: [
                const FieldLabel('Titre', optional: true),
                TextField(
                  controller: _titre,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'Maths — révisions du soir',
                    counterText: '',
                  ),
                ),
                const Gap(AppSpacing.sm),
                const MetaText(
                  'Laissé vide, le titre reprend la matière et la classe.',
                ),
                const Gap(AppSpacing.md),
                const FieldLabel('Ce que l’élève y trouvera', optional: true),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    hintText:
                        'Deux séances par semaine, questions en direct, '
                        'exercices corrigés ensemble.',
                    counterText: '',
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.xl),
            if (_manque case final probleme?) ...[
              InfoBanner(message: probleme, tone: StatusTone.warning),
              const Gap(AppSpacing.sm),
            ],
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _envoi || _manque != null ? null : _publier,
                icon: const Icon(Icons.publish_outlined),
                label: Text(
                  _envoi ? 'Publication…' : 'Publier le cours',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ce que rapporte une séance pleine, calculé en direct.
///
/// Posé en tête du formulaire parce que c'est la réponse à « pourquoi est-ce
/// que je remplis ça ». Un professeur qui voit 405 000 francs par séance
/// remplit le reste.
class _Gain extends StatelessWidget {
  const _Gain({required this.prix, required this.places});

  final int prix;
  final int places;

  @override
  Widget build(BuildContext context) {
    final brut = prix * places;
    // 40 % pour la plateforme, 60 % pour le professeur : le partage arrêté en
    // stratégie, et la raison du 60 % est qu'il vaut mieux que le particulier.
    final part = (brut * 0.60).round();

    return AppCard(
      color: AppColors.primarySurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Une séance pleine vous rapporte',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Gap(2),
          Text(
            Fmt.money(part),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const Gap(4),
          MetaText(
            '$places élèves × ${Fmt.money(prix)} = ${Fmt.money(brut)}, '
            'dont 60 % pour vous',
          ),
        ],
      ),
    );
  }
}

/// Les créneaux que le serveur accepte.
final liveSlotsProvider = FutureProvider<List<LiveSlot>>(
  (ref) => ref.watch(liveApiProvider).slots(),
);

/// Les cours que ce professeur a déjà publiés.
final myCoursesProvider = FutureProvider<List<MyCourse>>(
  (ref) => ref.watch(liveApiProvider).myCourses(),
);
