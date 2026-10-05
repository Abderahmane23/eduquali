import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/security/identity_checks.dart';
import '../../../data/repositories/verification_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Ecrans 9 a 13 — Vérification de l'identité (§6).
///
/// Étape 1 : selfie avec controles de qualite.
/// Étape 2 : piece d'identité recto et verso.
class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  bool _busy = false;
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(identityStateProvider);
    final documents = ref.watch(documentsProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification d’identité'),
        leading: const BackButton(),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'État indisponible',
          message: '$error',
        ),
        data: (state) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _StatusHeader(status: state.status),
            const Gap(AppSpacing.xl),

            Text(
              'Ces documents servent uniquement a vérifier votre identité. '
              'Ils sont chiffres et ne sont jamais affiches aux '
              'établissements.',
              style: text.bodyMedium,
            ),
            const Gap(AppSpacing.xl),

            // Parcours guide : controles de cadrage et d'éclairage avant la
            // prise de vue, plutot qu'un rejet après coup.
            AppCard(
              color: AppColors.primarySurface,
              borderColor: AppColors.primarySurface,
              onTap: () => context.push(Routes.teacherIdentityFlow),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.primary,
                  ),
                  const Gap(AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vérification guidee',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const Gap(AppSpacing.xs),
                        Text(
                          'Consentement, selfie et piece d’identité, étape par '
                          'étape. Mode démonstration : rien n’est transmis.',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ),
            const Gap(AppSpacing.xl),

            // Étape 1 — selfie.
            _StepCard(
              step: 1,
              title: 'Selfie',
              description:
                  'Prenez une photo de votre visage, dans un endroit bien '
                  'eclaire, sans lunettes de soleil ni couvre-chef.',
              done: state.hasSelfie,
              busy: _busy,
              previewPath: _pathFor(documents, DocumentType.selfie),
              actionLabel: state.hasSelfie ? 'Reprendre' : 'Prendre un selfie',
              onAction: _captureSelfie,
            ),
            const Gap(AppSpacing.md),

            // Étape 2 — piece d'identité.
            _StepCard(
              step: 2,
              title: 'Piece d’identité',
              description:
                  'Photographiez le recto de votre piece d’identité, puis le '
                  'verso si necessaire. Les informations seront extraites '
                  'automatiquement.',
              done: state.hasIdCard,
              busy: _busy,
              previewPath: _pathFor(documents, DocumentType.idFront),
              actionLabel: state.hasIdCard
                  ? 'Reprendre le recto'
                  : 'Photographier le recto',
              onAction: () => _captureIdCard(back: false),
              secondaryLabel: state.hasIdCard
                  ? (state.idBackDocumentId == null
                        ? 'Ajouter le verso'
                        : 'Reprendre le verso')
                  : null,
              onSecondary: () => _captureIdCard(back: true),
            ),

            if (_feedback != null) ...[
              const Gap(AppSpacing.lg),
              InfoBanner(
                message: _feedback!,
                tone: StatusTone.warning,
                icon: Icons.info_outline,
              ),
            ],

            // Informations extraites, presentees pour vérification (§6).
            if (state.extracted case final data? when !data.isEmpty) ...[
              const Gap(AppSpacing.xl),
              Text('Informations extraites', style: text.titleMedium),
              const Gap(AppSpacing.md),
              AppCard(child: _ExtractedFields(data: data)),
            ],

            const Gap(AppSpacing.xl),
            const InfoBanner(
              title: 'Protection de vos données',
              message:
                  'Les données issues de votre piece d’identité ne figurent '
                  'dans aucun journal applicatif et sont conservees selon la '
                  'politique de conservation en vigueur.',
              tone: StatusTone.neutral,
              icon: Icons.lock_outline,
            ),
          ],
        ),
      ),
    );
  }

  String? _pathFor(List<DocumentItem> documents, DocumentType type) =>
      documents.where((d) => d.type == type).firstOrNull?.localPath;

  Future<void> _captureSelfie() async {
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() {
      _busy = true;
      _feedback = null;
    });

    try {
      final captured = await ref
          .read(documentPipelineProvider)
          .captureFromCamera(DocumentType.selfie, frontCamera: true);
      if (captured == null) return;

      final result = await ref
          .read(verificationRepositoryProvider)
          .submitSelfie(teacherId: teacherId, captured: captured);

      if (!mounted) return;
      setState(() => _feedback = result.passed ? null : result.message);
      ref.invalidate(documentsProvider);
    } catch (error) {
      if (mounted) setState(() => _feedback = 'Capture impossible : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureIdCard({required bool back}) async {
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() {
      _busy = true;
      _feedback = null;
    });

    try {
      final pipeline = ref.read(documentPipelineProvider);
      final captured = await pipeline.captureFromCamera(
        back ? DocumentType.idBack : DocumentType.idFront,
      );
      if (captured == null) return;

      final repository = ref.read(verificationRepositoryProvider);
      if (back) {
        await repository.storeDocument(
          teacherId: teacherId,
          captured: captured,
        );
      } else {
        await repository.submitIdCard(teacherId: teacherId, front: captured);
      }

      if (!mounted) return;
      ref.invalidate(documentsProvider);
    } catch (error) {
      if (mounted) setState(() => _feedback = 'Capture impossible : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, message) = switch (status) {
      VerificationStatus.verified => (
        StatusTone.success,
        Icons.verified,
        'Votre identité a ete vérifiée.',
      ),
      VerificationStatus.inReview => (
        StatusTone.info,
        Icons.hourglass_top,
        'Vos documents sont en cours de vérification. Vous serez notifie du '
            'résultat.',
      ),
      VerificationStatus.rejected => (
        StatusTone.danger,
        Icons.cancel_outlined,
        'Vos documents ont ete rejetes. Reprenez les photos en suivant les '
            'consignes.',
      ),
      VerificationStatus.needsFix => (
        StatusTone.warning,
        Icons.error_outline,
        'Des corrections sont necessaires avant validation.',
      ),
      _ => (
        StatusTone.neutral,
        Icons.badge_outlined,
        'Completez les deux étapes pour obtenir le badge « Identité vérifiée ».',
      ),
    };

    return InfoBanner(
      title: status.label,
      message: message,
      tone: tone,
      icon: icon,
    );
  }
}

