import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
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
        TextButton(
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
          child: const Text('Mark all read', style: TextStyle(color: FamColors.white)),
        ),
      ],
      child: notifications.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: rows.isEmpty
              ? ListView(children: const [SizedBox(height: 120), EmptyState(message: "You're all caught up.")])
              : ListView.separated(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('${n['title']}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                              ),
                              if (unread)
                                const Text('New',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.royal)),
                            ],
                          ),
                          if (n['body'] != null)
                            Text('${n['body']}', style: const TextStyle(color: FamColors.textMuted)),
                          Text('${n['created_at']}', style: const TextStyle(color: FamColors.textMuted)),
                          if (unread) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
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
                              child: const Text('Mark read'),
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
