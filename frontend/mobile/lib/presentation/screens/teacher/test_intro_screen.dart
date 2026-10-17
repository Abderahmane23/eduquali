import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 19 — Presentation du test (§10.2).
///
/// Annonce le nombre de questions, la durée, les règles, le score minimum et
/// les consequences de la validation avant de demarrer.
class TestIntroScreen extends ConsumerStatefulWidget {
  const TestIntroScreen({super.key, required this.testId});

  final String testId;

  @override
  ConsumerState<TestIntroScreen> createState() => _TestIntroScreenState();
}

class _TestIntroScreenState extends ConsumerState<TestIntroScreen> {
  bool _starting = false;

  Future<void> _start() async {
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() => _starting = true);
    try {
      final sessionId = await ref
          .read(testRepositoryProvider)
          .startSession(testId: widget.testId, teacherId: teacherId);
      if (!mounted) return;
      context.pushReplacement('/teacher/session/$sessionId');
    } catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Demarrage impossible : $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final testAsync = ref.watch(testSummaryProvider(widget.testId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: testAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Test indisponible',
          message: '$error',
        ),
        data: (test) {
          if (test == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Test introuvable',
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 27,
                        color: AppColors.primary,
                      ),
                    ),
                    const Gap(AppSpacing.xl),

                    Text(
                      'Passer le test\nde compétence',
                      style: text.headlineMedium,
                    ),
                    const Gap(AppSpacing.xl),

                    Text(
                      'Test : ${test.subject.name}',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: text.titleMedium,
                        children: [
                          const TextSpan(text: 'Niveau : '),
                          TextSpan(
                            text: test.level.name,
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.xl),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          _IntroRow(
                            icon: Icons.checklist_outlined,
                            label: '${test.questionCount} questions',
                          ),
                          const SizedBox(height: 12),
                          _IntroRow(
                            icon: Icons.schedule,
                            label: '${test.durationMinutes} minutes',
                          ),
                          const SizedBox(height: 12),
                          const _IntroRow(
                            icon: Icons.workspace_premium_outlined,
                            label: 'Évaluation par matière et niveau',
                          ),
                          const SizedBox(height: 12),
                          _IntroRow(
                            icon: Icons.flag_outlined,
                            label: 'Score minimum : ${test.passingScore} %',
                          ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.xl),

                    Text('Règles du test', style: text.titleMedium),
                    const Gap(AppSpacing.md),
                    Text(
                      test.rules ??
                          'Test individuel et chronomètre. Une seule réponse '
                              'par question. Les réponses ne sont plus '
                              'modifiables après soumission.',
                      style: text.bodyMedium,
                    ),

                    const Gap(AppSpacing.xl),

                    // Le test reste utilisable sans connexion (§11).
                    const InfoBanner(
                      title: 'Fonctionne hors ligne',
                      message:
                          'Les questions sont telechargees avant le demarrage. '
                          'Si la connexion est perdue, le test continue et vos '
                          'réponses sont enregistrees sur l’appareil, puis '
                          'synchronisees automatiquement.',
                      tone: StatusTone.info,
                      icon: Icons.wifi_off_outlined,
                    ),

                    const Gap(AppSpacing.lg),

                    if (test.isCertified)
                      InfoBanner(
                        title: 'Déjà certifié a ${test.certification!.score} %',
                        message:
                            'Repasser le test remplacera votre certification '
                            'actuelle pour ${test.subject.name} — '
                            '${test.level.name}.',
                        tone: StatusTone.warning,
                      )
                    else
                      Text(
                        'En cas de réussite, une certification « ${test.subject.name} — '
                        '${test.level.name} » sera ajoutee a votre profil et '
                        'visible par les établissements.',
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _starting ? null : _start,
                    child: _starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            test.canResume
                                ? 'Reprendre le test'
                                : 'Commencer le test',
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroRow extends StatelessWidget {
  const _IntroRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.primary),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 14.5,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
