import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/repositories/conversations_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hero.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Les fils de discussion entre une famille et un professeur.
///
/// Ouverts au moment où le professeur accepte une demande : avant, les deux
/// n'ont rien à se dire ; après, ils n'avaient aucun endroit pour le faire et
/// devaient sortir de l'application.
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fils = ref.watch(conversationsProvider);

    return RefreshIndicator(
      onRefresh: () async => refreshConversations(ref),
      child: AsyncGate(
        value: fils,
        placeholder: const SkeletonDashboard(cards: [1, 4]),
        error: (_) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Messages indisponibles',
          message: 'Réessayez dans un instant.',
        ),
        data: (items) {
          final nonLus = items.fold<int>(0, (n, c) => n + c.unread);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              GradientHero(
                title: 'Messages',
                subtitle: nonLus == 0
                    ? 'Vos échanges avec les familles et les professeurs'
                    : nonLus == 1
                    ? '1 message non lu'
                    : '$nonLus messages non lus',
              ),
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
                    if (items.isEmpty)
                      const KitEmpty(
                        icon: Icons.forum_outlined,
                        message:
                            'Aucune conversation. Elle s’ouvre dès qu’un '
                            'professeur accepte une demande de cours.',
                      )
                    else
                      for (final fil in items)
                        PersonRow(
                          name: fil.otherName,
                          subtitle: fil.lastMessage ?? fil.subtitle,
                          chips: [
                            if (fil.subtitle.isNotEmpty)
                              TagChip(
                                label: fil.subtitle,
                                tone: StatusTone.primary,
                              ),
                            if (fil.unread > 0)
                              TagChip(
                                label: fil.unread == 1
                                    ? '1 non lu'
                                    : '${fil.unread} non lus',
                                tone: StatusTone.danger,
                              ),
                          ],
                          meta: [
                            if (fil.lastAt != null)
                              MetaText(Fmt.relative(fil.lastAt!)),
                          ],
                          onTap: () => context.push('/messages/${fil.id}'),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Un fil ouvert.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<ConversationScreen> {
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final userId = ref.read(currentSessionProvider)?.userId;
    if (userId == null || !mounted) return;
    await ref
        .read(conversationsRepositoryProvider)
        .markRead(widget.conversationId, userId);
    if (mounted) ref.invalidate(conversationsProvider);
  }

  Future<void> _send() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || _input.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(conversationsRepositoryProvider)
          .send(
            conversationId: widget.conversationId,
            senderId: session.userId,
            senderRole: session.role,
            body: _input.text,
          );
      _input.clear();
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final userId = ref.watch(currentSessionProvider)?.userId;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Message')),
      body: Column(
        children: [
          Expanded(
            child: AsyncGate(
              value: messages,
              placeholder: const SkeletonDashboard(cards: [4]),
              error: (_) => const EmptyState(
                icon: Icons.error_outline,
                title: 'Conversation indisponible',
              ),
              data: (items) => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (items.isEmpty)
                    const KitEmpty(
                      icon: Icons.waving_hand_outlined,
                      message:
                          'Écrivez le premier message. Les numéros et les '
                          'adresses restent masqués tant que rien n’est '
                          'conclu.',
                    )
                  else
                    for (final m in items)
                      _Bubble(message: m, mine: m.senderId == userId),
                ],
              ),
            ),
          ),

          // La règle est dite une fois, sous le champ, et non découverte
          // après coup en voyant son numéro remplacé.
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Votre message…',
                          helperText:
                              'Numéros et adresses masqués pour l’instant',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: _busy ? null : _send,
                      tooltip: 'Envoyer le message',
                      icon: const Icon(Icons.send, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ConversationMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: mine ? null : AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.body,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: mine ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.time(message.sentAt),
            style: TextStyle(
              fontSize: 12,
              color: mine ? AppColors.onHeroMuted : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    ),
  );
}
