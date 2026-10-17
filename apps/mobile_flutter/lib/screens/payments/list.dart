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

final paymentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listPayments(org.orgId!);
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final payments = ref.watch(paymentsProvider);
    final canVoid = org.role == 'owner' || org.role == 'manager';

    return FamPage(
      title: 'Payments',
      floatingActionButton: FloatingActionButton(
        backgroundColor: FamColors.royal,
        foregroundColor: FamColors.white,
        onPressed: () => context.push('/app/payments/new'),
        child: const Icon(Icons.add),
      ),
      child: payments.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(paymentsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(paymentsProvider),
          child: rows.isEmpty
              ? ListView(children: const [SizedBox(height: 120), EmptyState(message: 'No payments yet.')])
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = rows[i];
                    final voided = p['voided_at'] != null;
                    return FamCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${p['receipt_no'] ?? 'receipt'}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                              Text(voided ? 'void' : formatMoney(p['amount']),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: voided ? FamColors.textMuted : FamColors.navy,
                                  )),
                            ],
                          ),
                          Text('${p['method']} · ${p['paid_at']}', style: const TextStyle(color: FamColors.textMuted)),
                          if (p['reference'] != null)
                            Text('Ref ${p['reference']}', style: const TextStyle(color: FamColors.textMuted)),
                          if (canVoid && !voided) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => _confirmVoid(context, ref, p['id'] as String),
                              child: const Text('Void'),
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

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void payment'),
        content: const Text('This reverses the allocation. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Void')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await voidPayment(id, 'voided by user');
      ref.invalidate(paymentsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    }
  }
}
