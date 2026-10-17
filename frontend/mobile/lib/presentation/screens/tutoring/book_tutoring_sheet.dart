import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/tutoring_repository.dart';
import '../../../domain/usecases/first_message.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common.dart';

/// Ouvre la réservation d'une offre de cours.
///
/// Renvoie l'identifiant du fil de discussion ouvert par la demande, ou
/// `null` si rien n'est parti. L'appelant s'en sert pour emmener la famille
/// sur ses messages : depuis le 02/10, une réservation ouvre la conversation
/// et y pose le premier message, au lieu de laisser la demande partir dans
/// le silence.
Future<String?> showBookTutoringSheet(
  BuildContext context,
  TutoringOffer offer,
) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _BookSheet(offer: offer),
);

class _BookSheet extends ConsumerStatefulWidget {
  const _BookSheet({required this.offer});

  final TutoringOffer offer;

  @override
  ConsumerState<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends ConsumerState<_BookSheet> {
  final _message = TextEditingController();
  String? _childId;
  DateTime? _start;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// Ouvre le fil de la demande et y pose le premier message.
  ///
  /// Le texte part sous le nom de la famille : il ne dit donc que ce qu'on
  /// sait d'elle. Ce que le parent a écrit dans le champ libre suit, en
  /// second message — mélanger les deux ferait passer sa phrase pour une
  /// formule automatique, et l'automatique pour sa phrase.
  Future<String?> _ouvrirLeFil(String requestId) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return null;

    final conversations = ref.read(conversationsRepositoryProvider);
    final filId = await conversations.openForRequest(requestId);

    final enfants = ref.read(parentChildrenProvider).valueOrNull ?? const [];
    final enfant = enfants.where((e) => e.id == _childId).firstOrNull;
    final niveaux = ref.read(levelsProvider).valueOrNull ?? const [];
    final classe = niveaux
        .where((n) => n.id == enfant?.levelId)
        .map((n) => n.name)
        .firstOrNull;

    // Un etudiant majeur est lui-meme l'eleve : « mon enfant » serait faux,
    // et c'est lui qui le lirait.
    final etudiant = session.role == UserRole.student;

    await conversations.send(
      conversationId: filId,
      senderId: session.userId,
      senderRole: session.role,
      body: composeFirstMessage(
        author: etudiant
            ? FirstMessageAuthor.student
            : FirstMessageAuthor.parent,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: widget.offer.teacherName,
        senderName: session.displayName,
        subject: widget.offer.subjectName,
        levelName: classe,
      ),
    );

    final libre = _message.text.trim();
    if (libre.isNotEmpty) {
      await conversations.send(
        conversationId: filId,
        senderId: session.userId,
        senderRole: session.role,
        body: libre,
      );
    }

    // Et le professeur l'apprend.
    //
    // Sans cela le message tombe dans un onglet qu'il n'a aucune raison
    // d'ouvrir : une demande de cours arrivait sans que rien ne s'allume sur
    // son accueil. Le compte vise est celui du professeur, pas sa fiche —
    // c'est `users.id` que portent les notifications.
    final compte = await ref
        .read(teacherRepositoryProvider)
        .userIdOf(widget.offer.teacherId);
    if (compte != null) {
      await ref
          .read(notificationRepositoryProvider)
          .push(
            userId: compte,
            kind: NotificationKind.message,
            title: 'Nouvelle demande de cours',
            body:
                '${session.displayName} vous ecrit au sujet de '
                '${widget.offer.subjectName}.',
            route: '/messages/$filId',
          );
    }
    return filId;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final children = ref.watch(parentChildrenProvider).valueOrNull ?? const [];
    final offer = widget.offer;

    // Un seul enfant : pas de choix à faire.
    if (children.length == 1) _childId ??= children.first.id;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Réserver des cours', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${offer.subjectName} avec ${offer.teacherName}'
                '${offer.hourlyRate == null ? '' : ' · ${Fmt.money(offer.hourlyRate!)} / h'}',
                style: text.bodyMedium,
              ),

              const Gap(AppSpacing.xl),
              Text('Pour quel enfant ?', style: text.titleSmall),
              const Gap(AppSpacing.sm),
              if (children.isEmpty)
                const InfoBanner(
                  message: 'Ajoutez d’abord votre enfant depuis votre profil.',
                  tone: StatusTone.warning,
                  icon: Icons.child_care_outlined,
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in children)
                      ChoiceChip(
                        label: Text(c.firstName),
                        selected: _childId == c.id,
                        onSelected: (_) => setState(() => _childId = c.id),
                      ),
                  ],
                ),

              const Gap(AppSpacing.xl),
              Text('À partir de quand ? (facultatif)', style: text.titleSmall),
              const Gap(AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _start == null ? 'Choisir une date' : Fmt.date(_start!),
                ),
              ),

              const Gap(AppSpacing.xl),
              Text(
                'Un mot pour le professeur (facultatif)',
                style: text.titleSmall,
              ),
              const Gap(AppSpacing.sm),
              TextField(
                controller: _message,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText:
                      'Elle a du mal avec les équations, surtout en '
                      'contrôle.',
                ),
              ),

              if (_error != null) ...[
                const Gap(AppSpacing.md),
                InfoBanner(
                  message: _error!,
                  tone: StatusTone.danger,
                  icon: Icons.error_outline,
                ),
              ],

              const Gap(AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy || _childId == null ? null : _send,
                  child: Text(_busy ? 'Envoi…' : 'Envoyer ma demande'),
                ),
              ),
              const Gap(AppSpacing.sm),
              Center(
                child: Text(
                  'Rien à payer maintenant. Le professeur vous répond ici.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _send() async {
    final parentId = ref.read(currentSessionProvider)?.parentId;
    if (parentId == null || _childId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final requestId = await ref
          .read(tutoringRepositoryProvider)
          .requestTutoring(
            parentId: parentId,
            offerId: widget.offer.id,
            childId: _childId!,
            message: _message.text,
            preferredStart: _start,
          );

      // Le fil s'ouvre maintenant, pas à l'acceptation.
      //
      // Il attendait que le professeur accepte. Entre-temps la famille
      // n'avait rien : ni trace de sa demande, ni endroit où poser une
      // question. Le professeur, lui, recevait une ligne dans une liste sans
      // savoir qui la lui envoyait.
      final fil = await _ouvrirLeFil(requestId);
      refreshTutoring(ref);
      refreshConversations(ref);
      if (mounted) Navigator.pop(context, fil);
    } on TutoringException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
