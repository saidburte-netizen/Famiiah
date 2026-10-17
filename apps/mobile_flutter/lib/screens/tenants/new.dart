import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final vacantUnitsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listVacantUnits(org.orgId!);
});

class NewTenantScreen extends ConsumerStatefulWidget {
  final String? unitId;
  const NewTenantScreen({super.key, this.unitId});

  @override
  ConsumerState<NewTenantScreen> createState() => _NewTenantScreenState();
}

class _NewTenantScreenState extends ConsumerState<NewTenantScreen> {
  final _fullName = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _startDate = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _endDate = TextEditingController();
  final _monthlyRent = TextEditingController();
  final _deposit = TextEditingController(text: '0');
  String? _unitId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _unitId = widget.unitId;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _businessName.dispose();
    _phone.dispose();
    _email.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _monthlyRent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Map<String, dynamic>> units) async {
    setState(() => _error = null);
    final orgId = ref.read(orgProvider).orgId;
    if (orgId == null) {
      setState(() => _error = 'No active organization.');
      return;
    }
    final selected = _unitId != null ? units.firstWhere((u) => u['id'] == _unitId, orElse: () => const {}) : null;
    final unit = (selected != null && selected.isNotEmpty) ? selected : (units.isEmpty ? null : units.first);
    if (unit == null) {
      setState(() => _error = 'Pick a vacant unit.');
      return;
    }
    if (_fullName.text.trim().isEmpty) {
      setState(() => _error = 'Enter the tenant name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await createTenantWithLease({
        'orgId': orgId,
        'unitId': unit['id'],
        'startDate': _startDate.text.trim(),
        'endDate': _endDate.text.trim().isEmpty ? null : _endDate.text.trim(),
        'monthlyRent': _monthlyRent.text.trim().isEmpty ? unit['monthly_rent'] : _monthlyRent.text.trim(),
        'depositAmount': _deposit.text.trim().isEmpty ? '0' : _deposit.text.trim(),
        'billingDay': 1,
        'graceDays': 5,
        'tenant': {
          'fullName': _fullName.text.trim(),
          'businessName': _businessName.text.trim().isEmpty ? null : _businessName.text.trim(),
          'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        },
      });
      if (mounted) context.go('/app/tenants');
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(vacantUnitsProvider);
    final rows = units.valueOrNull ?? const <Map<String, dynamic>>[];
    final selectedId = _unitId ?? (rows.isNotEmpty ? rows.first['id'] as String? : null);

    return FamPage(
      title: 'New tenant',
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
                const Text('Unit', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const SizedBox(height: 8),
                units.when(
                  loading: () => const FamLoading(),
                  error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(vacantUnitsProvider)),
                  data: (data) => data.isEmpty
                      ? const EmptyState(message: 'No vacant units. Add units to a property first.')
                      : Column(
                          children: data.take(30).map((u) {
                            final selected = u['id'] == selectedId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => setState(() => _unitId = u['id'] as String?),
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
                                      Text('${u['code']} — ${u['property_name'] ?? 'Property'}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                                      Text('Rent ${u['monthly_rent']} ETB',
                                          style: const TextStyle(color: FamColors.textMuted)),
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
                const Text('Tenant', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const SizedBox(height: 8),
                FamField(label: 'Full name', controller: _fullName),
                const SizedBox(height: 12),
                FamField(label: 'Business name', controller: _businessName),
                const SizedBox(height: 12),
                FamField(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                FamField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
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
          FilledButton(onPressed: _busy ? null : () => _submit(rows), child: const Text('Create tenant & lease')),
        ],
      ),
    );
  }
}
