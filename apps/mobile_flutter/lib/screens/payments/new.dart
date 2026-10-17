import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

const _methods = ['cash', 'bank_transfer', 'telebirr', 'chapa', 'cheque', 'other'];

final activeLeasesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listLeases(org.orgId!, status: 'active');
});

class NewPaymentScreen extends ConsumerStatefulWidget {
  final String? leaseId;
  const NewPaymentScreen({super.key, this.leaseId});

  @override
  ConsumerState<NewPaymentScreen> createState() => _NewPaymentScreenState();
}

class _NewPaymentScreenState extends ConsumerState<NewPaymentScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'cash';
  String? _leaseId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _leaseId = widget.leaseId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Map<String, dynamic>> leases) async {
    setState(() => _error = null);
    final selected = _leaseId != null
        ? leases.firstWhere((l) => l['id'] == _leaseId, orElse: () => const {})
        : const <String, dynamic>{};
    final lease = selected.isNotEmpty ? selected : (leases.isEmpty ? null : leases.first);
    if (lease == null) {
      setState(() => _error = 'Pick a lease.');
      return;
    }
    if (_amount.text.trim().isEmpty) {
      setState(() => _error = 'Enter an amount.');
      return;
    }
    setState(() => _busy = true);
    try {
      await recordPayment({
        'leaseId': lease['id'],
        'amount': _amount.text.trim(),
        'method': _method,
        'reference': _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'idempotencyKey': 'pay-${lease['id']}-${DateTime.now().millisecondsSinceEpoch}',
      });
      if (mounted) context.pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leases = ref.watch(activeLeasesProvider);
    final rows = leases.valueOrNull ?? const <Map<String, dynamic>>[];
    final selectedId = _leaseId ?? (rows.isNotEmpty ? rows.first['id'] as String? : null);
    final selected = rows.where((r) => r['id'] == selectedId).toList();

    return FamPage(
      title: 'Record payment',
      child: ListView(
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: FamColors.danger)),
            const SizedBox(height: 12),
          ],
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Lease', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const SizedBox(height: 8),
                leases.when(
                  loading: () => const FamLoading(),
                  error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(activeLeasesProvider)),
                  data: (data) => data.isEmpty
                      ? const EmptyState(message: 'No active leases. Create a tenant first.')
                      : Column(
                          children: data.take(50).map((l) {
                            final isSel = l['id'] == selectedId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => setState(() => _leaseId = l['id'] as String?),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isSel ? FamColors.royal : FamColors.border),
                                    borderRadius: BorderRadius.circular(12),
                                    color: isSel ? FamColors.tint : FamColors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${l['label'] ?? l['id'].toString().substring(0, 8)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                                      Text('${l['monthly_rent']} ETB', style: const TextStyle(color: FamColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Payment', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const SizedBox(height: 8),
                FamField(
                  label: selected.isNotEmpty ? 'Amount (ETB) · rent ${selected.first['monthly_rent']}' : 'Amount (ETB)',
                  controller: _amount,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Text('Method', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _methods
                      .map((m) => _method == m
                          ? FilledButton(onPressed: () => setState(() => _method = m), child: Text(m.replaceAll('_', ' ')))
                          : OutlinedButton(onPressed: () => setState(() => _method = m), child: Text(m.replaceAll('_', ' '))))
                      .toList(),
                ),
                const SizedBox(height: 12),
                FamField(label: 'Reference', controller: _reference),
                const SizedBox(height: 12),
                FamField(label: 'Notes', controller: _notes, maxLines: 3),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : () => _submit(rows), child: const Text('Save payment')),
        ],
      ),
    );
  }
}
