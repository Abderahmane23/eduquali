import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/tutoring_repository.dart';
import '../../domain/usecases/tutoring_rules.dart';
import 'common.dart';

/// Couleur d'un statut de demande : la même partout, pour le parent comme
/// pour le professeur.
StatusTone tutoringTone(TutoringStatus status) => switch (status) {
  TutoringStatus.sent => StatusTone.warning,
  TutoringStatus.accepted => StatusTone.success,
  TutoringStatus.declined => StatusTone.danger,
  TutoringStatus.cancelled => StatusTone.neutral,
};

IconData tutoringModeIcon(TutoringMode mode) => switch (mode) {
  TutoringMode.atStudent => Icons.home_outlined,
  TutoringMode.atTeacher => Icons.person_pin_circle_outlined,
  TutoringMode.online => Icons.videocam_outlined,
};

/// Une offre de cours : matière, classes, lieu, tarif.
class TutoringOfferCard extends StatelessWidget {
  const TutoringOfferCard({
    super.key,
    required this.offer,
    this.showTeacher = false,
    this.action,
    this.trailing,
  });

  final TutoringOffer offer;

  /// Vrai quand le parent parcourt plusieurs professeurs.
  final bool showTeacher;

  /// Bouton principal sous la carte (« Réserver »).
  final Widget? action;

  /// Élément à droite du titre (interrupteur actif / en pause).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final where = [
      offer.mode.label,
      if (offer.mode != TutoringMode.online && offer.districts.isNotEmpty)
        offer.districts.join(', ')
      else if (offer.mode != TutoringMode.online && offer.city != null)
        offer.city!,
    ].join(' · ');

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
                    Text(offer.subjectName, style: text.titleMedium),
                    if (showTeacher) ...[
                      const SizedBox(height: 2),
                      Text(offer.teacherName, style: text.bodyMedium),
                    ],
                    const SizedBox(height: 2),
                    Text(offer.levelNames.join(' · '), style: text.bodySmall),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && offer.hourlyRate != null)
                Text(
                  '${Fmt.money(offer.hourlyRate!)} / h',
                  style: text.titleSmall?.copyWith(color: AppColors.primary),
                ),
            ],
          ),
          const Gap(AppSpacing.md),
          _Line(icon: tutoringModeIcon(offer.mode), label: where),
          if (offer.availabilityNote != null)
            _Line(icon: Icons.schedule, label: offer.availabilityNote!),
          if (trailing != null && offer.hourlyRate != null)
            _Line(
              icon: Icons.payments_outlined,
              label: '${Fmt.money(offer.hourlyRate!)} de l’heure',
            ),
          if (offer.description != null) ...[
            const Gap(AppSpacing.sm),
            Text(offer.description!, style: text.bodyMedium),
          ],
          if (action != null) ...[
            const Gap(AppSpacing.lg),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }
}

/// Une demande de cours.
///
/// Le parent y lit la réponse du professeur ; le professeur y lit qui
/// demande, pour quel enfant, et y répond.
class TutoringRequestCard extends StatelessWidget {
  const TutoringRequestCard({
    super.key,
    required this.item,
    required this.viewer,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final TutoringRequestItem item;
  final TutoringActor viewer;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final forTeacher = viewer == TutoringActor.teacher;

    final child = [
      if (item.childName != null) item.childName!,
      if (item.childLevel != null) item.childLevel!,
    ].join(' · ');

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
                    Text(
                      forTeacher
                          ? item.offer.subjectName
                          : '${item.offer.subjectName} avec '
                                '${item.offer.teacherName}',
                      style: text.titleMedium,
                    ),
                    if (child.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Pour $child', style: text.bodyMedium),
                    ],
                  ],
                ),
              ),
              StatusPill(
                label: item.status.label,
                tone: tutoringTone(item.status),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          if (forTeacher)
            _Line(
              icon: Icons.person_outline,
              label: [
                item.parentName,
                if (item.parentDistrict != null) item.parentDistrict!,
              ].join(' · '),
            ),
          _Line(
            icon: tutoringModeIcon(item.offer.mode),
            label: item.offer.mode.label,
          ),
          if (item.preferredStart != null)
            _Line(
              icon: Icons.event_outlined,
              label: 'À partir du ${Fmt.date(item.preferredStart!)}',
            ),
          _Line(
            icon: Icons.schedule,
            label: 'Envoyée ${Fmt.relative(item.createdAt)}',
          ),
          if (item.message != null) ...[
            const Gap(AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text('« ${item.message!} »', style: text.bodyMedium),
            ),
          ],
          if (item.status == TutoringStatus.accepted && !forTeacher) ...[
            const Gap(AppSpacing.md),
            const InfoBanner(
              message:
                  'Le professeur a accepté. Il vous contacte pour fixer '
                  'le premier cours.',
              tone: StatusTone.success,
              icon: Icons.check_circle_outline,
            ),
          ],
          if (onAccept != null || onDecline != null || onCancel != null) ...[
            const Gap(AppSpacing.lg),
            Row(
              children: [
                if (onDecline != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      // « Decliner » plutot que « Refuser » : les deux
                  // reponses d'un ecran restent aimables, et une
                  // famille qui lit le refus de son professeur n'a
                  // pas besoin du mot le plus sec.
                  child: const Text('Décliner'),
                    ),
                  ),
                if (onDecline != null && onAccept != null)
                  const SizedBox(width: AppSpacing.md),
                if (onAccept != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('Accepter'),
                    ),
                  ),
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: const Text('Annuler la demande'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}
