import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_enums.dart';
import '../../core/utils/formatters.dart';
import '../theme/app_theme.dart';
import 'interactions.dart';

/// La carte de l'application.
///
/// Redessinee le 23/09 : coins larges, ombre a deux couches, plus de trait.
/// Le trait servait a detacher une carte blanche d'un fond blanc ; le fond de
/// page est desormais lavande, l'ombre suffit, et la page est nettement plus
/// calme sans trente traits gris.
///
/// C'est volontairement le meme composant qu'avant et non un nouveau : les
/// trente-quatre ecrans qui l'utilisent heritent du nouveau dessin sans etre
/// touches, et ne peuvent donc pas diverger.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.card,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Le trait ne revient que si on le demande explicitement — une carte
        // d'avertissement, par exemple, qui doit se distinguer des autres.
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return content;
    // La carte s'enfonce sous le doigt, et c'est tout : l'ondulation de
    // l'`InkWell` se voit mal quand le doigt recouvre l'endroit touche, et
    // superposer les deux mettrait deux detecteurs de tap dans l'arene —
    // celui du dessous gagne, celui du dessus reste enfonce.
    return Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: content,
    );
  }
}

/// Badge de confiance (§14) — coche verte et libelle.
class TrustBadgeChip extends StatelessWidget {
  const TrustBadgeChip({super.key, required this.badge, this.compact = false});

  final TrustBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 13, color: AppColors.success),
            const SizedBox(width: 4),
            Text(
              badge.label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        const Icon(Icons.check_circle, size: 19, color: AppColors.success),
        const SizedBox(width: 10),
        Text(badge.label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

/// Puce de statut coloree selon la semantique du statut.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  StatusPill.verification(VerificationStatus status, {super.key})
    : label = status.label,
      tone = switch (status) {
        VerificationStatus.verified => StatusTone.success,
        VerificationStatus.rejected => StatusTone.danger,
        VerificationStatus.needsFix => StatusTone.warning,
        VerificationStatus.inReview => StatusTone.info,
        VerificationStatus.pending => StatusTone.neutral,
        VerificationStatus.none => StatusTone.neutral,
      },
      icon = switch (status) {
        VerificationStatus.verified => Icons.verified,
        VerificationStatus.rejected => Icons.cancel_outlined,
        VerificationStatus.needsFix => Icons.error_outline,
        VerificationStatus.inReview => Icons.hourglass_top,
        _ => Icons.schedule,
      };

  StatusPill.application(ApplicationStatus status, {super.key})
    : label = status.label,
      tone = switch (status) {
        ApplicationStatus.hired ||
        ApplicationStatus.accepted => StatusTone.success,
        ApplicationStatus.rejected ||
        ApplicationStatus.withdrawn => StatusTone.danger,
        ApplicationStatus.shortlisted ||
        ApplicationStatus.interview ||
        ApplicationStatus.offerReceived => StatusTone.info,
        _ => StatusTone.neutral,
      },
      icon = null;

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.success => (AppColors.successSurface, AppColors.success),
      StatusTone.warning => (AppColors.warningSurface, AppColors.warning),
      StatusTone.danger => (AppColors.dangerSurface, AppColors.danger),
      StatusTone.info => (AppColors.infoSurface, AppColors.info),
      StatusTone.primary => (AppColors.primarySurface, AppColors.primary),
      StatusTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { success, warning, danger, info, primary, neutral }

/// Anneau de progression — completion du profil (§16) et score (§12).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 5,
    this.color = AppColors.primary,
    this.trackColor,
    this.child,
  });

  /// Valeur de 0 a 1.
  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value.clamp(0, 1),
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: trackColor ?? AppColors.border,
          ),
        ),
        ?child,
      ],
    ),
  );
}

