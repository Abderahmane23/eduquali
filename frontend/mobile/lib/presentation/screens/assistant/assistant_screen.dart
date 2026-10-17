import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/course_models.dart';
import '../../../domain/usecases/subscription_rules.dart';
import '../../../core/constants/app_enums.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common.dart';
import '../billing/subscription_sheet.dart';
import 'assistant_controller.dart';
import 'assistant_messages.dart';
import 'course_form_screen.dart';

/// L'assistant : une discussion, des actions rapides, et la formule en cours.
///
/// Il etait facture au credit : un solde en haut, une feuille d'achat quand
/// il tombait a zero. Il fait desormais partie de l'abonnement — c'est
/// l'abonnement qui ouvre la porte, et rien ne se compte pendant qu'on s'en
/// sert. Une personne qui paie tous les mois ne doit pas avoir a surveiller
/// un compteur en ecrivant une question.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// La formule du compte, expiration comprise.
  SubscriptionPlan get _plan {
    final session = ref.read(currentSessionProvider);
    return effectivePlan(
      SubscriptionPlan.fromCode(session?.plan),
      session?.planRenewsAt,
      DateTime.now(),
    );
  }

  /// Vrai quand l'abonnement ouvre l'assistant.
  ///
  /// Demande au moment du geste, et non a l'ouverture de l'ecran : quelqu'un
  /// qui vient de taper sa question sait exactement ce qu'il achete, ce
  /// qu'une feuille affichee d'emblee ne dit a personne.
  Future<bool> _ouvert() async {
    if (allows(_plan, PaidFeature.assistant)) return true;
    return showSubscriptionSheet(
      context,
      required: PaidFeature.assistant.requires,
      because:
          'L’assistant fait partie de l’abonnement : il construit '
          'vos cours, corrige les exercices et répond aux questions de '
          'vos élèves.',
    );
  }

  /// Verifie l'abonnement, execute, puis redescend sur le dernier message.
  Future<void> _guard(Future<void> Function() action) async {
    if (!await _ouvert()) return;
    try {
      await action();
    } finally {
      if (mounted) {
        refreshAi(ref);
        _scrollToEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final session = ref.watch(currentSessionProvider);
    final plan = effectivePlan(
      SubscriptionPlan.fromCode(session?.plan),
      session?.planRenewsAt,
      DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          // La formule en cours, a la place du solde de credits. Elle dit
          // en un mot ce qui est ouvert ; « Basic » se touche pour voir ce
          // que l'abonnement ajoute.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ActionChip(
              avatar: Icon(
                plan == SubscriptionPlan.free
                    ? Icons.lock_outline
                    : Icons.workspace_premium_outlined,
                size: 16,
              ),
              label: Text(plan.label),
              onPressed: plan == SubscriptionPlan.free ? _ouvert : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isEmpty
                ? _Welcome(onCreateCourse: _createCourse)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: state.messages.length,
                    itemBuilder: (_, i) => _Bubble(
                      message: state.messages[i],
                      onBuild: (brief, outline) => _guard(
                        () => ref
                            .read(assistantProvider.notifier)
                            .build(brief, outline),
                      ),
                      onImprove: _improve,
                      onOpen: _open,
                    ),
                  ),
          ),
          _Composer(
            controller: _input,
            busy: state.busy,
            onSend: () {
              final text = _input.text;
              _input.clear();
              _guard(() => ref.read(assistantProvider.notifier).send(text));
            },
            onCourse: _createCourse,
          ),
        ],
      ),
    );
  }

  Future<void> _createCourse() async {
    final brief = await Navigator.of(context).push<CourseBrief>(
      MaterialPageRoute(builder: (_) => const CourseFormScreen()),
    );
    if (brief == null || !mounted) return;
    await _guard(
      () => ref.read(assistantProvider.notifier).requestOutline(brief),
    );
  }

  Future<void> _improve(String courseId) async {
    final instruction = await showDialog<String>(
      context: context,
      builder: (_) => const _ImproveDialog(),
    );
    if (instruction == null || !mounted) return;
    await _guard(
      () => ref.read(assistantProvider.notifier).improve(courseId, instruction),
    );
  }

  Future<void> _open(String? path) async {
    if (path == null) return;
    final result = await OpenFilex.open(path);
    if (result.type == ResultType.done || !mounted) return;

    // Beaucoup de téléphones n'ont aucune application bureautique : on dit
    // laquelle installer plutôt que d'afficher « échec de l'ouverture ».
    final word = path.endsWith('.docx');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          word
              ? 'Installez WPS Office ou Google Docs pour ouvrir ce fichier '
                    'Word.'
              : 'Installez WPS Office ou Google Sheets pour ouvrir ce '
                    'tableur.',
        ),
      ),
    );
  }
}

