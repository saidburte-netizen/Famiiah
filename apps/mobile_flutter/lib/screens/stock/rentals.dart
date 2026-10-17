import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final stockRentalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listStockRentals(org.orgId!);
});

class StockRentalsScreen extends ConsumerWidget {
  const StockRentalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentals = ref.watch(stockRentalsProvider);

    return FamPage(
      title: 'Stock rentals',
      child: rentals.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(stockRentalsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(stockRentalsProvider),
          child: rows.isEmpty
              ? ListView(children: const [SizedBox(height: 120), EmptyState(message: 'Nothing rented out.')])
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final items = r['stock_items'] as Map<String, dynamic>?;
                    final tenants = r['tenants'] as Map<String, dynamic>?;
                    final status = '${r['status']}';
                    final open = status == 'out' || status == 'overdue';
                    return FamCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${items?['name'] ?? 'Item'}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                              Text(status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: open ? FamColors.navy : FamColors.textMuted,
                                  )),
                            ],
                          ),
                          Text(
                            '${r['quantity']} × ${formatMoney(r['daily_rate'])}/day · to ${tenants?['full_name'] ?? 'tenant'}',
                            style: const TextStyle(color: FamColors.textMuted),
                          ),
                          Text('${r['start_date']} → ${r['due_date']}', style: const TextStyle(color: FamColors.textMuted)),
                          if (open) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => _confirmReturn(context, ref, r['id'] as String),
                              child: const Text('Return'),
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

  Future<void> _confirmReturn(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return item'),
        content: const Text('Mark this rental as returned?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await returnStockItem(id);
      ref.invalidate(stockRentalsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    }
  }
}
