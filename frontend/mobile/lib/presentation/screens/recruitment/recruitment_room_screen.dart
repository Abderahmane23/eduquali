import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/contact_masker.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/recruitment_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 27 a 33 — Espace de recrutement (§24).
///
/// Centralise candidature, messages, entretien, proposition, contrat et suivi.
class RecruitmentRoomScreen extends ConsumerWidget {
  const RecruitmentRoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(recruitmentRoomProvider(roomId));

    return roomAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Espace indisponible',
          message: '$error',
        ),
      ),
      data: (room) {
        if (room == null) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const EmptyState(
              icon: Icons.help_outline,
              title: 'Espace introuvable',
            ),
          );
        }
        return _RoomBody(room: room);
      },
    );
  }
}

class _RoomBody extends ConsumerStatefulWidget {
  const _RoomBody({required this.room});

  final RecruitmentRoomView room;

  @override
  ConsumerState<_RoomBody> createState() => _RoomBodyState();
}

class _RoomBodyState extends ConsumerState<_RoomBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final session = ref.watch(currentSessionProvider);
    final isInstitution = session?.isInstitution ?? false;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isInstitution ? room.teacher.fullName : room.job.institution.name,
              style: text.titleMedium,
            ),
            Text(room.job.title, style: text.labelSmall),
          ],
        ),
        // Couleurs et graisse viennent du theme : une seule definition.
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Suivi'),
            Tab(text: 'Messages'),
            Tab(text: 'Dossier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TimelineTab(room: room, isInstitution: isInstitution),
          _MessagesTab(room: room),
          _DossierTab(room: room, isInstitution: isInstitution),
        ],
      ),
    );
  }
}

/// Onglet « Suivi » — workflow, entretien, proposition, contrat (§28).
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.room, required this.isInstitution});

  final RecruitmentRoomView room;
  final bool isInstitution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Étape courante du workflow (§28).
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Étape actuelle', style: text.labelSmall),
                        const SizedBox(height: 2),
                        Text(room.stage.label, style: text.titleMedium),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: '${room.stage.order + 1} / 10',
                    tone: StatusTone.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ThinProgressBar(value: (room.stage.order + 1) / 10),
            ],
          ),
        ),

        const Gap(AppSpacing.xl),

        // Entretien (§25).
        SectionHeader(
          title: 'Entretien',
          actionLabel: isInstitution ? 'Proposer' : null,
          onAction: isInstitution
              ? () => _proposeInterview(context, ref)
              : null,
        ),
        const Gap(AppSpacing.md),
        if (room.interviews.isEmpty)
          AppCard(
            child: Text(
              isInstitution
                  ? 'Aucun entretien planifie. Proposez une date au candidat.'
                  : 'Aucun entretien propose pour le moment.',
              style: text.bodyMedium,
            ),
          )
        else
          for (final interview in room.interviews)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _InterviewCard(
                interview: interview,
                canRespond: !isInstitution,
              ),
            ),

        const Gap(AppSpacing.xl),

        // Proposition de recrutement (§26).
        SectionHeader(
          title: 'Proposition de recrutement',
          actionLabel: isInstitution && room.offer == null ? 'Envoyer' : null,
          onAction: isInstitution && room.offer == null
              ? () => _sendOffer(context, ref)
              : null,
        ),
        const Gap(AppSpacing.md),
        if (room.offer case final offer?)
          _OfferCard(offer: offer, isInstitution: isInstitution, room: room)
        else
          AppCard(
            child: Text(
              isInstitution
                  ? 'Aucune proposition envoyée. Une proposition officialise '
                        'les conditions du poste.'
                  : 'Vous n’avez pas encore recu de proposition.',
              style: text.bodyMedium,
            ),
          ),

        // Contrat (§27).
        if (room.offer?.status == OfferStatus.accepted) ...[
          const Gap(AppSpacing.xl),
          SectionHeader(title: 'Contrat'),
          const Gap(AppSpacing.md),
          AppCard(
            onTap: () => context.push('/rooms/${room.id}/contract'),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.contract == null
                            ? 'Generer le contrat'
                            : 'Contrat ${room.contract!.reference}',
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        room.contract == null
                            ? 'A partir des conditions acceptees'
                            : room.contract!.status.label,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
        ],

        // Suivi après recrutement (§32).
        if (room.followUp case final followUp?) ...[
          const Gap(AppSpacing.xl),
          SectionHeader(title: 'Suivi du recrutement'),
          const Gap(AppSpacing.md),
          _FollowUpCard(
            followUp: followUp,
            isInstitution: isInstitution,
            roomId: room.id,
          ),
        ],

        // Journal du workflow (§28).
        if (room.events.isNotEmpty) ...[
          const Gap(AppSpacing.xl),
          Text('Historique', style: text.titleMedium),
          const Gap(AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < room.events.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          room.events[i].toStage.label,
                          style: text.titleSmall,
                        ),
                      ),
                      Text(
                        Fmt.relative(room.events[i].createdAt),
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _proposeInterview(BuildContext context, WidgetRef ref) async {
    final result =
        await showModalBottomSheet<
          ({
            DateTime date,
            InterviewMode mode,
            String? location,
            String? comment,
          })
        >(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _InterviewForm(),
        );
    if (result == null) return;

    await ref
        .read(recruitmentRepositoryProvider)
        .proposeInterview(
          roomId: room.id,
          scheduledAt: result.date,
          mode: result.mode,
          location: result.location,
          comment: result.comment,
        );
  }

  Future<void> _sendOffer(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_OfferDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OfferForm(defaultPosition: room.job.title),
    );
    if (result == null) return;

    await ref
        .read(recruitmentRepositoryProvider)
        .sendOffer(
          roomId: room.id,
          position: result.position,
          contractType: result.contractType,
          monthlySalary: result.salary,
          startDate: result.startDate,
          durationMonths: result.durationMonths,
          trialPeriodDays: result.trialPeriodDays,
          schedule: result.schedule,
          extraConditions: result.extraConditions,
        );
  }
}

