import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

const _unitKinds = ['shop', 'apartment', 'office', 'storage'];

class _PropertyData {
  final Map<String, dynamic> property;
  final List<Map<String, dynamic>> units;
  const _PropertyData(this.property, this.units);
}

final propertyProvider = FutureProvider.autoDispose.family<_PropertyData, String>((ref, id) async {
  final results = await Future.wait([getProperty(id), listUnits(id)]);
  final property = results[0] as Map<String, dynamic>;
  final units = results[1] as List<Map<String, dynamic>>;
  return _PropertyData(property, units);
});

class PropertyDetailScreen extends ConsumerWidget {
  final String id;
  const PropertyDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(propertyProvider(id));
    final title = async.valueOrNull?.property['name']?.toString() ?? 'Property';

    return FamPage(
      title: title,
      child: async.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(propertyProvider(id))),
        data: (data) {
          final p = data.property;
          final rented = data.units.where((u) => u['status'] == 'rented').length;
          return ListView(
            children: [
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                    Text('${p['type']} · ${p['city'] ?? '—'}',
                        style: const TextStyle(color: FamColors.textMuted)),
                    Text('$rented/${data.units.length} units rented',
                        style: const TextStyle(color: FamColors.textMuted)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _showAddUnit(context, ref, id, p['org_id'] as String),
                      child: const Text('Add unit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (data.units.isEmpty)
                const EmptyState(message: 'No units yet.')
              else
                ...data.units.map((u) {
                  final vacant = u['status'] == 'vacant';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FamCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${u['code']}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                              Text('${u['status']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: vacant ? FamColors.royal : FamColors.textMuted,
                                  )),
                            ],
                          ),
                          Text(
                            '${u['kind'] ?? '—'} · ${u['monthly_rent'] != null ? formatMoney(u['monthly_rent']) : 'no rent'}'
                            '${u['tenant_name'] != null ? ' · ${u['tenant_name']}' : ''}',
                            style: const TextStyle(color: FamColors.textMuted),
                          ),
                          if (vacant) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => context.push('/app/tenants/new?unitId=${u['id']}'),
                              child: const Text('Assign tenant'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddUnit(BuildContext context, WidgetRef ref, String propertyId, String orgId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => _AddUnitSheet(
        propertyId: propertyId,
        orgId: orgId,
        onCreated: () async => ref.invalidate(propertyProvider(id)),
      ),
    );
  }
}

class _AddUnitSheet extends StatefulWidget {
  final String propertyId;
  final String orgId;
  final Future<void> Function() onCreated;
  const _AddUnitSheet({required this.propertyId, required this.orgId, required this.onCreated});

  @override
  State<_AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends State<_AddUnitSheet> {
  final _code = TextEditingController();
  final _floorLabel = TextEditingController();
  final _monthlyRent = TextEditingController();
  String _kind = 'shop';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _floorLabel.dispose();
    _monthlyRent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Unit code is required.');
      return;
    }
    setState(() => _busy = true);
    try {
      await createUnit(widget.orgId, {
        'propertyId': widget.propertyId,
        'code': _code.text.trim(),
        'kind': _kind,
        'floorLabel': _floorLabel.text.trim().isEmpty ? null : _floorLabel.text.trim(),
        'monthlyRent': _monthlyRent.text.trim().isEmpty ? '0' : _monthlyRent.text.trim(),
      });
      await widget.onCreated();
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
            Text('New unit', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FamField(label: 'Code', controller: _code),
                  const SizedBox(height: 12),
                  const Text('Kind', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _unitKinds
                        .map((k) => _kind == k
                            ? FilledButton(onPressed: () => setState(() => _kind = k), child: Text(k))
                            : OutlinedButton(onPressed: () => setState(() => _kind = k), child: Text(k)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FamField(label: 'Floor label', controller: _floorLabel),
                  const SizedBox(height: 12),
                  FamField(label: 'Monthly rent (ETB)', controller: _monthlyRent, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('Save unit')),
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