/// Avatar avec repli sur les initiales.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    this.photoPath,
    this.size = 48,
  });

  final String firstName;
  final String lastName;
  final String? photoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && File(photoPath!).existsSync();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
      ),
      child: hasPhoto
          ? Image.file(
              File(photoPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Center(
    child: Text(
      Fmt.initials(firstName, lastName),
      style: TextStyle(
        fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
  );
}

/// Titre de section avec action optionnelle.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // La puce du 23/09 : dans une page sans barres de separation, c'est
      // elle qui marque le debut d'un bloc. Posee ici plutot que recopiee
      // dans chaque ecran, pour que les blocs restent alignes entre eux.
      Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(top: 9, right: AppSpacing.sm),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      if (actionLabel != null && onAction != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}

/// État vide, avec action de rattrapage.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Le rond porte la couleur principale : un ecran vide est le
          // premier qu'on voit, et un rond gris sur fond gris donne
          // l'impression que l'application n'a pas fini de charger.
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, AppSpacing.touchTarget + 4),
                backgroundColor: AppColors.primarySurface,
                foregroundColor: AppColors.primary,
                elevation: 0,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Ligne d'information « libelle : valeur ».
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: AppColors.textTertiary),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 4,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: valueColor),
          ),
        ),
      ],
    ),
  );
}

/// Bandeau d'information contextuel.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.title,
  });

  final String message;
  final String? title;
  final StatusTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.success => (AppColors.successSurface, AppColors.success),
      StatusTone.warning => (AppColors.warningSurface, AppColors.warning),
      StatusTone.danger => (AppColors.dangerSurface, AppColors.danger),
      StatusTone.info => (AppColors.infoSurface, AppColors.info),
      StatusTone.primary => (AppColors.primarySurface, AppColors.primary),
      StatusTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, size: 19, color: fg),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: fg.withValues(alpha: 0.92),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          decoration: TextDecoration.underline,
                          decorationColor: fg,
                        ),
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
}

/// Ligne de statistique compacte pour les tableaux de bord (§20).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    this.icon,
    this.onTap,
    this.tone = StatusTone.neutral,
  });

  final String value;
  final String label;

  /// Une précision courte, quand le chiffre seul se lit de travers :
  /// « Faites sur prévues », « 12 j pour recruter ».
  final String? hint;

  final IconData? icon;
  final VoidCallback? onTap;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      StatusTone.primary => AppColors.primary,
      StatusTone.success => AppColors.success,
      StatusTone.warning => AppColors.warning,
      StatusTone.danger => AppColors.danger,
      StatusTone.info => AppColors.info,
      StatusTone.neutral => AppColors.textPrimary,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(height: AppSpacing.sm),
          ],
          // Un montant guinéen s'écrit en millions : « 12 500 000 GNF » ne
          // tient pas dans une demi-largeur. Il rétrécit plutôt que d'être
          // coupé — un chiffre tronqué se lit de travers, un chiffre plus
          // petit se lit quand même.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (hint != null)
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }
}

/// Barre de progression fine, utilisee pendant le test (§10.3).
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color = AppColors.primary,
  });

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: height,
      color: color,
      backgroundColor: AppColors.border,
    ),
  );
}

/// Puce d'etiquette neutre (matière, niveau, ville).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final IconData? icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.primary => (AppColors.primarySurface, AppColors.primary),
      StatusTone.success => (AppColors.successSurface, AppColors.success),
      StatusTone.warning => (AppColors.warningSurface, AppColors.warning),
      StatusTone.danger => (AppColors.dangerSurface, AppColors.danger),
      StatusTone.info => (AppColors.infoSurface, AppColors.info),
      StatusTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur de score circulaire large (§12).
class ScoreDial extends StatelessWidget {
  const ScoreDial({
    super.key,
    required this.score,
    this.caption = 'Score obtenu',
    this.size = 200,
    this.passed = true,
  });

  final int score;
  final String caption;
  final double size;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.primary : AppColors.warning;
    return ProgressRing(
      value: score / 100,
      size: size,
      strokeWidth: math.max(10, size * 0.055),
      color: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score %',
            style: TextStyle(
              fontSize: size * 0.21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Espace vertical standard entre sections.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}
