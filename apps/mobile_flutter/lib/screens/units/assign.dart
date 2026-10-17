import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';
import '../properties/detail.dart';

/// Tenants that can still take a unit: anyone without an active lease.
/// `list_tenants_with_status` returns `unit_code == null` in that case, and the
/// `assign_tenant_to_unit` RPC itself does not guard against double-assigning.
final assignableTenantsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  final rows = await listTenantsWithStatus(org.orgId!, 'all');
  return rows.where((t) => t['unit_code'] == null).toList();
});

class AssignTenantScreen extends ConsumerStatefulWidget {
  final String unitId;
  final String? propertyId;
  final String? unitCode;
  final String? monthlyRent;

  const AssignTenantScreen({
    super.key,
    required this.unitId,
    this.propertyId,
    this.unitCode,
    this.monthlyRent,
  });

  @override
  ConsumerState<AssignTenantScreen> createState() => _AssignTenantScreenState();
}

class _AssignTenantScreenState extends ConsumerState<AssignTenantScreen> {
  final _startDate = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _endDate = TextEditingController();
  late final TextEditingController _monthlyRent =
      TextEditingController(text: widget.monthlyRent?.toString() ?? '');
  final _deposit = TextEditingController(text: '0');
  String? _tenantId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _startDate.dispose();
    _endDate.dispose();
    _monthlyRent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Map<String, dynamic>> tenants) async {
    setState(() => _error = null);
    if (_tenantId == null) {
      setState(() => _error = 'Choose a tenant.');
      return;
    }
    setState(() => _busy = true);
    try {
      await assignTenantToUnit({
        'unitId': widget.unitId,
        'tenantId': _tenantId,
        'startDate': _startDate.text.trim(),
        'endDate': _endDate.text.trim().isEmpty ? null : _endDate.text.trim(),
        'monthlyRent': _monthlyRent.text.trim().isEmpty ? '0' : _monthlyRent.text.trim(),
        'depositAmount': _deposit.text.trim().isEmpty ? '0' : _deposit.text.trim(),
        'billingDay': 1,
        'graceDays': 5,
      });
      final propertyId = widget.propertyId;
      if (propertyId != null) ref.invalidate(propertyProvider(propertyId));
      if (mounted) context.pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(assignableTenantsProvider);

    return FamPage(
      title: 'Assign tenant',
      child: ListView(
        children: [
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unit ${widget.unitCode ?? widget.unitId}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                const Text('The unit becomes rented once the lease is created.',
                    style: TextStyle(color: FamColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: FamColors.danger)),
            const SizedBox(height: 12),
          ],
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tenant', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const SizedBox(height: 8),
                tenants.when(
                  loading: () => const FamLoading(),
                  error: (e, _) =>
                      ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(assignableTenantsProvider)),
                  data: (rows) => rows.isEmpty
                      ? const EmptyState(
                          message: 'Every tenant already has an active lease. Create a new tenant instead.')
                      : Column(
                          children: rows.take(50).map((t) {
                            final selected = t['id'] == _tenantId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => setState(() => _tenantId = t['id'] as String?),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: selected ? FamColors.royal : FamColors.border),
                                    borderRadius: BorderRadius.circular(12),
                                    color: selected ? FamColors.tint : FamColors.white,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${t['full_name'] ?? t['id'].toString().substring(0, 8)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                                      if (t['phone'] != null)
                                        Text('${t['phone']}', style: const TextStyle(color: FamColors.textMuted)),
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
                const Text('Lease', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const SizedBox(height: 8),
                FamField(label: 'Start date (YYYY-MM-DD)', controller: _startDate),
                const SizedBox(height: 12),
                FamField(label: 'End date (optional)', controller: _endDate),
                const SizedBox(height: 12),
                FamField(label: 'Monthly rent (ETB)', controller: _monthlyRent, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                FamField(label: 'Deposit (ETB)', controller: _deposit, keyboardType: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : () => _submit(tenants.valueOrNull ?? const []), child: const Text('Assign tenant')),
        ],
      ),
    );
  }
}
