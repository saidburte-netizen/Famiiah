import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../i18n/strings.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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

/// Archived (soft-deleted) stock items, for the restore view.
final archivedStockProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listArchivedStockItems(org.orgId!);
});

final showArchivedStockProvider = StateProvider<bool>((_) => false);

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(stockFilterProvider);
    final archived = ref.watch(showArchivedStockProvider);
    final items = filter == 'low' ? ref.watch(lowStockProvider) : ref.watch(stockItemsProvider);
    final tenants = ref.watch(stockTenantsProvider).valueOrNull ?? const <Map<String, dynamic>>[];

    return FamPage(
      title: 'Stock',
      subtitle: archived ? 'Archived items' : 'Items, adjustments and rentals',
      actions: [
        FamIconButton(
          icon: archived ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          tooltip: archived ? t('common.hideArchived') : t('common.showArchived'),
          background: FamColors.background,
          size: 40,
          onPressed: () =>
              ref.read(showArchivedStockProvider.notifier).state = !archived,
        ),
        const SizedBox(width: 10),
        if (!archived)
          FamIconButton(
            icon: Icons.handshake_outlined,
            tooltip: 'Rentals',
            size: 40,
            onPressed: () => context.push('/app/stock/rentals'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!archived) ...[
          FamSegmented(
            labels: const ['All items', 'Low stock'],
            selected: filter == 'low' ? 1 : 0,
            onChanged: (i) => ref.read(stockFilterProvider.notifier).state = i == 1 ? 'low' : 'all',
          ),
          const SizedBox(height: 14),
          ],
          Expanded(
            child: archived
                ? _ArchivedStockList(
                    onRestore: (row) async {
                      await restoreStockItem(row['id'] as String);
                      ref.invalidate(archivedStockProvider);
                      ref.invalidate(stockItemsProvider);
                      ref.invalidate(lowStockProvider);
                    },
                  )
                : items.when(
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
                        const SizedBox(height: 80),
                        EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: filter == 'low' ? 'Nothing running low' : 'No stock items yet',
                            message: filter == 'low'
                                ? 'No items are below their minimum quantity.'
                                : 'Add items to track quantities, movements and rentals.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
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
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: low ? FamColors.dangerBg : FamColors.tint,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(Icons.inventory_2_outlined,
                                          size: 22,
                                          color: low ? FamColors.danger : FamColors.royal),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item['name']}',
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
                                            '${item['sku'] ?? 'no sku'}'
                                            '${item['category'] != null ? ' · ${item['category']}' : ''}'
                                            '${rentable ? ' · rentable' : ''}',
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item['quantity']}',
                                          style: TextStyle(
                                            fontFamily: FamFonts.body,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: low ? FamColors.danger : FamColors.navy,
                                          ),
                                        ),
                                        Text(
                                          '${item['uom']}',
                                          style: const TextStyle(
                                            fontFamily: FamFonts.body,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: FamColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: t('common.manage'),
                                      icon: const Icon(Icons.more_vert_rounded,
                                          size: 20, color: FamColors.textMuted),
                                      onSelected: (v) {
                                        if (v == 'archive') {
                                          _archive(context, ref, item);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'archive',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.archive_outlined,
                                                  size: 18, color: FamColors.danger),
                                              const SizedBox(width: 10),
                                              Text(t('common.archive')),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (low) ...[
                                  const SizedBox(height: 10),
                                  FamBadge(
                                    label: 'Low stock · min ${item['min_quantity']}',
                                    foreground: FamColors.danger,
                                    background: FamColors.dangerBg,
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FamSecondaryButton(
                                        label: 'Adjust',
                                        height: 46,
                                        dense: true,
                                        filled: true,
                                        onPressed: () => _showAdjust(context, ref, item),
                                      ),
                                    ),
                                    if (rentable && (item['quantity'] as num? ?? 0) > 0) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FamPrimaryButton(
                                          label: 'Rent out',
                                          height: 46,
                                          dense: true,
                                          onPressed: () => _showRent(context, ref, item, tenants),
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

  /// Archive a catalogue item. The server refuses while it is rented out or
  /// still has stock on hand.
  Future<void> _archive(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final ok = await famConfirm(
      context,
      title: t('common.archiveTitle'),
      message: t('common.archiveBody'),
      confirmLabel: t('common.archive'),
      danger: true,
    );
    if (!ok) return;
    try {
      await archiveStockItem(item['id'] as String);
      ref.invalidate(stockItemsProvider);
      ref.invalidate(lowStockProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}

/// A read-only list of archived stock items with a Restore action on each.
class _ArchivedStockList extends ConsumerWidget {
  final Future<void> Function(Map<String, dynamic> row) onRestore;

  const _ArchivedStockList({required this.onRestore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archivedStockProvider);
    return async.when(
      loading: () => const FamLoading(),
      error: (e, _) => ErrorState(
        message: userMessage(e),
        onRetry: () => ref.invalidate(archivedStockProvider),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(archivedStockProvider),
        child: rows.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.archive_outlined,
                  title: t('common.noArchived'),
                  message: 'Items you archive will appear here so you can restore them.',
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final name = '${r['name'] ?? r['id']}';
                  final sub = '${r['sku'] ?? 'no sku'} · ${r['quantity']} ${r['uom'] ?? ''}';
                  return FamCard(
                    child: Row(
                      children: [
                        const Icon(Icons.archive_outlined, size: 22, color: FamColors.textMuted),
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
                              Text(
                                sub,
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
                        const SizedBox(width: 10),
                        FamSecondaryButton(
                          label: t('common.restore'),
                          height: 42,
                          dense: true,
                          filled: true,
                          onPressed: () async {
                            final ok = await famConfirm(
                              context,
                              title: t('common.restoreTitle'),
                              message: t('common.restoreBody'),
                              confirmLabel: t('common.restore'),
                            );
                            if (!ok) return;
                            try {
                              await onRestore(r);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(userMessage(e))));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Stock movement',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item['name']} · ${widget.item['quantity']} ${widget.item['uom']} on hand',
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FamNotice.error(_error!),
              const SizedBox(height: 14),
            ],
            _ChoiceRow(
              label: 'Movement',
              options: _adjustTypes,
              value: _type,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 18),
            FamField(
              label: _type == 'adjustment' ? 'Counted quantity' : 'Quantity',
              controller: _qty,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.numbers_rounded,
            ),
            const SizedBox(height: 14),
            FamField(
              label: 'Reason (optional)',
              controller: _reason,
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: 20),
            FamPrimaryButton(
              label: 'Save movement',
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 10),
            FamSecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rent out',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item['name']} · ${widget.item['quantity']} ${widget.item['uom']} available'
              '${widget.item['rental_rate'] != null ? ' · ${formatMoney(widget.item['rental_rate'])}/day' : ''}',
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FamNotice.error(_error!),
              const SizedBox(height: 14),
            ],
            const FamSectionHeader(title: 'Tenant'),
            const SizedBox(height: 10),
            if (widget.tenants.isEmpty)
              const EmptyState(
                icon: Icons.people_alt_rounded,
                title: 'No tenants yet',
                message: 'Add a tenant before renting stock out.',
              )
            else
              ...widget.tenants.take(30).map((t) {
                final selected = _tenantId == t['id'];
                final name = '${t['full_name'] ?? t['id'].toString().substring(0, 8)}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: selected ? FamColors.tint : FamColors.white,
                    borderRadius: BorderRadius.circular(FamRadius.button),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(FamRadius.button),
                      onTap: () => setState(() => _tenantId = t['id'] as String?),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected ? FamColors.royal : FamColors.border,
                            width: selected ? 1.6 : 1,
                          ),
                          borderRadius: BorderRadius.circular(FamRadius.button),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: FamFonts.body,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: FamColors.navy,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  size: 20, color: FamColors.royal),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            const FamSectionHeader(title: 'Rental'),
            const SizedBox(height: 10),
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FamField(
                    label: 'Quantity',
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.numbers_rounded,
                  ),
                  const SizedBox(height: 14),
                  FamField(
                    label: 'Daily rate (ETB)',
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.payments_outlined,
                  ),
                  const SizedBox(height: 14),
                  FamField(
                    label: 'Due date (YYYY-MM-DD)',
                    controller: _due,
                    prefixIcon: Icons.event_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FamPrimaryButton(
              label: 'Rent out',
              icon: Icons.check_rounded,
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 10),
            FamSecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// Movement chooser: the active option is a filled navy pill.
class _ChoiceRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: FamFonts.body,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FamColors.textLabel,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((o) => o == value
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => onChanged(o),
                      child: Text(o),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => onChanged(o),
                      child: Text(o),
                    ))
              .toList(),
        ),
      ],
    );
  }
}
