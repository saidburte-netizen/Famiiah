import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

class _TenantData {
  final Map<String, dynamic> tenant;
  final List<Map<String, dynamic>> leases;
  final List<Map<String, dynamic>> charges;
  const _TenantData(this.tenant, this.leases, this.charges);
}

final tenantProvider = FutureProvider.autoDispose.family<_TenantData, String>((ref, id) async {
  final tenant = await getTenant(id);
  final leases = await listTenantLeases(id);
  final active = leases.where((l) => l['status'] == 'active').toList();
  final charges = active.isEmpty ? <Map<String, dynamic>>[] : await listLeaseCharges(active.first['id'] as String);
  return _TenantData(tenant, leases, charges);
});

class TenantDetailScreen extends ConsumerWidget {
  final String id;
  const TenantDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tenantProvider(id));
    final title = async.valueOrNull?.tenant['full_name']?.toString() ?? 'Tenant';

    return FamPage(
      title: title,
      child: async.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(tenantProvider(id))),
        data: (data) {
          final t = data.tenant;
          final activeLease = data.leases.where((l) => l['status'] == 'active').toList();
          final lease = activeLease.isEmpty ? null : activeLease.first;
          return ListView(
            children: [
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t['full_name'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                    if (t['business_name'] != null) Text('${t['business_name']}', style: const TextStyle(color: FamColors.textMuted)),
                    Text('${t['phone'] ?? 'no phone'}', style: const TextStyle(color: FamColors.textMuted)),
                    Text('${t['email'] ?? 'no email'}', style: const TextStyle(color: FamColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (lease != null)
                FamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Active lease · ${lease['unit_code'] ?? 'unit'}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                      Text(
                        '${lease['start_date']} → ${lease['end_date'] ?? 'open'} · ${formatMoney(lease['monthly_rent'])}/mo',
                        style: const TextStyle(color: FamColors.textMuted),
                      ),
                      if (lease['deposit_amount'] != null)
                        Text('Deposit ${formatMoney(lease['deposit_amount'])}', style: const TextStyle(color: FamColors.textMuted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => context.push('/app/payments/new?leaseId=${lease['id']}'),
                              child: const Text('Record payment'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showManageSheet(context, ref, lease),
                              child: const Text('Manage'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const FamCard(child: EmptyState(message: 'No active lease.')),
              const SizedBox(height: 12),
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Charges', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                    if (data.charges.isEmpty)
                      const EmptyState(message: 'No charges yet.')
                    else
                      ...data.charges.map((c) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${c['due_date']}', style: const TextStyle(color: FamColors.textMuted)),
                              Text(formatMoney(c['amount']), style: const TextStyle(color: FamColors.textMuted)),
                              Text('${c['status']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c['status'] == 'overdue' ? FamColors.danger : FamColors.textMuted,
                                  )),
                            ],
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lease history', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                    if (data.leases.isEmpty)
                      const EmptyState(message: 'None.')
                    else
                      ...data.leases.map((l) => Text(
                            '${l['start_date']} → ${l['end_date'] ?? 'open'} · ${l['status']}'
                            '${l['ended_reason'] != null ? ' (${l['ended_reason']})' : ''}',
                            style: const TextStyle(color: FamColors.textMuted),
                          )),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showManageSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> lease) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => _ManageLeaseSheet(lease: lease, onDone: () async => ref.invalidate(tenantProvider(id))),
    );
  }
}

class _ManageLeaseSheet extends StatefulWidget {
  final Map<String, dynamic> lease;
  final Future<void> Function() onDone;
  const _ManageLeaseSheet({required this.lease, required this.onDone});

  @override
  State<_ManageLeaseSheet> createState() => _ManageLeaseSheetState();
}

class _ManageLeaseSheetState extends State<_ManageLeaseSheet> {
  String _mode = 'renew';
  late final TextEditingController _date;
  late final TextEditingController _rent;
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _date = TextEditingController(text: widget.lease['end_date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10));
    _rent = TextEditingController(text: widget.lease['monthly_rent']?.toString() ?? '');
  }

  @override
  void dispose() {
    _date.dispose();
    _rent.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (_mode == 'renew') {
        await renewLease(widget.lease['id'] as String, _date.text.trim(),
            newRent: _rent.text.trim().isEmpty ? null : _rent.text.trim());
      } else {
        await terminateLease(widget.lease['id'] as String, _date.text.trim(),
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim());
      }
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
            Text('Manage lease', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _mode == 'renew'
                            ? FilledButton(onPressed: () => setState(() => _mode = 'renew'), child: const Text('Renew'))
                            : OutlinedButton(onPressed: () => setState(() => _mode = 'renew'), child: const Text('Renew')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _mode == 'terminate'
                            ? FilledButton(onPressed: () => setState(() => _mode = 'terminate'), child: const Text('Terminate'))
                            : OutlinedButton(onPressed: () => setState(() => _mode = 'terminate'), child: const Text('Terminate')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FamField(
                    label: _mode == 'renew' ? 'New end date (YYYY-MM-DD)' : 'Termination date (YYYY-MM-DD)',
                    controller: _date,
                  ),
                  const SizedBox(height: 12),
                  if (_mode == 'renew')
                    FamField(label: 'Monthly rent (ETB)', controller: _rent, keyboardType: TextInputType.number)
                  else
                    FamField(label: 'Reason', controller: _reason),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_mode == 'renew' ? 'Renew lease' : 'Terminate lease'),
                  ),
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
