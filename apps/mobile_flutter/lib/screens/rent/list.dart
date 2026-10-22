import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final rentProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const {};
  final month = '${DateTime.now().toIso8601String().substring(0, 7)}-01';
  return rentOverview(org.orgId!, month);
});

class RentScreen extends ConsumerWidget {
  const RentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final rent = ref.watch(rentProvider);

    if (org.loading) return const Center(child: CircularProgressIndicator(color: FamColors.royal));
    if (org.error != null) {
      return FamScreen(
        child: ErrorState(message: userMessage(org.error), onRetry: () => ref.read(orgProvider.notifier).refresh()),
      );
    }

    return FamScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FamScreenHeader(
            title: 'Rent',
            subtitle: 'Charges, collections and reminders',
          ),
          const SizedBox(height: 16),
          rent.when(
            loading: () => const FamLoading(),
            error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(rentProvider)),
            data: (data) {
              final rows = (data['rows'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
              final expected = (data['expected'] as num?)?.toDouble() ?? 0;
              final collected = (data['collected'] as num?)?.toDouble() ?? 0;
              final rate = expected <= 0 ? 0.0 : collected / expected;
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FamHeroCard(
                      label: 'Collected this month',
                      value: formatMoney(data['collected'], decimals: 0),
                      trailing: '${(rate * 100).toStringAsFixed(0)}%',
                      progress: rate,
                      caption: '${formatMoney(data['outstanding'], decimals: 0)} outstanding',
                      height: 92,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FamPrimaryButton(
                            label: 'Record',
                            icon: Icons.add_card_rounded,
                            height: 48,
                            dense: true,
                            onPressed: () => context.push('/app/payments/new'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FamSecondaryButton(
                            label: 'History',
                            icon: Icons.receipt_long_outlined,
                            height: 48,
                            dense: true,
                            filled: true,
                            onPressed: () => context.push('/app/payments'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FamSecondaryButton(
                      label: 'Remind unpaid tenants',
                      icon: Icons.notifications_active_outlined,
                      height: 48,
                      dense: true,
                      onPressed: () => _remindUnpaid(context, ref),
                    ),
                    const SizedBox(height: 16),
                    const FamSectionHeader(title: 'This month'),
                    const SizedBox(height: 10),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => ref.invalidate(rentProvider),
                        child: rows.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 80),
                                EmptyState(
                                  icon: Icons.event_available_outlined,
                                  title: 'No charges this month',
                                  message: 'Once leases are active, their monthly rent shows up here.',
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) => _rentCard(context, ref, rows[i]),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _remindUnpaid(BuildContext context, WidgetRef ref) async {
    final orgId = ref.read(orgProvider).orgId;
    if (orgId == null) return;
    final month = '${DateTime.now().toIso8601String().substring(0, 7)}-01';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sent = await sendRemindersBulk(orgId, month);
      messenger.showSnackBar(SnackBar(content: Text('Queued $sent reminder(s).')));
      ref.invalidate(rentProvider);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(err))));
    }
  }

  Widget _rentCard(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final status = '${item['status']}';
    final owes = ['overdue', 'pending', 'partial'].contains(status);
    final overdue = status == 'overdue';
    final name = '${item['tenant_name']}';
    return FamCard(
      onTap: () => context.push('/app/payments/new?leaseId=${item['lease_id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FamAvatar(
                name: name,
                size: 44,
                background: overdue ? FamColors.dangerBg : FamColors.tint,
                foreground: overdue ? FamColors.danger : FamColors.royalMid,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: FamColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['unit_code']} · due ${item['due_date']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FamColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FamBadge(
                label: status,
                foreground: overdue ? FamColors.danger : FamColors.textMuted,
                background: overdue ? FamColors.dangerBg : FamColors.chipBg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rent ${formatMoney(item['amount'], decimals: 0)}',
                  style: const TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FamColors.text,
                  ),
                ),
              ),
              Text(
                'Paid ${formatMoney(item['amount_paid'], decimals: 0)}',
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FamColors.textMuted,
                ),
              ),
            ],
          ),
          if (owes) ...[
            const SizedBox(height: 12),
            FamSecondaryButton(
              label: 'Send reminder',
              icon: Icons.notifications_active_outlined,
              height: 46,
              dense: true,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await sendReminder(item['id'] as String);
                  messenger.showSnackBar(const SnackBar(content: Text('Reminder sent')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
