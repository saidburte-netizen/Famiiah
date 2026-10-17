import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
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
    final text = Theme.of(context).textTheme;

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
          Text('Rent', style: text.displayLarge?.copyWith(color: FamColors.midnight)),
          const SizedBox(height: 12),
          rent.when(
            loading: () => const FamLoading(),
            error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(rentProvider)),
            data: (data) {
              final rows = (data['rows'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () => context.push('/app/payments/new'),
                      child: const Text('Record payment'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _stat(context, 'Expected', formatMoney(data['expected']))),
                        Expanded(child: _stat(context, 'Collected', formatMoney(data['collected']))),
                        Expanded(child: _stat(context, 'Outstanding', formatMoney(data['outstanding']))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => ref.invalidate(rentProvider),
                        child: rows.isEmpty
                            ? ListView(children: const [SizedBox(height: 120), EmptyState(message: 'No charges this month.')])
                            : ListView.separated(
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

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: FamColors.textMuted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
      ],
    );
  }

  Widget _rentCard(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final status = '${item['status']}';
    final owes = ['overdue', 'pending', 'partial'].contains(status);
    return InkWell(
      onTap: () => context.push('/app/payments/new?leaseId=${item['lease_id']}'),
      borderRadius: BorderRadius.circular(FamRadius.card),
      child: FamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${item['tenant_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                Text(status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: status == 'overdue' ? FamColors.danger : FamColors.textMuted,
                    )),
              ],
            ),
            Text('${item['unit_code']} · due ${item['due_date']} · ${formatMoney(item['amount'])}',
                style: const TextStyle(color: FamColors.textMuted)),
            Text('Paid ${formatMoney(item['amount_paid'])}', style: const TextStyle(color: FamColors.textMuted)),
            if (owes) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await sendReminder(item['id'] as String);
                    messenger.showSnackBar(const SnackBar(content: Text('Reminder sent')));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
                  }
                },
                child: const Text('Send reminder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
