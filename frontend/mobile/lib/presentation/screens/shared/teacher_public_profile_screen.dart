import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/teacher_profile.dart';
import '../../../domain/usecases/subscription_rules.dart';
import '../../../domain/usecases/first_message.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/kit.dart';
import '../../widgets/tutoring_cards.dart';
import '../billing/subscription_sheet.dart';
import '../tutoring/book_tutoring_sheet.dart';

/// Écran 8 établissement — Profil public d'un enseignant (§15).
///
/// Les coordonnées personnelles restent masquees avant recrutement (§30) ;
/// l'échange passe par l'espace de recrutement.
class TeacherPublicProfileScreen extends ConsumerStatefulWidget {
  const TeacherPublicProfileScreen({
    super.key,
    required this.teacherId,
    this.jobId,
  });

  final String teacherId;

  /// Offre depuis laquelle le profil est consulte, si applicable.
  final String? jobId;

  @override
  ConsumerState<TeacherPublicProfileScreen> createState() =>
      _TeacherPublicProfileState();
}

class _TeacherPublicProfileState
    extends ConsumerState<TeacherPublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Une vue de plus, comptee une seule fois par ouverture. C'est le seul
    // chiffre qui dit au professeur si son boost a servi ; sans lui, il
    // l'achete a l'aveugle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(statsRepositoryProvider)
          .countProfileView(
            teacherId: widget.teacherId,
            byTeacherId: ref.read(currentSessionProvider)?.teacherId,
          );
    });
  }

  String get teacherId => widget.teacherId;
  String? get jobId => widget.jobId;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(teacherProfileByIdProvider(teacherId));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Profil indisponible',
          message: '$error',
        ),
        data: (profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profil introuvable',
            );
          }
          return _Body(profile: profile, jobId: jobId);
        },
      ),
    );
  }
}

