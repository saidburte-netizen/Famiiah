import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
                child: Row(
                  children: [
                    FamAvatar(name: '${t['full_name'] ?? '—'}', size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t['full_name'] ?? '—'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: FamFonts.body,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: FamColors.navy,
                            ),
                          ),
                          if (t['business_name'] != null)
                            Text(
                              '${t['business_name']}',
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FamSectionHeader(title: 'Contact'),
                    const SizedBox(height: 10),
                    FamInfoRow(
                      label: 'Phone',
                      value: '${t['phone'] ?? 'no phone'}',
                      icon: Icons.phone_outlined,
                    ),
                    const Divider(),
                    FamInfoRow(
                      label: 'Email',
                      value: '${t['email'] ?? 'no email'}',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (lease != null)
                FamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FamBadge(label: 'Active lease · ${lease['unit_code'] ?? 'unit'}'),
                      const SizedBox(height: 12),
                      Text(
                        '${lease['start_date']} → ${lease['end_date'] ?? 'open'} · '
                        '${formatMoney(lease['monthly_rent'], decimals: 0)}/mo',
                        style: const TextStyle(
                          fontFamily: FamFonts.body,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FamColors.text,
                        ),
                      ),
                      if (lease['deposit_amount'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Deposit ${formatMoney(lease['deposit_amount'], decimals: 0)}',
                          style: const TextStyle(
                            fontFamily: FamFonts.body,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FamColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FamPrimaryButton(
                              label: 'Record payment',
                              height: 48,
                              dense: true,
                              onPressed: () =>
                                  context.push('/app/payments/new?leaseId=${lease['id']}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FamSecondaryButton(
                              label: 'Manage',
                              height: 48,
                              dense: true,
                              filled: true,
                              onPressed: () => _showManageSheet(context, ref, lease),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const FamCard(
                  child: EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No active lease',
                    message: 'This tenant has no lease running right now.',
                  ),
                ),
              const SizedBox(height: 12),
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FamSectionHeader(title: 'Charges'),
                    const SizedBox(height: 8),
                    if (data.charges.isEmpty)
                      const EmptyState(message: 'No charges yet.')
                    else
                      ...data.charges.map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${c['due_date']}',
                                    style: const TextStyle(
                                      fontFamily: FamFonts.body,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: FamColors.text,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatMoney(c['amount'], decimals: 0),
                                  style: const TextStyle(
                                    fontFamily: FamFonts.body,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: FamColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FamBadge(
                                  label: '${c['status']}',
                                  foreground: c['status'] == 'overdue'
                                      ? FamColors.danger
                                      : FamColors.textMuted,
                                  background: c['status'] == 'overdue'
                                      ? FamColors.dangerBg
                                      : FamColors.chipBg,
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FamSectionHeader(title: 'Lease history'),
                    const SizedBox(height: 8),
                    if (data.leases.isEmpty)
                      const EmptyState(message: 'None.')
                    else
                      ...data.leases.map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              '${l['start_date']} → ${l['end_date'] ?? 'open'} · ${l['status']}'
                              '${l['ended_reason'] != null ? ' (${l['ended_reason']})' : ''}',
                              style: const TextStyle(
                                fontFamily: FamFonts.body,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: FamColors.textMuted,
                              ),
                            ),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Manage lease',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Renew the term or end the lease.',
              style: TextStyle(
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
            FamSegmented(
              labels: const ['Renew', 'Terminate'],
              selected: _mode == 'renew' ? 0 : 1,
              onChanged: (i) => setState(() => _mode = i == 0 ? 'renew' : 'terminate'),
            ),
            const SizedBox(height: 18),
            FamField(
              label: _mode == 'renew'
                  ? 'New end date (YYYY-MM-DD)'
                  : 'Termination date (YYYY-MM-DD)',
              controller: _date,
              prefixIcon: Icons.event_outlined,
            ),
            const SizedBox(height: 14),
            if (_mode == 'renew')
              FamField(
                label: 'Monthly rent (ETB)',
                controller: _rent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.payments_outlined,
              )
            else
              FamField(
                label: 'Reason (optional)',
                controller: _reason,
                prefixIcon: Icons.notes_rounded,
              ),
            const SizedBox(height: 20),
            FamPrimaryButton(
              label: _mode == 'renew' ? 'Renew lease' : 'Terminate lease',
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
