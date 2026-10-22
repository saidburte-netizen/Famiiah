import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listNotifications(org.orgId!);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return FamPage(
      title: 'Notifications',
      actions: [
        FamIconButton(
          icon: Icons.done_all_rounded,
          tooltip: 'Mark all read',
          background: FamColors.white,
          size: 40,
          onPressed: () async {
            final orgId = ref.read(orgProvider).orgId;
            if (orgId == null) return;
            try {
              await markAllNotificationsRead(orgId);
              ref.invalidate(notificationsProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
              }
            }
          },
        ),
      ],
      child: notifications.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: rows.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: "You're all caught up",
                    message: 'Reminders, receipts and overdue alerts land here.',
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final n = rows[i];
                    final unread = n['status'] != 'read';
                    return FamCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: unread ? FamColors.tint : FamColors.chipBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  unread
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_none_rounded,
                                  size: 20,
                                  color: unread ? FamColors.royal : FamColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${n['title']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: FamFonts.body,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: FamColors.navy,
                                  ),
                                ),
                              ),
                              if (unread) ...[
                                const SizedBox(width: 8),
                                const FamBadge(label: 'New'),
                              ],
                            ],
                          ),
                          if (n['body'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${n['body']}',
                              style: const TextStyle(
                                fontFamily: FamFonts.body,
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: FamColors.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${n['created_at']}',
                            style: const TextStyle(
                              fontFamily: FamFonts.body,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FamColors.textFaint,
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(height: 12),
                            FamSecondaryButton(
                              label: 'Mark read',
                              height: 44,
                              dense: true,
                              onPressed: () async {
                                try {
                                  await markNotificationRead(n['id'] as String);
                                  ref.invalidate(notificationsProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text(userMessage(e))));
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