/// Étape du parcours de vérification, avec apercu du document capture.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.done,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
    this.previewPath,
    this.secondaryLabel,
    this.onSecondary,
  });

  final int step;
  final String title;
  final String description;
  final bool done;
  final bool busy;
  final String actionLabel;
  final VoidCallback onAction;
  final String? previewPath;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasPreview = previewPath != null && File(previewPath!).existsSync();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.successSurface
                      : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.success,
                      )
                    : Text(
                        '$step',
                        style: text.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: text.titleMedium)),
              if (done)
                const TagChip(
                  label: 'Ajouté',
                  icon: Icons.check,
                  tone: StatusTone.success,
                ),
            ],
          ),

          const SizedBox(height: 10),
          Text(description, style: text.bodySmall),

          if (hasPreview) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.file(
                File(previewPath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onAction,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(actionLabel, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onSecondary,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(
                      secondaryLabel!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtractedFields extends StatelessWidget {
  const _ExtractedFields({required this.data});

  final IdCardData data;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Nom', data.lastName),
      ('Prenom', data.firstName),
      ('Numéro de piece', data.documentNumber),
      ('Nationalite', data.nationality),
      ('Sexe', data.sex),
    ];

    return Column(
      children: [
        for (final (label, value) in rows)
          if (value != null && value.isNotEmpty)
            InfoRow(label: label, value: value),
        if (data.confidence == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'L’extraction automatique sera complétée par le serveur lors de '
              'la vérification.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}
