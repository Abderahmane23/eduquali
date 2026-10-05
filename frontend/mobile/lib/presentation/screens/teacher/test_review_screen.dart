import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/feature_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Detail des réponses après correction (§12 — « Voir le detail »).
class TestReviewScreen extends ConsumerWidget {
  const TestReviewScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(testReviewProvider(sessionId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail des réponses'),
        leading: const BackButton(),
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Detail indisponible',
          message: '$error',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Aucune réponse enregistree',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.md),
            itemBuilder: (_, index) {
              final item = items[index];
              final question = item.question;
              final correctOption = question.options.firstWhere(
                (o) => o.key == question.correctKey,
                orElse: () => question.options.first,
              );

              return AppCard(
                borderColor: item.correct
                    ? AppColors.successSurface
                    : AppColors.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.correct ? Icons.check_circle : Icons.cancel,
                          size: 19,
                          color: item.correct
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question ${index + 1} · ${question.domain}',
                                style: text.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                question.statement,
                                style: text.titleSmall?.copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (item.given == null)
                      const TagChip(
                        label: 'Sans réponse',
                        icon: Icons.remove_circle_outline,
                        tone: StatusTone.warning,
                      )
                    else if (!item.correct)
                      _AnswerLine(
                        label: 'Votre réponse',
                        value: _optionText(question.options, item.given!),
                        tone: StatusTone.danger,
                      ),

                    if (!item.correct) const SizedBox(height: 8),
                    _AnswerLine(
                      label: 'Bonne réponse',
                      value: '${correctOption.key}. ${correctOption.text}',
                      tone: StatusTone.success,
                    ),

                    if (question.explanation != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          question.explanation!,
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _optionText(List<dynamic> options, String key) {
    for (final option in options) {
      if (option.key == key) return '${option.key}. ${option.text}';
    }
    return key;
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusTone.success => AppColors.success,
      StatusTone.danger => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
