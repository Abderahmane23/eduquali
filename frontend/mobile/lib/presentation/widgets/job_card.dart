import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/job_models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Carte d'offre d'emploi (§17).
///
/// Affiche l'établissement, le poste, la ville, les niveaux et la date de
/// publication, ainsi que la compatibilite lorsqu'elle est calculee (§22).
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.offer,
    this.onTap,
    this.showMatch = true,
  });

  final JobOffer offer;
  final VoidCallback? onTap;
  final bool showMatch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final salary = Fmt.salaryRange(
      offer.salaryMin,
      offer.salaryMax,
      published: offer.salaryPublished,
    );

    return AppCard(
      onTap: onTap,
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
                    Text(
                      offer.title,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            offer.institution.name,
                            style: text.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (offer.institution.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (offer.levels.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                TagChip(label: offer.levelLabel, tone: StatusTone.primary),
              ],
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 3),
              Text(offer.city, style: text.bodySmall),
              const SizedBox(width: 12),
              const Icon(
                Icons.work_outline,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  offer.contractType.shortLabel,
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (salary != null) ...[
            const SizedBox(height: 8),
            Text(
              salary,
              style: text.titleSmall?.copyWith(color: AppColors.primary),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Text(Fmt.publishedOn(offer.publishedAt), style: text.labelSmall),
              const Spacer(),
              if (offer.isPrivate) ...[
                const TagChip(
                  label: 'Offre privee',
                  icon: Icons.lock_outline,
                  tone: StatusTone.warning,
                ),
                const SizedBox(width: 6),
              ],
              if (offer.hasApplied)
                const TagChip(
                  label: 'Candidature envoyée',
                  icon: Icons.check,
                  tone: StatusTone.success,
                )
              else if (showMatch && offer.matchScore != null)
                _MatchChip(value: offer.matchScore!.value),
            ],
          ),
        ],
      ),
    );
  }
}

/// Puce de compatibilite — le score doit rester explicable (§22).
class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final tone = value >= 75
        ? StatusTone.success
        : value >= 50
        ? StatusTone.info
        : StatusTone.neutral;

    return TagChip(
      label: 'Compatibilite $value %',
      icon: Icons.insights_outlined,
      tone: tone,
    );
  }
}