/// Premier affichage : ce que l'assistant sait faire, avec son coût.
///
/// Les propositions dépendent du profil : un professeur construit des cours,
/// une famille cherche des exercices et un programme de révision. Une liste
/// unique obligeait chacun à écarter la moitié de ce qu'on lui montrait.
class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onCreateCourse});

  final VoidCallback onCreateCourse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final role = ref.watch(currentSessionProvider)?.role;
    final professeur = role == UserRole.teacher;

    /// Ce qu'on propose, dans l'ordre où l'on s'en sert.
    final propositions = professeur
        ? const [
            (
              Icons.menu_book_outlined,
              'Crée un cours complet',
              'Six semaines de contenu, prêt à imprimer',
              true,
            ),
            (
              Icons.fact_check_outlined,
              'Corrige les exercices de mes élèves',
              'Photographiez une copie, recevez la correction',
              false,
            ),
          ]
        : const [
            (
              Icons.edit_note_outlined,
              'Génère un exercice',
              'Sur le programme guinéen, à la classe voulue',
              false,
            ),
            (
              Icons.fact_check_outlined,
              'Corrige un exercice',
              'Photographiez le devoir, recevez la correction',
              false,
            ),
            (
              Icons.event_note_outlined,
              'Propose un programme de révision',
              'Réparti sur les semaines qui restent',
              false,
            ),
          ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      children: [
        Text('Qu’est-ce qu’on fait aujourd’hui ?', style: text.headlineSmall),
        const Gap(AppSpacing.xl),
        for (final (icone, titre, detail, branche) in propositions) ...[
          AppCard(
            onTap: branche
                ? onCreateCourse
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cette fonction arrive avec la connexion au serveur.',
                      ),
                    ),
                  ),
            child: Row(
              children: [
                Icon(icone, color: AppColors.primary),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(detail, style: text.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
          const Gap(AppSpacing.md),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onBuild,
    required this.onImprove,
    required this.onOpen,
  });

  final AssistantMessage message;
  final void Function(CourseBrief, CourseOutline) onBuild;
  final void Function(String courseId) onImprove;
  final void Function(String? path) onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return switch (message) {
      UserMessage(:final text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md, left: 48),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ),

      AssistantText(:final text, :final isError) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md, right: 48),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isError ? AppColors.dangerSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(text),
      ),

      PendingMessage(:final label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),

      OutlineMessage(:final brief, :final outline) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md, right: 24),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(outline.title, style: text.titleMedium),
              Text(outline.audience, style: text.bodySmall),
              const Gap(AppSpacing.md),
              for (final chapter in outline.chapters)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chapter.title, style: text.titleSmall),
                      Text(chapter.summary, style: text.bodySmall),
                    ],
                  ),
                ),
              const Gap(AppSpacing.sm),
              Text(
                '${outline.recommendedExercises} exercices recommandés · '
                '${outline.definitionCount} définitions',
                style: text.bodySmall,
              ),
              const Gap(AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onBuild(brief, outline),
                  child: const Text('Construire le cours'),
                ),
              ),
            ],
          ),
        ),
      ),

      CourseMessage(:final course) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md, right: 24),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Votre cours est prêt',
                      style: text.titleMedium,
                    ),
                  ),
                  if (course.version > 1)
                    StatusPill(
                      label: 'v${course.version}',
                      tone: StatusTone.neutral,
                    ),
                ],
              ),
              const Gap(AppSpacing.sm),
              Text(course.title, style: text.titleSmall),
              Text(
                '${course.course.chapters.length} chapitres · '
                '${course.course.exercises.length} exercices · '
                '${course.course.definitions.length} définitions',
                style: text.bodySmall,
              ),
              const Gap(AppSpacing.lg),
              // Word en premier : c'est le fichier que le professeur rouvre
              // et corrige. L'Excel sert aux tableaux, il reste à portée.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onOpen(course.docxPath),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Télécharger en Word'),
                ),
              ),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onOpen(course.xlsxPath),
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('Excel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onImprove(course.courseId),
                      child: const Text('Améliorer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    };
  }
}

class _ImproveDialog extends StatefulWidget {
  const _ImproveDialog();

  @override
  State<_ImproveDialog> createState() => _ImproveDialogState();
}

class _ImproveDialogState extends State<_ImproveDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Améliorer ce cours'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: 'Ajoute 5 exercices sur le chapitre 3',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Envoyer à l’assistant'),
      ),
    ],
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onCourse,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onCourse;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          IconButton(
            onPressed: busy ? null : onCourse,
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Crée un cours complet',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Écrivez votre question…',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onSend,
            icon: const Icon(Icons.send),
            tooltip: 'Envoyer',
          ),
        ],
      ),
    ),
  );
}
