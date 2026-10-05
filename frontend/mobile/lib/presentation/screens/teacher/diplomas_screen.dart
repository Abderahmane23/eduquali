import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactions.dart';
import '../../widgets/common.dart';

/// Écran 12 — Diplômes (§7).
class DiplomasScreen extends ConsumerWidget {
  const DiplomasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentTeacherProfileProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diplômes'),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/diplomas/add'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: profileAsync.when(
        loading: () => const SkeletonDashboard(cards: [3]),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          if (profile.diplomas.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: 'Aucun diplôme',
              message:
                  'Ajoutez votre diplôme et son justificatif pour obtenir le '
                  'badge « Diplôme vérifié ».',
              actionLabel: 'Ajouter un diplôme',
              onAction: () => context.push('/teacher/diplomas/add'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              Text(
                'Chaque diplôme est controle par notre equipe. Un justificatif '
                'lisible accéléré la vérification.',
                style: text.bodyMedium,
              ),
              const Gap(AppSpacing.xl),
              for (final diploma in profile.diplomas)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _DiplomaCard(
                    diploma: diploma,
                    onDelete: () => _confirmDelete(
                      context,
                      ref,
                      profile.teacherId,
                      diploma,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String teacherId,
    DiplomaItem diploma,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce diplôme ?'),
        content: Text(
          '« ${diploma.diplomaType} — ${diploma.institutionName} » ainsi que '
          'son justificatif seront supprimes de votre appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(verificationRepositoryProvider)
        .deleteDiploma(teacherId, diploma.id);
    ref.invalidate(documentsProvider);
  }
}

class _DiplomaCard extends StatelessWidget {
  const _DiplomaCard({required this.diploma, required this.onDelete});

  final DiplomaItem diploma;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(diploma.diplomaType, style: text.titleMedium),
                    const SizedBox(height: 3),
                    Text(diploma.institutionName, style: text.bodyMedium),
                  ],
                ),
              ),
              StatusPill.verification(diploma.status),
            ],
          ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TagChip(label: '${diploma.graduationYear}'),
              if (diploma.field != null) TagChip(label: diploma.field!),
              if (diploma.speciality != null)
                TagChip(label: diploma.speciality!),
              if (diploma.documentId == null)
                const TagChip(
                  label: 'Justificatif manquant',
                  icon: Icons.warning_amber_outlined,
                  tone: StatusTone.warning,
                ),
            ],
          ),

          if (diploma.status == VerificationStatus.rejected &&
              diploma.rejectionReason != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              message: diploma.rejectionReason!,
              tone: StatusTone.danger,
              icon: Icons.error_outline,
            ),
          ],

          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
