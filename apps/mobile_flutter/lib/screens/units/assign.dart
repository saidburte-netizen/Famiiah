import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
      subtitle: 'Tenant and lease for this unit',
      child: ListView(
        children: [
          FamCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FamColors.tint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.door_front_door_outlined,
                      size: 22, color: FamColors.royal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit ${widget.unitCode ?? widget.unitId}',
                        style: const TextStyle(
                          fontFamily: FamFonts.body,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FamColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'The unit becomes rented once the lease is created.',
                        style: TextStyle(
                          fontFamily: FamFonts.body,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: FamColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FamNotice.error(_error!),
            const SizedBox(height: 14),
          ],
          const FamSectionHeader(title: 'Tenant'),
          const SizedBox(height: 10),
          tenants.when(
            loading: () => const FamLoading(),
            error: (e, _) => ErrorState(
                message: userMessage(e), onRetry: () => ref.invalidate(assignableTenantsProvider)),
            data: (rows) => rows.isEmpty
                ? const EmptyState(
                    icon: Icons.people_alt_rounded,
                    title: 'No tenant available',
                    message: 'Every tenant already has an active lease. Create a new tenant instead.',
                  )
                : Column(
                    children: rows.take(50).map((t) {
                      final selected = t['id'] == _tenantId;
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
                                  FamAvatar(
                                    name: name,
                                    size: 40,
                                    background: selected ? FamColors.white : FamColors.tint,
                                    foreground: FamColors.royalMid,
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: FamColors.navy,
                                          ),
                                        ),
                                        if (t['phone'] != null)
                                          Text(
                                            '${t['phone']}',
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
                                  if (selected)
                                    const Icon(Icons.check_circle_rounded,
                                        size: 20, color: FamColors.royal),
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
          const FamSectionHeader(title: 'Lease'),
          const SizedBox(height: 10),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FamField(
                  label: 'Start date (YYYY-MM-DD)',
                  controller: _startDate,
                  prefixIcon: Icons.event_outlined,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'End date (optional)',
                  controller: _endDate,
                  prefixIcon: Icons.event_available_outlined,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'Monthly rent (ETB)',
                  controller: _monthlyRent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'Deposit (ETB)',
                  controller: _deposit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.savings_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FamPrimaryButton(
            label: 'Assign tenant',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _busy ? null : () => _submit(tenants.valueOrNull ?? const []),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
