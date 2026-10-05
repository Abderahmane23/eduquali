import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/teacher_profile.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';

/// Le profil du professeur, d'après les maquettes du 23/09.
///
/// L'en-tête montre ce que les autres voient de lui — sa photo, son statut,
/// sa ville — et trois chiffres qui disent où en est sa fiche. Le corps ne
/// garde que ce qui se complète : expériences, diplômes, puis les actions.
///
/// La déconnexion vit dans l'en-tête, pas au fond de la page. Elle y était,
/// et il fallait faire défiler tout le profil pour l'atteindre ; un téléphone
/// se prête, et quitter son compte ne doit pas se mériter.
class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHero(
          title: 'Mon profil',
          actions: [
            HeroIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Modifier mon profil',
              onPressed: () => context.push(Routes.teacherProfileEdit),
            ),
            HeroIconButton(
              icon: Icons.logout,
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go(Routes.splash);
              },
            ),
          ],
          bottom: profile == null ? null : _Identity(profile: profile),
        ),

        if (profile == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.section),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Expériences -------------------------------------------
                KitSectionTitle(
                  title: 'Expériences',
                  actionLabel: profile.experiences.isEmpty ? null : 'Ajouter',
                  onAction: profile.experiences.isEmpty
                      ? null
                      : () => context.push('/teacher/experience'),
                ),
                if (profile.experiences.isEmpty)
                  KitEmpty(
                    icon: Icons.work_outline,
                    message:
                        'Aucune expérience déclarée. C’est la première chose '
                        'qu’une école regarde.',
                    actionLabel: 'Ajouter une expérience',
                    onAction: () => context.push('/teacher/experience'),
                  )
                else
                  KitCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < profile.experiences.length; i++)
                          _Row(
                            first: i == 0,
                            icon: Icons.apartment_outlined,
                            title: profile.experiences[i].institutionName,
                            subtitle: profile.experiences[i].position,
                            onTap: () => context.push('/teacher/experience'),
                          ),
                      ],
                    ),
                  ),

                // --- Diplômes ----------------------------------------------
                const Gap(AppSpacing.xl),
                KitSectionTitle(
                  title: 'Diplômes',
                  actionLabel: profile.diplomas.isEmpty ? null : 'Ajouter',
                  onAction: profile.diplomas.isEmpty
                      ? null
                      : () => context.push('/teacher/diplomas/add'),
                ),
                if (profile.diplomas.isEmpty)
                  KitEmpty(
                    icon: Icons.school_outlined,
                    message: 'Aucun diplôme déposé.',
                    actionLabel: 'Ajouter un diplôme',
                    onAction: () => context.push('/teacher/diplomas/add'),
                  )
                else
                  KitCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < profile.diplomas.length; i++)
                          _Row(
                            first: i == 0,
                            icon: Icons.school_outlined,
                            title: profile.diplomas[i].diplomaType,
                            subtitle: '${profile.diplomas[i].graduationYear}',
                            onTap: () => context.push('/teacher/diplomas'),
                          ),
                      ],
                    ),
                  ),

                // --- Actions -----------------------------------------------
                const Gap(AppSpacing.xl),
                const KitSectionTitle(title: 'Actions rapides'),

                // Les deux gestes qui rapportent le plus de vues, et
                // seulement tant qu'ils restent à faire : « Ajoutez une
                // photo » proposé à quelqu'un qui en a déjà une fait douter
                // de tout le reste de l'écran.
                //
                // Ils remplacent « Booster mon compte », qui menait à la même
                // page de modification sans dire ce qu'il fallait y faire.
                if ((profile.photoPath ?? '').isEmpty)
                  _Action(
                    icon: Icons.add_a_photo_outlined,
                    tone: StatusTone.warning,
                    label: 'Ajouter une photo de profil',
                    hint: '20 % de vues en plus',
                    onTap: () => context.push(Routes.teacherProfileEdit),
                  ),
                if (profile.certifications.isEmpty)
                  _Action(
                    icon: Icons.workspace_premium_outlined,
                    tone: StatusTone.primary,
                    label: 'Passer un test de compétence',
                    hint: '20 % de vues en plus',
                    onTap: () => context.push(Routes.teacherTests),
                  ),
                _Action(
                  icon: Icons.note_add_outlined,
                  tone: StatusTone.info,
                  label: 'Ajouter des documents',
                  onTap: () => context.push('/teacher/diplomas'),
                ),
                // L'éditeur de CV n'existe pas encore : l'entrée est là,
                // et le dit. Un bouton qui n'a l'air de rien faire se
                // retente trois fois avant qu'on renonce ; celui-ci
                // répond.
                _Action(
                  icon: Icons.description_outlined,
                  tone: StatusTone.neutral,
                  label: 'Modifier mon CV',
                  hint: 'Bientôt disponible',
                  onTap: () => ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'L’éditeur de CV arrive. En attendant, déposez '
                          'votre CV dans « Ajouter des documents ».',
                        ),
                      ),
                    ),
                ),
                _Action(
                  icon: Icons.credit_card_outlined,
                  tone: StatusTone.success,
                  label: 'Facturation et moyens de paiement',
                  onTap: () => context.push(Routes.paymentMethods),
                ),
                _Action(
                  icon: Icons.support_agent_outlined,
                  tone: StatusTone.neutral,
                  label: 'Nous contacter',
                  onTap: () => context.push(Routes.contact),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Qui il est, sur le dégradé : photo, nom, statut, ville, et trois chiffres.
class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          ProfileAvatar(
            firstName: profile.firstName,
            lastName: profile.lastName,
            photoPath: profile.photoPath,
            size: 74,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onHeroSurface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.onHeroBorder),
                  ),
                  child: Text(
                    profile.availability.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: AppColors.onHeroMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        profile.city ?? 'Ville non renseignée',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onHeroMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      HeroStatStrip(
        items: [
          (value: '${profile.experiences.length}', label: 'Expériences'),
          (value: '${profile.diplomas.length}', label: 'Diplômes'),
          (value: '${profile.completion.rate} %', label: 'Complété'),
        ],
      ),
    ],
  );
}

/// Une ligne dans une carte : pastille, titre, sous-titre, chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.first,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool first;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!first) const Divider(height: 1, color: AppColors.border),
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              IconTile(icon: icon, size: 42),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Une action rapide, en pleine largeur.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tone,
    required this.label,
    required this.onTap,
    this.hint,
  });

  final IconData icon;
  final StatusTone tone;
  final String label;
  final VoidCallback onTap;

  /// Ce que l'action rapporte, sous son nom. Le gain écrit à côté du geste
  /// est ce qui décide de le faire : « Ajouter une photo » tout seul se
  /// remet à demain.
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: KitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconTile(icon: icon, tone: tone, size: 46),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tonePair(tone).ink,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: 22,
          ),
        ],
      ),
    ),
  );
}
