import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/job_models.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/common.dart';

/// Fiche publique d'un établissement (§19).
///
/// Ce qu'un parent ou un enseignant regarde avant de s'engager : depuis quand
/// il existe, qui le tient, ce qu'on y étudie, ce qu'on y trouve et comment
/// le joindre. L'ordre suit celui des questions qu'on se pose.
class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(institutionByIdProvider(institutionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Établissement')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Fiche indisponible',
          message: '$error',
        ),
        data: (institution) {
          if (institution == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Établissement introuvable',
              message: 'Cette fiche n’existe plus.',
            );
          }
          return _Body(institution: institution);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.institution});

  final InstitutionSummary institution;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final origin = institution.originLine;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                institution.name,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            if (institution.isVerified) ...[
              const Gap(AppSpacing.sm),
              const StatusPill(label: 'Vérifié', tone: StatusTone.success),
            ],
          ],
        ),
        const Gap(AppSpacing.xs),
        Text(
          [institution.type.label, ?origin].join(' · '),
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),

        if (institution.description != null) ...[
          const Gap(AppSpacing.lg),
          Text(
            institution.description!,
            style: text.bodyMedium?.copyWith(height: 1.5),
          ),
        ],

        // --- Études ---------------------------------------------------
        if (institution.academicSystem != null ||
            institution.degrees.isNotEmpty) ...[
          const Gap(AppSpacing.xxl),
          const SectionHeader(title: 'Études'),
          const Gap(AppSpacing.sm),
          if (institution.academicSystem != null)
            InfoRow(
              icon: Icons.school_outlined,
              label: 'Système',
              value: institution.academicSystem!,
            ),
          if (institution.degrees.isNotEmpty)
            InfoRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Diplômes',
              value: institution.degrees.join(' · '),
            ),
        ],

        if (institution.specialties.isNotEmpty) ...[
          const Gap(AppSpacing.xxl),
          SectionHeader(title: 'Filières (${institution.specialties.length})'),
          const Gap(AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final specialty in institution.specialties)
                TagChip(label: specialty),
            ],
          ),
        ],

        if (institution.facilities.isNotEmpty) ...[
          const Gap(AppSpacing.xxl),
          const SectionHeader(title: 'Sur le campus'),
          const Gap(AppSpacing.sm),
          for (final facility in institution.facilities)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const Gap(AppSpacing.xs),
                  Expanded(child: Text(facility, style: text.bodyMedium)),
                ],
              ),
            ),
        ],

        // --- Contact --------------------------------------------------
        const Gap(AppSpacing.xxl),
        const SectionHeader(title: 'Contact'),
        const Gap(AppSpacing.sm),
        if (institution.address != null)
          InfoRow(
            icon: Icons.place_outlined,
            label: 'Adresse',
            value: institution.address!,
          ),
        // Coordonnees selectionnables : sans `url_launcher`, au moins un
        // appui long permet de copier au lieu de recopier a la main.
        for (final number in [institution.phone, institution.phoneAlt])
          if (number != null)
            _CopyableRow(
              icon: Icons.call_outlined,
              label: 'Téléphone',
              value: number,
            ),
        if (institution.email != null)
          _CopyableRow(
            icon: Icons.mail_outline,
            label: 'E-mail',
            value: institution.email!,
          ),
        if (institution.website != null)
          _CopyableRow(
            icon: Icons.language_outlined,
            label: 'Site',
            value: institution.website!,
          ),
        const Gap(AppSpacing.xxxl),
      ],
    );
  }
}

/// Ligne de coordonnee, copiable d'un appui long.
class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                SelectableText(value, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
