import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
      subtitle: 'Items currently out with tenants',
      child: rentals.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(
            message: userMessage(e), onRetry: () => ref.invalidate(stockRentalsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(stockRentalsProvider),
          child: rows.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'Nothing rented out',
                    message: 'Rent a stock item from the Stock screen and it shows up here.',
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
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
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: open ? FamColors.tint : FamColors.chipBg,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.handshake_outlined,
                                  size: 22,
                                  color: open ? FamColors.royal : FamColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${items?['name'] ?? 'Item'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: FamFonts.body,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: FamColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${r['quantity']} × ${formatMoney(r['daily_rate'])}/day · '
                                      'to ${tenants?['full_name'] ?? 'tenant'}',
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
                                foreground: open ? FamColors.royal : FamColors.textMuted,
                                background: open ? FamColors.tint : FamColors.chipBg,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FamInfoRow(
                            label: 'Rental period',
                            value: '${r['start_date']} → ${r['due_date']}',
                            icon: Icons.event_outlined,
                          ),
                          if (open) ...[
                            const SizedBox(height: 12),
                            FamPrimaryButton(
                              label: 'Mark returned',
                              icon: Icons.assignment_turned_in_outlined,
                              height: 48,
                              dense: true,
                              onPressed: () => _confirmReturn(context, ref, r['id'] as String),
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
