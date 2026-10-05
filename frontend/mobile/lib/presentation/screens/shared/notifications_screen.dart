import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Notifications (§53).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Rafraichit les rappels deductibles de l'état local a l'ouverture.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = ref.read(currentSessionProvider);
      if (session == null) return;
      await ref
          .read(notificationRepositoryProvider)
          .refreshLocalReminders(
            userId: session.userId,
            teacherId: session.teacherId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const BackButton(),
        actions: [
          if (session != null)
            TextButton(
              onPressed: () => ref
                  .read(notificationRepositoryProvider)
                  .markAllRead(session.userId),
              child: const Text('Tout lire'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Chargement impossible',
          message: '$error',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Aucune notification',
              message:
                  'Vous serez prevenu des qu’un document est vérifié, qu’une '
                  'offre correspond a votre profil ou qu’un établissement vous '
                  'contacte.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
            itemBuilder: (_, index) => _NotificationCard(item: items[index]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final (icon, tone) = _visual(item.kind);

    return AppCard(
      borderColor: item.read ? AppColors.border : AppColors.primarySurface,
      color: item.read ? null : AppColors.primarySurface,
      onTap: () async {
        await ref.read(notificationRepositoryProvider).markRead(item.id);
        if (item.route != null && context.mounted) context.push(item.route!);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: text.titleSmall)),
                    if (!item.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(item.body, style: text.bodySmall),
                const SizedBox(height: 6),
                Text(Fmt.relative(item.createdAt), style: text.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _visual(NotificationKind kind) => switch (kind) {
    NotificationKind.documentVerified => (Icons.verified, AppColors.success),
    NotificationKind.documentRejected => (
      Icons.cancel_outlined,
      AppColors.danger,
    ),
    NotificationKind.testAvailable => (
      Icons.assignment_outlined,
      AppColors.primary,
    ),
    NotificationKind.testPassed => (Icons.workspace_premium, AppColors.success),
    NotificationKind.newJob => (Icons.work_outline, AppColors.primary),
    NotificationKind.newApplication => (
      Icons.person_add_outlined,
      AppColors.primary,
    ),
    NotificationKind.interview => (Icons.event_outlined, AppColors.info),
    NotificationKind.message => (Icons.forum_outlined, AppColors.info),
    NotificationKind.offer => (Icons.mail_outline, AppColors.primary),
    NotificationKind.contract => (
      Icons.description_outlined,
      AppColors.primary,
    ),
    NotificationKind.recruitment => (
      Icons.handshake_outlined,
      AppColors.success,
    ),
    // Rouge, comme partout ailleurs pour « en direct ». C'est la seule
    // notification à laquelle répondre dans la minute : le cours est commencé.
    NotificationKind.liveStarting => (Icons.sensors, AppColors.danger),
    _ => (Icons.info_outline, AppColors.textSecondary),
  };
}
