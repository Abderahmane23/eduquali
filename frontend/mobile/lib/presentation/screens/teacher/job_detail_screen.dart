import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/entities/job_models.dart';
import '../../../domain/usecases/matching_engine.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';

/// Ecrans 24 et 25 — Detail de l'offre et candidature (§17, §18).
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Offre indisponible',
          message: '$error',
        ),
        data: (offer) {
          if (offer == null) {
            return const EmptyState(
              icon: Icons.work_off_outlined,
              title: 'Offre introuvable',
            );
          }

          final salary = Fmt.salaryRange(
            offer.salaryMin,
            offer.salaryMax,
            published: offer.salaryPublished,
          );

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // L'en-tete reprend ce que portait la carte de la liste,
                    // en grand : on reconnait ce sur quoi on vient de taper.
                    GradientHero(
                      onBack: () => Navigator.of(context).maybePop(),
                      title: offer.title,
                      subtitle: offer.institution.isVerified
                          ? '${offer.institution.name} · vérifié'
                          : offer.institution.name,
                      bottom: salary == null
                          ? null
                          : HeroStatStrip(
                              items: [
                                (value: salary, label: 'Par mois'),
                                (
                                  value: offer.contractType.shortLabel,
                                  label: 'Contrat',
                                ),
                                (value: offer.city, label: 'Lieu'),
                              ],
                            ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              TagChip(
                                label: offer.city,
                                icon: Icons.location_on_outlined,
                              ),
                              TagChip(
                                label: offer.contractType.label,
                                icon: Icons.work_outline,
                              ),
                              TagChip(
                                label: offer.subject.name,
                                tone: StatusTone.primary,
                              ),
                              for (final level in offer.levels)
                                TagChip(
                                  label: level.name,
                                  tone: StatusTone.primary,
                                ),
                              if (offer.isPrivate)
                                const TagChip(
                                  label: 'Offre privee',
                                  icon: Icons.lock_outline,
                                  tone: StatusTone.warning,
                                ),
                            ],
                          ),

                          // Compatibilite expliquee (§22, §61).
                          if (offer.matchScore case final match?) ...[
                            const Gap(AppSpacing.xl),
                            _MatchBreakdown(match: match),
                          ],

                          if (offer.description != null) ...[
                            const Gap(AppSpacing.xl),
                            Text(
                              'Description du poste',
                              style: text.titleMedium,
                            ),
                            const Gap(AppSpacing.md),
                            Text(
                              offer.description!,
                              style: text.bodyLarge?.copyWith(fontSize: 15),
                            ),
                          ],

                          const Gap(AppSpacing.xl),
                          Text('Details', style: text.titleMedium),
                          const Gap(AppSpacing.md),
                          AppCard(
                            child: Column(
                              children: [
                                InfoRow(
                                  label: 'Expérience requise',
                                  value: offer.minExperience == 0
                                      ? 'Non precisee'
                                      : '${offer.minExperience} an(s) minimum',
                                ),
                                const Divider(height: 20),
                                InfoRow(
                                  label: 'Certification',
                                  value: offer.requiresCertification
                                      ? 'Exigee pour ce poste'
                                      : 'Non exigee',
                                ),
                                if (offer.startDate != null) ...[
                                  const Divider(height: 20),
                                  InfoRow(
                                    label: 'Prise de poste',
                                    value: Fmt.date(offer.startDate!),
                                  ),
                                ],
                                const Divider(height: 20),
                                InfoRow(
                                  label: 'Publiée',
                                  value: Fmt.relative(offer.publishedAt),
                                ),
                                const Divider(height: 20),
                                InfoRow(
                                  label: 'Candidatures reçues',
                                  value: '${offer.applicationCount}',
                                ),
                              ],
                            ),
                          ),

                          if (offer.institution.description != null) ...[
                            const Gap(AppSpacing.xl),
                            Text('L’établissement', style: text.titleMedium),
                            const Gap(AppSpacing.md),
                            Text(
                              offer.institution.description!,
                              style: text.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Le bouton ne bouge pas : sur une offre longue, il fallait
              // tout derouler pour savoir qu'on pouvait candidater.
              StickyActionBar(
                label: offer.hasApplied
                    ? 'Candidature envoyée'
                    : !offer.isOpen
                    ? 'Offre clôturée'
                    : 'Candidater',
                busy: _applying,
                note: offer.hasApplied || !offer.isOpen
                    ? null
                    : '${offer.applicationCount} candidature'
                          '${offer.applicationCount > 1 ? "s" : ""} reçue'
                          '${offer.applicationCount > 1 ? "s" : ""}',
                onPressed: offer.hasApplied || !offer.isOpen
                    ? null
                    : () => _confirmApply(offer),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmApply(JobOffer offer) async {
    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
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
                Text(
                  'Candidater',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const Gap(AppSpacing.sm),
                Text(
                  '${offer.title} · ${offer.institution.name}',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const Gap(AppSpacing.xl),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Message de motivation (facultatif)',
                    alignLabelWithHint: true,
                    hintText:
                        'Presentez en quelques lignes ce qui vous rend '
                        'pertinent pour ce poste.',
                  ),
                ),
                const Gap(AppSpacing.sm),
                const InfoBanner(
                  message:
                      'Votre profil vérifié, vos certifications et votre '
                      'experience seront transmis a l’établissement.',
                  tone: StatusTone.info,
                ),
                const Gap(AppSpacing.xl),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Envoyer ma candidature'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) {
      noteController.dispose();
      return;
    }

    setState(() => _applying = true);
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    await ref
        .read(jobRepositoryProvider)
        .apply(
          jobId: offer.id,
          teacherId: teacherId,
          coverNote: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
    noteController.dispose();

    ref.invalidate(jobDetailProvider(widget.jobId));
    ref.invalidate(opportunitiesProvider);

    if (!mounted) return;
    setState(() => _applying = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Candidature envoyée.')));
  }
}

/// Explication du score de compatibilite (§22).
class _MatchBreakdown extends StatelessWidget {
  const _MatchBreakdown({required this.match});

  final MatchScore match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compatibilite ${match.value} %',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calculee a partir de votre profil',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              ProgressRing(
                value: match.value / 100,
                size: 50,
                strokeWidth: 4.5,
                child: Text('${match.value}', style: text.titleSmall),
              ),
            ],
          ),
          const Divider(height: 24),
          for (final factor in match.factors)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    factor.ratio >= 1
                        ? Icons.check_circle
                        : factor.ratio > 0
                        ? Icons.adjust
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: factor.ratio >= 1
                        ? AppColors.success
                        : factor.ratio > 0
                        ? AppColors.warning
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(factor.label, style: text.titleSmall),
                        Text(factor.detail, style: text.labelSmall),
                      ],
                    ),
                  ),
                  Text(
                    '${factor.points}/${factor.maxPoints}',
                    style: text.labelMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