/// Offres de cours du professeur, avec réservation.
class _TutoringSection extends ConsumerWidget {
  const _TutoringSection({required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final offers =
        ref.watch(teacherTutoringOffersProvider(teacherId)).valueOrNull ??
        const [];

    // Une demande déjà partie vers ce professeur ferme la porte jusqu'à sa
    // réponse. Le bouton restait actif : on pouvait réserver trois fois le
    // même professeur sans que rien ne le dise, et lui recevait trois
    // demandes identiques.
    //
    // Le verrou porte sur le professeur, pas sur l'offre : demander deux
    // matières au même professeur avant qu'il réponde une seule fois est le
    // même geste répété.
    final enAttente =
        (ref.watch(parentTutoringRequestsProvider).valueOrNull ?? const []).any(
          (r) =>
              r.offer.teacherId == teacherId && r.status == TutoringStatus.sent,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cours à domicile', style: text.titleMedium),
        const Gap(AppSpacing.md),
        if (offers.isEmpty)
          const AppCard(
            child: Text(
              'Ce professeur ne propose pas encore de cours à domicile.',
            ),
          )
        else
          for (final offer in offers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TutoringOfferCard(
                offer: offer,
                action: FilledButton(
                  // Désactivé plutôt que masqué : un bouton qui disparaît
                  // laisse croire que le professeur ne se réserve plus.
                  onPressed: enAttente
                      ? null
                      : () async {
                          final fil = await showBookTutoringSheet(
                            context,
                            offer,
                          );
                          if (fil == null || !context.mounted) return;
                          // On ouvre le fil, on n'annonce pas qu'il existe.
                          // L'ancien message renvoyait vers « Mes cours » et
                          // laissait la famille chercher : la demande est
                          // partie, le premier message est ecrit, autant
                          // montrer la conversation.
                          context.push('/messages/$fil');
                        },
                  child: Text(
                    enAttente
                        ? 'Ce professeur vous répondra bientôt'
                        : 'Réserver ce professeur',
                  ),
                ),
              ),
            ),
        const Gap(AppSpacing.xl),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.profile, this.jobId});

  final TeacherProfile profile;
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final session = ref.watch(currentSessionProvider);
    // Un professeur ne se met pas lui-même de côté : la liste sert à
    // comparer des candidats, et il n'en compare aucun.
    final peutMettreEnFavori =
        session != null && session.role != UserRole.teacher;
    final enFavori =
        ref
            .watch(favouritesProvider)
            .valueOrNull
            ?.contains(profile.teacherId) ??
        false;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              GradientHero(
                onBack: () => Navigator.of(context).maybePop(),
                title: profile.fullName,
                subtitle: profile.displayHeadline,
                actions: [
                  if (peutMettreEnFavori)
                    HeroIconButton(
                      icon: enFavori ? Icons.star : Icons.star_border,
                      tooltip: enFavori
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      onPressed: () => _toggleFavourite(context, ref),
                    ),
                ],
                bottom: HeroStatStrip(
                  items: [
                    (
                      value: '${profile.yearsExperience}',
                      label: 'Ans d’expérience',
                    ),
                    (value: '${profile.diplomas.length}', label: 'Diplômes'),
                    (value: profile.city ?? '—', label: 'Ville'),
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
                    Row(
                      children: [
                        StatusPill(
                          label: profile.availability.label,
                          tone: switch (profile.availability) {
                            Availability.available => StatusTone.success,
                            Availability.availableSoon => StatusTone.warning,
                            Availability.unavailable => StatusTone.neutral,
                          },
                          icon: Icons.event_available_outlined,
                        ),
                      ],
                    ),

                    // Le score de confiance sur 100 a ete retire : que fait une
                    // directrice avec « 72 » ? C'est un composite qui cache ce
                    // dont il est fait, alors que les badges de verification,
                    // juste en dessous, disent la meme chose en clair.
                    const Gap(AppSpacing.xl),

                    // Cours à domicile : c'est pour cela qu'un parent ouvre ce
                    // profil, la section vient donc avant tout le reste. Un
                    // établissement, lui, ne réserve pas de cours.
                    if (ref.watch(currentSessionProvider)?.role ==
                        UserRole.parent)
                      _TutoringSection(teacherId: profile.teacherId),

                    // Vérification (§14).
                    Text('Vérification', style: text.titleMedium),
                    const Gap(AppSpacing.md),
                    AppCard(
                      child: Column(
                        children: [
                          for (final badge in TrustBadge.values)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Icon(
                                    profile.badges.contains(badge)
                                        ? Icons.check_circle
                                        : Icons.remove_circle_outline,
                                    size: 19,
                                    color: profile.badges.contains(badge)
                                        ? AppColors.success
                                        : AppColors.borderStrong,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      badge.label,
                                      style: text.bodyLarge?.copyWith(
                                        fontSize: 14.5,
                                        color: profile.badges.contains(badge)
                                            ? AppColors.textPrimary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.xl),

                    // Compétences evaluees, par matière et niveau (§13).
                    Text('Compétences', style: text.titleMedium),
                    const Gap(AppSpacing.md),
                    if (profile.capabilities.isEmpty)
                      AppCard(
                        child: Text(
                          'Aucune matière declaree pour le moment.',
                          style: text.bodyMedium,
                        ),
                      )
                    else
                      for (final capability in profile.capabilities)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  capability.subject.name,
                                  style: text.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                for (final level in capability.levels)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            level.name,
                                            style: text.bodyLarge?.copyWith(
                                              fontSize: 14.5,
                                            ),
                                          ),
                                        ),
                                        if (capability.isCertified(level.id))
                                          StatusPill(
                                            label:
                                                '${capability.certifiedScores[level.id]} %',
                                            tone: StatusTone.success,
                                            icon: Icons.verified,
                                          )
                                        else
                                          Text(
                                            'Non evalue',
                                            style: text.labelSmall,
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                    const Gap(AppSpacing.lg),

                    // Reputation vérifiée (§33).
                    Text('Reputation', style: text.titleMedium),
                    const Gap(AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${profile.reputation.institutionCount}',
                            label: 'Établissements',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: StatTile(
                            value: '${profile.yearsExperience}',
                            label: 'An(s) d’experience',
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${profile.reputation.platformRecruitments}',
                            label: 'Recrutements par EduQuali',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: StatTile(
                            value: profile.reputation.satisfaction == null
                                ? '—'
                                : '${profile.reputation.satisfaction!.round()} %',
                            label: 'Satisfaction',
                            tone: StatusTone.success,
                          ),
                        ),
                      ],
                    ),

                    if (profile.bio != null) ...[
                      const Gap(AppSpacing.xl),
                      Text('Presentation', style: text.titleMedium),
                      const Gap(AppSpacing.md),
                      Text(
                        profile.bio!,
                        style: text.bodyLarge?.copyWith(fontSize: 15),
                      ),
                    ],

                    // Historique professionnel (§15).
                    if (profile.experiences.isNotEmpty) ...[
                      const Gap(AppSpacing.xl),
                      Text(
                        'Expérience professionnelle',
                        style: text.titleMedium,
                      ),
                      const Gap(AppSpacing.md),
                      for (final experience in profile.experiences)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        experience.position,
                                        style: text.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        experience.institutionName,
                                        style: text.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Fmt.period(
                                          experience.startDate,
                                          experience.endDate,
                                        ),
                                        style: text.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (experience.verificationStatus.isVerified)
                                  const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],

                    // Diplômes vérifiés (§7).
                    if (profile.diplomas.isNotEmpty) ...[
                      const Gap(AppSpacing.xl),
                      Text('Diplômes', style: text.titleMedium),
                      const Gap(AppSpacing.md),
                      for (final diploma in profile.diplomas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        diploma.diplomaType,
                                        style: text.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${diploma.institutionName} · ${diploma.graduationYear}',
                                        style: text.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill.verification(diploma.status),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action de contact (§23) — réservée aux établissements.
        //
        // Une école contacte pour recruter ; une famille réserve une offre
        // de cours. Leur donner les deux portes envoyait des familles écrire
        // « bonjour » dans un fil, pendant que le professeur attendait une
        // demande datée avec une matière et une classe — et personne ne
        // savait ce qui avait été convenu.
        if (session?.isInstitution ?? false)
          StickyActionBar(
            label: jobId != null ? 'Contacter le candidat' : 'Contacter',
            onPressed: () => _contact(context, ref),
          ),
      ],
    );
  }

  /// Met de côté, ou retire.
  ///
  /// Réservé aux comptes Pro : c'est l'une des fonctions que l'abonnement
  /// ouvre. Le refus propose l'abonnement plutôt que d'afficher un rappel et
  /// de s'arrêter là.
  Future<void> _toggleFavourite(BuildContext context, WidgetRef ref) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    final plan = SubscriptionPlan.fromCode(session.plan);
    if (!allows(plan, PaidFeature.favourites)) {
      await showSubscriptionSheet(
        context,
        required: PaidFeature.favourites.requires,
        because: 'Les favoris font partie du compte Pro.',
      );
      return;
    }

    await ref
        .read(favouritesRepositoryProvider)
        .toggle(ownerId: session.userId, teacherId: profile.teacherId);
    ref.invalidate(favouritesProvider);
  }

  /// Ouvre la discussion, ou demande l'abonnement.
  ///
  /// Le contrôle se fait ici et non sur le bouton : un bouton absent ne dit
  /// pas ce qui manque, et le faire disparaître laisserait croire que le
  /// professeur ne se contacte pas.
  Future<void> _contact(BuildContext context, WidgetRef ref) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      context.push(Routes.signup);
      return;
    }

    final plan = SubscriptionPlan.fromCode(session.plan);
    if (!allows(plan, PaidFeature.contact)) {
      await showSubscriptionSheet(
        context,
        required: PaidFeature.contact.requires,
        because:
            'Écrire à un professeur fait partie du compte Pro. Sans lui, '
            'vous pouvez consulter les fiches, pas prendre contact.',
      );
      return;
    }

    // Hors d'une offre, la discussion passe par un fil direct : il n'y a ni
    // candidature ni espace de recrutement à ouvrir.
    //
    // L'écran répondait « arrive bientôt » depuis le 24/09, faute d'une table
    // capable de ranger ce fil : `conversations` ne savait porter qu'une
    // famille. Elle accepte un établissement depuis la v22.
    if (jobId == null) {
      final institutionId = session.institutionId;
      if (institutionId == null) return;

      final conversations = ref.read(conversationsRepositoryProvider);
      final fil = await conversations.openForInstitution(
        institutionId: institutionId,
        teacherId: profile.teacherId,
      );

      // Le premier message dit qui écrit et ce qu'il cherche : un professeur
      // reçoit des demandes de gens qu'il ne connaît pas, et c'est cela qui
      // décide s'il répond.
      if ((await conversations.messages(fil)).isEmpty) {
        await conversations.send(
          conversationId: fil,
          senderId: session.userId,
          senderRole: session.role,
          body: composeFirstMessage(
            author: FirstMessageAuthor.institution,
            purpose: FirstMessagePurpose.job,
            teacherName: profile.fullName,
            senderName: session.displayName,
            subject: profile.capabilities.firstOrNull?.subject.name,
          ),
        );

        final compte = await ref
            .read(teacherRepositoryProvider)
            .userIdOf(profile.teacherId);
        if (compte != null) {
          await ref
              .read(notificationRepositoryProvider)
              .push(
                userId: compte,
                kind: NotificationKind.message,
                title: 'Un établissement vous écrit',
                body:
                    '${session.displayName} vous contacte au sujet d’un poste.',
                route: '/messages/$fil',
              );
        }
      }

      refreshConversations(ref);
      if (!context.mounted) return;
      context.push('/messages/$fil');
      return;
    }

    final applicants = await ref.read(applicantsProvider(jobId!).future);
    final candidate = applicants
        .where((c) => c.profile.teacherId == profile.teacherId)
        .firstOrNull;

    if (candidate?.applicationId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce candidat n’a pas postule a cette offre. Invitez-le via une '
            'offre privee.',
          ),
        ),
      );
      return;
    }

    final roomId = await ref
        .read(recruitmentRepositoryProvider)
        .openRoom(candidate!.applicationId!);
    if (!context.mounted) return;
    context.push('/rooms/$roomId');
  }
}
