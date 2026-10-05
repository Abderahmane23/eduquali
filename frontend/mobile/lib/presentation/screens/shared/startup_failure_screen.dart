import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/startup_report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// L'écran montré quand le démarrage a échoué sur une étape indispensable.
///
/// Il remplace ce que voyait l'utilisateur le 25/09 : le logo du lanceur
/// Android, immobile, sans message. Une application qui s'ouvre sur une
/// erreur peut être décrite au support ; une application qui reste sur le
/// logo ne peut pas.
///
/// Le message technique est affiché **tel quel** et se copie d'un appui.
/// C'est laid, et c'est voulu : la phrase rassurante qui le remplacerait ne
/// se diagnostique pas, et personne ne peut brancher le téléphone d'un
/// parent à Conakry sur un poste de développement.
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({super.key, required this.report});

  final StartupReport report;

  String get _rapport => [
    'Eduquali ${AppConstants.appName}',
    for (final issue in report.issues) '- ${issue.step} : ${issue.message}',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.section,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: AppColors.danger,
              ),
              const Gap(AppSpacing.lg),
              Text(
                'L’application n’a pas pu démarrer',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Gap(AppSpacing.md),
              const Text(
                'Fermez l’application et rouvrez-la. Si le message revient, '
                'envoyez-nous le texte ci-dessous : c’est lui qui dit ce qui '
                'bloque.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const Gap(AppSpacing.xl),
              for (final issue in report.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    color: AppColors.dangerSurface,
                    borderColor: AppColors.dangerSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.step,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          issue.message,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Gap(AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _rapport));
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(content: Text('Message copié')),
                    );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copier le message'),
              ),
              const Gap(AppSpacing.md),
              Text(
                'Assistance : ${AppConstants.supportPhone}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