class _InterviewCard extends ConsumerWidget {
  const _InterviewCard({required this.interview, required this.canRespond});

  final InterviewItem interview;
  final bool canRespond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      Fmt.dateTime(interview.scheduledAt),
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(interview.mode.label, style: text.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                label: interview.status.label,
                tone: switch (interview.status) {
                  InterviewStatus.accepted => StatusTone.success,
                  InterviewStatus.declined ||
                  InterviewStatus.noShow => StatusTone.danger,
                  InterviewStatus.completed => StatusTone.neutral,
                  InterviewStatus.proposed => StatusTone.info,
                },
              ),
            ],
          ),

          if (interview.location != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(interview.location!, style: text.bodySmall),
                ),
              ],
            ),
          ],

          if (interview.comment != null) ...[
            const SizedBox(height: 8),
            Text(interview.comment!, style: text.bodySmall),
          ],

          if (canRespond && interview.status == InterviewStatus.proposed) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(recruitmentRepositoryProvider)
                        .respondToInterview(
                          interview.id,
                          InterviewStatus.declined,
                        ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const Text('Decliner'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => ref
                        .read(recruitmentRepositoryProvider)
                        .respondToInterview(
                          interview.id,
                          InterviewStatus.accepted,
                        ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const Text('Accepter'),
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

/// Proposition de recrutement, avec les trois réponses possibles (§26).
class _OfferCard extends ConsumerWidget {
  const _OfferCard({
    required this.offer,
    required this.isInstitution,
    required this.room,
  });

  final OfferItem offer;
  final bool isInstitution;
  final RecruitmentRoomView room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(offer.position, style: text.titleMedium)),
              StatusPill(
                label: offer.status.label,
                tone: switch (offer.status) {
                  OfferStatus.accepted => StatusTone.success,
                  OfferStatus.declined => StatusTone.danger,
                  OfferStatus.changeRequested => StatusTone.warning,
                  _ => StatusTone.info,
                },
              ),
            ],
          ),

          const Divider(height: 22),

          InfoRow(
            label: 'Rémunération mensuelle',
            value: Fmt.money(offer.monthlySalary),
            valueColor: AppColors.primary,
          ),
          const Divider(height: 18),
          InfoRow(label: 'Type de contrat', value: offer.contractType.label),
          const Divider(height: 18),
          InfoRow(label: 'Prise de poste', value: Fmt.date(offer.startDate)),
          if (offer.durationMonths != null) ...[
            const Divider(height: 18),
            InfoRow(label: 'Durée', value: '${offer.durationMonths} mois'),
          ],
          if (offer.trialPeriodDays != null) ...[
            const Divider(height: 18),
            InfoRow(
              label: 'Période d’essai',
              value: '${offer.trialPeriodDays} jours',
            ),
          ],
          if (offer.schedule != null) ...[
            const Divider(height: 18),
            InfoRow(label: 'Horaires', value: offer.schedule!),
          ],

          if (offer.extraConditions != null) ...[
            const SizedBox(height: 12),
            Text('Conditions supplementaires', style: text.labelSmall),
            const SizedBox(height: 4),
            Text(offer.extraConditions!, style: text.bodySmall),
          ],

          if (offer.changeRequest != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              title: 'Modification demandee',
              message: offer.changeRequest!,
              tone: StatusTone.warning,
            ),
          ],

          // Frais de recrutement dus par l'établissement (§36).
          if (isInstitution) ...[
            const SizedBox(height: 12),
            InfoBanner(
              message:
                  'En cas de recrutement, les frais s’elevent a '
                  '${Fmt.money(offer.successFee)} (un mois de salaire), selon '
                  'les conditions commerciales.',
              tone: StatusTone.neutral,
              icon: Icons.receipt_long_outlined,
            ),
          ],

          // Réponse de l'enseignant (§26).
          if (!isInstitution && offer.awaitsTeacher) ...[
            const Divider(height: 22),
            FilledButton(
              onPressed: () => ref
                  .read(recruitmentRepositoryProvider)
                  .respondToOffer(offer.id, OfferStatus.accepted),
              child: const Text('Accepter la proposition'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _requestChange(context, ref),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text(
                      'Demander une modification',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(recruitmentRepositoryProvider)
                        .respondToOffer(offer.id, OfferStatus.declined),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],

          // Confirmation du recrutement une fois le contrat signe (§32).
          if (isInstitution &&
              room.contract?.fullySigned == true &&
              room.followUp == null) ...[
            const Divider(height: 22),
            FilledButton.icon(
              onPressed: () => ref
                  .read(recruitmentRepositoryProvider)
                  .confirmRecruitment(room.id),
              icon: const Icon(Icons.handshake_outlined, size: 19),
              label: const Text('Confirmer le recrutement'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestChange(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Demander une modification'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Precisez le point a revoir : rémunération, date de prise de '
                'poste, horaires…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null || result.trim().isEmpty) return;

    await ref
        .read(recruitmentRepositoryProvider)
        .respondToOffer(
          offer.id,
          OfferStatus.changeRequested,
          changeRequest: result.trim(),
        );
  }
}

/// Suivi a 30 / 60 / 90 jours (§32).
class _FollowUpCard extends ConsumerWidget {
  const _FollowUpCard({
    required this.followUp,
    required this.isInstitution,
    required this.roomId,
  });

  final RecruitmentFollowUp followUp;
  final bool isInstitution;
  final String roomId;

  static const _milestones = [30, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final due = followUp.dueMilestones(_milestones);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: 'Prise de poste', value: Fmt.date(followUp.startDate)),
          const Divider(height: 18),
          InfoRow(
            label: 'Anciennete',
            value: '${followUp.daysSinceStart} jour(s)',
          ),
          if (isInstitution) ...[
            const Divider(height: 18),
            InfoRow(
              label: 'Frais de recrutement',
              value: Fmt.money(followUp.successFeeAmount),
              valueColor: followUp.feePaid
                  ? AppColors.success
                  : AppColors.textPrimary,
            ),
          ],

          const SizedBox(height: 14),
          Text('Jalons de suivi', style: text.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final milestone in _milestones) ...[
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        followUp.completedMilestones.contains(milestone)
                            ? Icons.check_circle
                            : followUp.daysSinceStart >= milestone
                            ? Icons.radio_button_unchecked
                            : Icons.schedule,
                        size: 20,
                        color: followUp.completedMilestones.contains(milestone)
                            ? AppColors.success
                            : followUp.daysSinceStart >= milestone
                            ? AppColors.warning
                            : AppColors.borderStrong,
                      ),
                      const SizedBox(height: 4),
                      Text('$milestone j', style: text.labelSmall),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (isInstitution && due.isNotEmpty) ...[
            const Divider(height: 22),
            FilledButton(
              onPressed: () => _review(context, ref, due.first),
              child: Text('Évaluer a ${due.first} jours'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    int milestone,
  ) async {
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewForm(milestone: milestone),
    );
    if (result == null) return;

    await ref
        .read(recruitmentRepositoryProvider)
        .submitReview(
          recruitmentId: followUp.id,
          milestoneDays: milestone,
          punctuality: result['punctuality']!,
          pedagogy: result['pedagogy']!,
          subjectMastery: result['subjectMastery']!,
          professionalism: result['professionalism']!,
          attendance: result['attendance']!,
        );
  }
}

/// Onglet « Messages » — messagerie interne (§23).
class _MessagesTab extends ConsumerStatefulWidget {
  const _MessagesTab({required this.room});

  final RecruitmentRoomView room;

  @override
  ConsumerState<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends ConsumerState<_MessagesTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(currentSessionProvider);
      if (session != null) {
        ref
            .read(recruitmentRepositoryProvider)
            .markMessagesRead(widget.room.id, session.userId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final session = ref.watch(currentSessionProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        // Rappel de la protection anti-contournement (§30).
        if (!room.contactUnlocked)
          Container(
            width: double.infinity,
            color: AppColors.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les coordonnées personnelles sont masquees jusqu’a la '
                    'signature du contrat.',
                    style: text.labelSmall,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: room.messages.isEmpty
              ? const EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Aucun message',
                  message:
                      'Echangez ici documents, questions et informations '
                      'pratiques. Tout reste centralise dans le dossier.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: room.messages.length,
                  itemBuilder: (_, index) {
                    final message = room.messages[index];
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == session?.userId,
                    );
                  },
                ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message…',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 19),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(46, 46),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    // Avertit l'auteur avant l'envoi si le message contient des coordonnées.
    if (!widget.room.contactUnlocked &&
        ContactMasker.containsContactDetails(body)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Coordonnées detectees'),
          content: const Text(
            'Votre message semble contenir des coordonnées personnelles. '
            'Elles seront masquees jusqu’a la signature du contrat.\n\n'
            'La plateforme met a votre disposition la messagerie, les '
            'entretiens, l’échange de documents et le suivi du recrutement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Modifier'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    _controller.clear();
    await ref
        .read(recruitmentRepositoryProvider)
        .sendMessage(
          roomId: widget.room.id,
          senderId: session.userId,
          senderRole: session.role,
          body: body,
        );

    if (!mounted) return;
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final MessageItem message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surfaceMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(isMine ? AppRadius.md : 3),
                  bottomRight: Radius.circular(isMine ? 3 : AppRadius.md),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: isMine ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.masked) ...[
                        Icon(
                          Icons.lock_outline,
                          size: 11,
                          color: isMine
                              ? Colors.white70
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        Fmt.time(message.sentAt),
                        style: text.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: isMine
                              ? Colors.white70
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet « Dossier » — profil du candidat, notes internes (§24).
class _DossierTab extends ConsumerWidget {
  const _DossierTab({required this.room, required this.isInstitution});

  final RecruitmentRoomView room;
  final bool isInstitution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        AppCard(
          onTap: isInstitution
              ? () => context.push('/teachers/${room.teacher.teacherId}')
              : null,
          child: Row(
            children: [
              ProfileAvatar(
                firstName: room.teacher.firstName,
                lastName: room.teacher.lastName,
                photoPath: room.teacher.photoPath,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.teacher.fullName, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(room.teacher.displayHeadline, style: text.bodySmall),
                  ],
                ),
              ),
              if (isInstitution)
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),

        const Gap(AppSpacing.lg),
        Text('Le poste', style: text.titleMedium),
        const Gap(AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              InfoRow(label: 'Intitule', value: room.job.title),
              const Divider(height: 18),
              InfoRow(label: 'Matière', value: room.job.subject.name),
              const Divider(height: 18),
              InfoRow(label: 'Niveaux', value: room.job.levelLabel),
              const Divider(height: 18),
              InfoRow(label: 'Ville', value: room.job.city),
              const Divider(height: 18),
              InfoRow(label: 'Contrat', value: room.job.contractType.label),
            ],
          ),
        ),

        // Coordonnées revelees après signature (§30).
        const Gap(AppSpacing.lg),
        Text('Coordonnées', style: text.titleMedium),
        const Gap(AppSpacing.md),
        AppCard(
          color: room.contactUnlocked ? null : AppColors.surfaceMuted,
          borderColor: room.contactUnlocked
              ? AppColors.border
              : AppColors.surfaceMuted,
          child: Row(
            children: [
              Icon(
                room.contactUnlocked ? Icons.lock_open : Icons.lock_outline,
                size: 19,
                color: room.contactUnlocked
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.contactUnlocked
                          ? room.teacher.phone
                          : ContactMasker.maskPhone(room.teacher.phone),
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      room.contactUnlocked
                          ? 'Coordonnées accessibles — contrat signe.'
                          : 'Revelees une fois le contrat signe.',
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Notes internes, visibles de l'établissement seul (§24).
        if (isInstitution) ...[
          const Gap(AppSpacing.lg),
          Text('Notes internes', style: text.titleMedium),
          const Gap(AppSpacing.md),
          _InternalNotes(roomId: room.id, initial: room.internalNotes),
        ],
      ],
    );
  }
}

class _InternalNotes extends ConsumerStatefulWidget {
  const _InternalNotes({required this.roomId, this.initial});

  final String roomId;
  final String? initial;

  @override
  ConsumerState<_InternalNotes> createState() => _InternalNotesState();
}

class _InternalNotesState extends ConsumerState<_InternalNotes> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Impressions d’entretien, points a vérifier, decision de '
                'l’equipe…',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        TextButton(
          onPressed: () async {
            await ref
                .read(recruitmentRepositoryProvider)
                .saveInternalNotes(widget.roomId, _controller.text);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notes enregistrees.')),
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

// --- Formulaires.

/// Proposition d'entretien (§25).
class _InterviewForm extends StatefulWidget {
  const _InterviewForm();

  @override
  State<_InterviewForm> createState() => _InterviewFormState();
}

class _InterviewFormState extends State<_InterviewForm> {
  DateTime _date = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  InterviewMode _mode = InterviewMode.onSite;
  final _location = TextEditingController();
  final _comment = TextEditingController();

  @override
  void dispose() {
    _location.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
            Text('Proposer un entretien', style: text.titleLarge),
            const Gap(AppSpacing.xl),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(Fmt.date(_date), style: text.bodyLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                  locale: const Locale('fr'),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(_time.format(context), style: text.bodyLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
            ),

            const Gap(AppSpacing.md),
            DropdownButtonFormField<InterviewMode>(
              initialValue: _mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type d’entretien'),
              items: [
                for (final mode in InterviewMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.label)),
              ],
              onChanged: (value) =>
                  setState(() => _mode = value ?? InterviewMode.onSite),
            ),
            const Gap(AppSpacing.lg),

            TextField(
              controller: _location,
              decoration: InputDecoration(
                labelText: _mode == InterviewMode.video
                    ? 'Lien de visioconference'
                    : 'Lieu de l’entretien',
              ),
            ),
            const Gap(AppSpacing.lg),

            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Commentaire (facultatif)',
                alignLabelWithHint: true,
              ),
            ),

            const Gap(AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, (
                date: DateTime(
                  _date.year,
                  _date.month,
                  _date.day,
                  _time.hour,
                  _time.minute,
                ),
                mode: _mode,
                location: _location.text.trim().isEmpty
                    ? null
                    : _location.text.trim(),
                comment: _comment.text.trim().isEmpty
                    ? null
                    : _comment.text.trim(),
              )),
              child: const Text('Proposer l’entretien'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Données d'une proposition de recrutement (§26).
class _OfferDraft {
  const _OfferDraft({
    required this.position,
    required this.contractType,
    required this.salary,
    required this.startDate,
    this.durationMonths,
    this.trialPeriodDays,
    this.schedule,
    this.extraConditions,
  });

  final String position;
  final ContractType contractType;
  final int salary;
  final DateTime startDate;
  final int? durationMonths;
  final int? trialPeriodDays;
  final String? schedule;
  final String? extraConditions;
}

class _OfferForm extends StatefulWidget {
  const _OfferForm({required this.defaultPosition});

  final String defaultPosition;

  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  late final _position = TextEditingController(text: widget.defaultPosition);
  final _salary = TextEditingController();
  final _duration = TextEditingController();
  // Quinze jours : le temps de voir le professeur en classe, pas un
  // trimestre d'engagement deguise.
  final _trial = TextEditingController(text: '15');
  final _schedule = TextEditingController();
  final _conditions = TextEditingController();

  ContractType _contractType = ContractType.permanent;
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    for (final controller in [
      _position,
      _salary,
      _duration,
      _trial,
      _schedule,
      _conditions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final salary = int.tryParse(_salary.text.trim());

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
            Text('Proposition de recrutement', style: text.titleLarge),
            const Gap(AppSpacing.xl),

            TextField(
              controller: _position,
              decoration: const InputDecoration(labelText: 'Poste'),
            ),
            const Gap(AppSpacing.lg),

            DropdownButtonFormField<ContractType>(
              initialValue: _contractType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type de contrat'),
              items: [
                for (final type in ContractType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) => setState(
                () => _contractType = value ?? ContractType.permanent,
              ),
            ),
            const Gap(AppSpacing.lg),

            TextField(
              controller: _salary,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Salaire mensuel',
                suffixText: 'GNF',
              ),
            ),

            // Rappel du modèle economique (§36).
            if (salary != null && salary > 0) ...[
              const Gap(AppSpacing.sm),
              InfoBanner(
                message:
                    'Frais de recrutement en cas d’embauche : '
                    '${Fmt.money(salary)} (un mois de salaire).',
                tone: StatusTone.neutral,
                icon: Icons.receipt_long_outlined,
              ),
            ],

            const Gap(AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text('Prise de poste', style: text.labelSmall),
              subtitle: Text(Fmt.date(_startDate), style: text.bodyLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  locale: const Locale('fr'),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),

            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois)',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _trial,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Essai (jours)',
                    ),
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.lg),

            TextField(
              controller: _schedule,
              decoration: const InputDecoration(
                labelText: 'Horaires',
                hintText: '12 heures par semaine, lundi au mercredi',
              ),
            ),
            const Gap(AppSpacing.lg),

            TextField(
              controller: _conditions,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Conditions supplementaires',
                alignLabelWithHint: true,
              ),
            ),

            const Gap(AppSpacing.xl),
            FilledButton(
              onPressed: salary == null || salary <= 0
                  ? null
                  : () => Navigator.pop(
                      context,
                      _OfferDraft(
                        position: _position.text.trim(),
                        contractType: _contractType,
                        salary: salary,
                        startDate: _startDate,
                        durationMonths: int.tryParse(_duration.text.trim()),
                        trialPeriodDays: int.tryParse(_trial.text.trim()),
                        schedule: _schedule.text.trim().isEmpty
                            ? null
                            : _schedule.text.trim(),
                        extraConditions: _conditions.text.trim().isEmpty
                            ? null
                            : _conditions.text.trim(),
                      ),
                    ),
              child: const Text('Envoyer la proposition'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Évaluation a un jalon de suivi (§32).
class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.milestone});

  final int milestone;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final Map<String, int> _scores = {
    'punctuality': 4,
    'pedagogy': 4,
    'subjectMastery': 4,
    'professionalism': 4,
    'attendance': 4,
  };

  static const _labels = {
    'punctuality': 'Ponctualite',
    'pedagogy': 'Pedagogie',
    'subjectMastery': 'Maitrise de la matière',
    'professionalism': 'Professionnalisme',
    'attendance': 'Assiduite',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
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
              'Évaluation a ${widget.milestone} jours',
              style: text.titleLarge,
            ),
            const Gap(AppSpacing.sm),
            Text(
              'Votre évaluation alimente la reputation vérifiée de '
              'l’enseignant.',
              style: text.bodySmall,
            ),
            const Gap(AppSpacing.xl),

            for (final entry in _labels.entries) ...[
              Text(entry.value, style: text.titleSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      onPressed: () =>
                          setState(() => _scores[entry.key] = star),
                      icon: Icon(
                        star <= _scores[entry.key]!
                            ? Icons.star
                            : Icons.star_border,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      tooltip: 'Donner $star étoile${star > 1 ? "s" : ""}',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.touchTarget,
                        minHeight: AppSpacing.touchTarget,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            const Gap(AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.pop(context, _scores),
              child: const Text('Enregistrer l’évaluation'),
            ),
          ],
        ),
      ),
    );
  }
}
