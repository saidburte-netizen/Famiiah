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

const _adjustTypes = ['in', 'out', 'adjustment'];

final stockItemsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listStockItems(org.orgId!);
});

/// Which subset of the catalogue is on screen: everything, or only items at or
/// below their reorder point (the `list_low_stock` RPC).
final stockFilterProvider = StateProvider<String>((_) => 'all');

final lowStockProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listLowStock(org.orgId!);
});

final stockTenantsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listTenantsWithStatus(org.orgId!, 'all');
});

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(stockFilterProvider);
    final items = filter == 'low' ? ref.watch(lowStockProvider) : ref.watch(stockItemsProvider);
    final tenants = ref.watch(stockTenantsProvider).valueOrNull ?? const <Map<String, dynamic>>[];

    return FamPage(
      title: 'Stock',
      actions: [
        TextButton(
          onPressed: () => context.push('/app/stock/rentals'),
          child: const Text('Rentals', style: TextStyle(color: FamColors.white)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: filter == 'all'
                    ? FilledButton(
                        onPressed: () => ref.read(stockFilterProvider.notifier).state = 'all',
                        child: const Text('All items'))
                    : OutlinedButton(
                        onPressed: () => ref.read(stockFilterProvider.notifier).state = 'all',
                        child: const Text('All items')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: filter == 'low'
                    ? FilledButton(
                        onPressed: () => ref.read(stockFilterProvider.notifier).state = 'low',
                        child: const Text('Low stock'))
                    : OutlinedButton(
                        onPressed: () => ref.read(stockFilterProvider.notifier).state = 'low',
                        child: const Text('Low stock')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.when(
              loading: () => const FamLoading(),
              error: (e, _) => ErrorState(
                  message: userMessage(e),
                  onRetry: () =>
                      ref.invalidate(filter == 'low' ? lowStockProvider : stockItemsProvider)),
              data: (rows) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(filter == 'low' ? lowStockProvider : stockItemsProvider),
                child: rows.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        EmptyState(
                            message: filter == 'low'
                                ? 'No items are below their minimum quantity.'
                                : 'No stock items yet.')
                      ])
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = rows[i];
                          final low =
                              (item['quantity'] as num? ?? 0) <= (item['min_quantity'] as num? ?? 0);
                          final rentable = item['is_rentable'] == true;
                          return FamCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item['name']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, color: FamColors.navy)),
                                    Text('${item['quantity']} ${item['uom']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: low ? FamColors.danger : FamColors.textMuted,
                                        )),
                                  ],
                                ),
                                Text(
                                  '${item['sku'] ?? 'no sku'}'
                                  '${item['category'] != null ? ' · ${item['category']}' : ''}'
                                  '${rentable ? ' · rentable' : ''}',
                                  style: const TextStyle(color: FamColors.textMuted),
                                ),
                                if (low)
                                  Text('Low stock (min ${item['min_quantity']})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, color: FamColors.danger)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _showAdjust(context, ref, item),
                                        child: const Text('Adjust'),
                                      ),
                                    ),
                                    if (rentable && (item['quantity'] as num? ?? 0) > 0) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () => _showRent(context, ref, item, tenants),
                                          child: const Text('Rent out'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdjust(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => _AdjustSheet(item: item, onDone: () async {
        ref.invalidate(stockItemsProvider);
        ref.invalidate(lowStockProvider);
      }),
    );
  }

  Future<void> _showRent(
      BuildContext context, WidgetRef ref, Map<String, dynamic> item, List<Map<String, dynamic>> tenants) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => _RentSheet(
        item: item,
        tenants: tenants,
        onDone: () async {
          ref.invalidate(stockItemsProvider);
          ref.invalidate(lowStockProvider);
        },
      ),
    );
  }
}

class _AdjustSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final Future<void> Function() onDone;
  const _AdjustSheet({required this.item, required this.onDone});

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _qty = TextEditingController();
  final _reason = TextEditingController();
  String _type = 'in';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await stockAdjust(widget.item['id'] as String, _type, _qty.text.trim(),
          reason: _reason.text.trim().isEmpty ? null : _reason.text.trim());
      await widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.item['name']}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Movement', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                  const SizedBox(height: 8),
                  Row(
                    children: _adjustTypes
                        .map((t) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _type == t
                                    ? FilledButton(onPressed: () => setState(() => _type = t), child: Text(t))
                                    : OutlinedButton(onPressed: () => setState(() => _type = t), child: Text(t)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FamField(
                    label: _type == 'adjustment' ? 'Counted quantity' : 'Quantity',
                    controller: _qty,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  FamField(label: 'Reason', controller: _reason),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> tenants;
  final Future<void> Function() onDone;
  const _RentSheet({required this.item, required this.tenants, required this.onDone});

  @override
  State<_RentSheet> createState() => _RentSheetState();
}

class _RentSheetState extends State<_RentSheet> {
  String? _tenantId;
  late final TextEditingController _qty = TextEditingController(text: '1');
  late final TextEditingController _rate = TextEditingController(text: '${widget.item['rental_rate'] ?? ''}');
  late final TextEditingController _due = TextEditingController(
      text: DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10));
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _qty.dispose();
    _rate.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_tenantId == null) {
      setState(() => _error = 'Choose a tenant.');
      return;
    }
    setState(() => _busy = true);
    try {
      await rentStockItem({
        'itemId': widget.item['id'],
        'tenantId': _tenantId,
        'qty': _qty.text.trim(),
        'rate': _rate.text.trim().isEmpty ? null : _rate.text.trim(),
        'due': _due.text.trim(),
      });
      await widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rent out', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 4),
            Text(
              '${widget.item['name']} · ${widget.item['quantity']} ${widget.item['uom']} available'
              '${widget.item['rental_rate'] != null ? ' · ${formatMoney(widget.item['rental_rate'])}/day' : ''}',
              style: const TextStyle(color: FamColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tenant', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                  const SizedBox(height: 8),
                  if (widget.tenants.isEmpty)
                    const EmptyState(message: 'No tenants yet.')
                  else
                    ...widget.tenants.take(30).map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _tenantId == t['id']
                              ? FilledButton(
                                  onPressed: () => setState(() => _tenantId = t['id'] as String?),
                                  child: Text('${t['full_name'] ?? t['id'].toString().substring(0, 8)}'))
                              : OutlinedButton(
                                  onPressed: () => setState(() => _tenantId = t['id'] as String?),
                                  child: Text('${t['full_name'] ?? t['id'].toString().substring(0, 8)}')),
                        )),
                  const SizedBox(height: 12),
                  FamField(label: 'Quantity', controller: _qty, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  FamField(label: 'Daily rate (ETB)', controller: _rate, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  FamField(label: 'Due date (YYYY-MM-DD)', controller: _due),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('Rent out')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
