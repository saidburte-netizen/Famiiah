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
      subtitle: 'Tenant details and lease',
      child: ListView(
        children: [
          if (_error != null) ...[
            FamNotice.error(_error!),
            const SizedBox(height: 14),
          ],
          const FamSectionHeader(title: 'Unit'),
          const SizedBox(height: 10),
          units.when(
            loading: () => const FamLoading(),
            error: (e, _) => ErrorState(
                message: userMessage(e), onRetry: () => ref.invalidate(vacantUnitsProvider)),
            data: (data) => data.isEmpty
                ? const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No vacant units',
                    message: 'Add units to a property first, then assign a tenant.',
                  )
                : Column(
                    children: data.take(30).map((u) {
                      final selected = u['id'] == selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: selected ? FamColors.tint : FamColors.white,
                          borderRadius: BorderRadius.circular(FamRadius.button),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(FamRadius.button),
                            onTap: () => setState(() => _unitId = u['id'] as String?),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${u['code']} — ${u['property_name'] ?? 'Property'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: FamFonts.body,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: FamColors.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Rent ${formatMoney(u['monthly_rent'], decimals: 0)}/mo',
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
          const FamSectionHeader(title: 'Tenant'),
          const SizedBox(height: 10),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FamField(
                  label: 'Full name',
                  hint: 'e.g. Abebe Kebede',
                  controller: _fullName,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'Business name (optional)',
                  controller: _businessName,
                  prefixIcon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'Phone (optional)',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 14),
                FamField(
                  label: 'Email (optional)',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ],
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
                  hint: 'Defaults to the unit rent',
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
            label: 'Create tenant & lease',
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
