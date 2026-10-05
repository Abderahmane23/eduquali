import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/security/capture_analyzer.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Liste des controles de capture, cochee au fur et a mesure.
///
/// Un critère acquis le reste : la liste ne doit jamais clignoter, sans quoi
/// l'utilisateur perd confiance dans ce que l'application lui dit.
class CaptureChecklist extends StatelessWidget {
  const CaptureChecklist({super.key, required this.readiness});

  final CaptureReadiness readiness;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final check in readiness.checks) ...[
          _CheckRow(check: check),
          if (check != readiness.checks.last) const Gap(AppSpacing.md),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final CaptureCheck check;

  @override
  Widget build(BuildContext context) {
    final done = check.satisfied;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? AppColors.success : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? AppColors.success : AppColors.borderStrong,
              width: 1.6,
            ),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const Gap(AppSpacing.md),
        Expanded(
          child: Text(
            check.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: done ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cadre de visee : ovale pour un visage, rectangle pour un document.
class CaptureFrame extends StatelessWidget {
  const CaptureFrame({
    super.key,
    required this.target,
    required this.ready,
    this.previewPath,
  });

  final CaptureTarget target;
  final bool ready;

  /// Apercu de la capture déjà realisee, le cas echeant.
  final String? previewPath;

  @override
  Widget build(BuildContext context) {
    final isFace = target.requiresLiveness;
    final borderColor = ready ? AppColors.success : AppColors.borderStrong;
    final radius = isFace
        ? BorderRadius.circular(999)
        : BorderRadius.circular(AppRadius.lg);

    return AspectRatio(
      aspectRatio: isFace ? 0.78 : 1.5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: ready ? 2.4 : 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: previewPath != null
            ? Image.file(File(previewPath!), fit: BoxFit.cover)
            : _Placeholder(target: target, ready: ready),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.target, required this.ready});

  final CaptureTarget target;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final icon = switch (target) {
      CaptureTarget.selfie => Icons.face_outlined,
      CaptureTarget.diploma => Icons.workspace_premium_outlined,
      _ => Icons.badge_outlined,
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: ready ? AppColors.success : AppColors.textTertiary,
          ),
          const Gap(AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              // L'apercu camera temps reel remplacera ce reperage lors du
              // branchement de la detection embarquee.
              'Apercu camera',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau de consigne affiche sous le cadre.
class CaptureHint extends StatelessWidget {
  const CaptureHint({super.key, required this.readiness});

  final CaptureReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final ready = readiness.ready;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: ready ? AppColors.successSurface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.center_focus_weak,
            size: 18,
            color: ready ? AppColors.success : AppColors.textSecondary,
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              readiness.hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ready ? AppColors.success : AppColors.textSecondary,
                fontWeight: ready ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur d'étape « 2 / 4 » avec barre de progression.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.current,
    required this.total,
    required this.label,
  });

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Étape $current sur $total',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        ThinProgressBar(value: current / total),
      ],
    );
  }
}
