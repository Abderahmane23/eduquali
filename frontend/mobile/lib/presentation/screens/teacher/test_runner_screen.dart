import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/test_models.dart';
import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 20 — Passage du test (§10.3).
///
/// Le chronomètre et l'enregistrement des réponses fonctionnent sans
/// connexion (§11) ; la progression est sauvegardee regulierement afin de
/// survivre a une interruption.
class TestRunnerScreen extends ConsumerWidget {
  const TestRunnerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(testSessionProvider(sessionId));

    return PopScope(
      // Quitter le test doit etre un choix explicite.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit(context);
        if (leave == true && context.mounted) context.pop();
      },
      child: Scaffold(
        body: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Session indisponible',
            message: '$error',
          ),
          data: (session) {
            if (session == null) {
              return const EmptyState(
                icon: Icons.help_outline,
                title: 'Session introuvable',
              );
            }
            if (session.questions.isEmpty) {
              return const EmptyState(
                icon: Icons.help_outline,
                title: 'Aucune question disponible',
                message:
                    'La banque de questions de ce test n’a pas pu etre chargee.',
              );
            }
            return _RunnerBody(session: session, sessionId: sessionId);
          },
        ),
      ),
    );
  }

  Future<bool?> _confirmExit(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Quitter le test ?'),
      content: const Text(
        'Votre progression est enregistree sur l’appareil. Vous pourrez '
        'reprendre le test la ou vous vous etes arrete.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Continuer le test'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Quitter'),
        ),
      ],
    ),
  );
}

class _RunnerBody extends ConsumerWidget {
  const _RunnerBody({required this.session, required this.sessionId});

  final TestSessionData session;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final controller = ref.read(testSessionProvider(sessionId).notifier);
    final question = session.currentQuestion;
    final selected = session.answers[question.id];

    // Sous une minute, le chronomètre passe en alerte.
    final urgent = session.remainingSeconds <= 60;

    return SafeArea(
      child: Column(
        children: [
          // En-tete : titre, chronomètre et progression.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Retour',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test en cours', style: text.titleMedium),
                      Text(
                        '${session.test.subject.name} - ${session.test.level.name}',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: urgent
                        ? AppColors.dangerSurface
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: urgent
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        Fmt.clock(session.remainingSeconds),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: urgent
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text(
                  'Question ${session.currentIndex + 1} / ${session.questions.length}',
                  style: text.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${session.answeredCount} repondue(s)',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: ThinProgressBar(value: session.progress),
          ),

          // Énoncé et options.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  question.statement,
                  style: text.titleLarge?.copyWith(height: 1.4),
                ),
                const Gap(AppSpacing.xl),

                for (final option in question.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _OptionTile(
                      option: option,
                      selected: selected == option.key,
                      enabled: session.status == TestSessionStatus.inProgress,
                      onTap: () => controller.answer(question.id, option.key),
                    ),
                  ),

                const Gap(AppSpacing.lg),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _openNavigator(context, ref),
                    icon: const Icon(Icons.grid_view_outlined, size: 17),
                    label: const Text('Voir toutes les questions'),
                  ),
                ),
              ],
            ),
          ),

          // Navigation entre questions.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (session.currentIndex > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.previous,
                      child: const Text('Precedent'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: session.isLastQuestion
                        ? () => _confirmSubmit(context, ref, session)
                        : controller.next,
                    child: Text(
                      session.isLastQuestion
                          ? 'Terminer le test'
                          : 'Question suivante',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNavigator(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuestionGrid(sessionId: sessionId),
    );
  }

  Future<void> _confirmSubmit(
    BuildContext context,
    WidgetRef ref,
    TestSessionData session,
  ) async {
    final unanswered = session.questions.length - session.answeredCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminer le test ?'),
        content: Text(
          unanswered > 0
              ? 'Il reste $unanswered question(s) sans réponse. Elles seront '
                    'comptees comme incorrectes.\n\nLes réponses ne sont plus '
                    'modifiables après soumission.'
              : 'Vous avez repondu a toutes les questions.\n\nLes réponses ne '
                    'sont plus modifiables après soumission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revenir au test'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(testSessionProvider(sessionId).notifier).submit();
    if (!context.mounted) return;
    context.pushReplacement('/teacher/result/$sessionId');
  }
}

/// Option de réponse — reprend la maquette (pastille A/B/C/D + radio).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AnswerOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  option.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.primary : AppColors.borderStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille de navigation entre les questions.
class _QuestionGrid extends ConsumerWidget {
  const _QuestionGrid({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(testSessionProvider(sessionId)).valueOrNull;
    if (session == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(AppSpacing.xl),
            Text('Questions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${session.answeredCount} sur ${session.questions.length} repondue(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Gap(AppSpacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < session.questions.length; i++)
                      _GridCell(
                        index: i,
                        answered:
                            session.answers[session.questions[i].id] != null,
                        current: i == session.currentIndex,
                        onTap: () {
                          ref
                              .read(testSessionProvider(sessionId).notifier)
                              .goTo(i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.index,
    required this.answered,
    required this.current,
    required this.onTap,
  });

  final int index;
  final bool answered;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = current
        ? (AppColors.primary, Colors.white, AppColors.primary)
        : answered
        ? (
            AppColors.primarySurface,
            AppColors.primary,
            AppColors.primarySurface,
          )
        : (AppColors.background, AppColors.textSecondary, AppColors.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: border),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
