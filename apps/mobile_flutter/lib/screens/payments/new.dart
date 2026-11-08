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
import '../home/dashboard.dart' show dashboardProvider;
import '../rent/list.dart' show rentProvider;
import '../tenants/detail.dart' show tenantProvider;
import 'list.dart' show paymentsProvider;

const _methods = ['cash', 'bank_transfer', 'telebirr', 'chapa', 'cheque', 'other'];

final activeLeasesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  // Load the whole active set (up to the API cap) so a lease passed in the URL
  // is always found, even when the org has more than a screenful of leases.
  return listLeases(org.orgId!, status: 'active', limit: 1000);
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
    // A lease passed in the URL (from the Rent screen or a tenant) must be the
    // one paid. Falling back to the first lease would silently record the money
    // against somebody else's tenancy, so refuse instead.
    Map<String, dynamic>? lease;
    if (_leaseId != null) {
      final match = leases.where((l) => l['id'] == _leaseId).toList();
      if (match.isEmpty) {
        setState(() => _error = 'That lease is no longer active. Pick another lease.');
        return;
      }
      lease = match.first;
    } else if (leases.isNotEmpty) {
      lease = leases.first;
    }
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
      if (!mounted) return;
      // The list, rent and tenant screens underneath are still mounted, so
      // their cached rows must be refreshed explicitly before popping back.
      ref.invalidate(paymentsProvider);
      ref.invalidate(rentProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(tenantProvider);
      context.pop();
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
    // The lease may have ended between opening this screen and loading the
    // list: say so instead of leaving the form looking empty.
    final requestedMissing = _leaseId != null &&
        rows.isNotEmpty &&
        !rows.any((r) => r['id'] == _leaseId);

    return FamPage(
      title: 'Record payment',
      subtitle: 'Against an active lease',
      child: ListView(
        children: [
          if (_error != null) ...[
            FamNotice.error(_error!),
            const SizedBox(height: 14),
          ],
          if (requestedMissing) ...[
            FamNotice.error('That lease is no longer active. Choose another lease below.'),
            const SizedBox(height: 14),
          ],
          const FamSectionHeader(title: 'Lease'),
          const SizedBox(height: 10),
          leases.when(
            loading: () => const FamLoading(),
            error: (e, _) => ErrorState(
                message: userMessage(e), onRetry: () => ref.invalidate(activeLeasesProvider)),
            data: (data) => data.isEmpty
                ? const EmptyState(
                    icon: Icons.people_alt_rounded,
                    title: 'No active leases',
                    message: 'Add a tenant first, then record their rent here.',
                  )
                : Column(
                    children: data.take(50).map((l) {
                      final isSel = l['id'] == selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: isSel ? FamColors.tint : FamColors.white,
                          borderRadius: BorderRadius.circular(FamRadius.button),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(FamRadius.button),
                            onTap: () => setState(() => _leaseId = l['id'] as String?),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSel ? FamColors.royal : FamColors.border,
                                  width: isSel ? 1.6 : 1,
                                ),
                                borderRadius: BorderRadius.circular(FamRadius.button),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${l['label'] ?? l['id'].toString().substring(0, 8)}',
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
                                  const SizedBox(width: 8),
                                  Text(
                                    '${formatMoney(l['monthly_rent'], decimals: 0)}/mo',
                                    style: const TextStyle(
                                      fontFamily: FamFonts.body,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: FamColors.textMuted,
                                    ),
                                  ),
                                  if (isSel) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle_rounded,
                                        size: 20, color: FamColors.royal),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          const FamSectionHeader(title: 'Payment'),
          const SizedBox(height: 10),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FamField(
                  label: selected.isNotEmpty
                      ? 'Amount (ETB) · rent ${formatMoney(selected.first['monthly_rent'], decimals: 0)}'
                      : 'Amount (ETB)',
                  hint: '0.00',
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Method',
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FamColors.textLabel,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _methods
                      .map((m) => _method == m
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: () => setState(() => _method = m),
                              child: Text(m.replaceAll('_', ' ')),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: () => setState(() => _method = m),
                              child: Text(m.replaceAll('_', ' ')),
                            ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                FamField(
                  label: 'Reference (optional)',
                  hint: 'Bank or Telebirr reference',
                  controller: _reference,
                  prefixIcon: Icons.tag_rounded,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'Notes (optional)',
                  controller: _notes,
                  maxLines: 3,
                  prefixIcon: Icons.notes_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FamPrimaryButton(
            label: 'Save payment',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _busy ? null : () => _submit(rows),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
