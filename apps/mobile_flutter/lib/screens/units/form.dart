import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';
import '../properties/list.dart' show propertiesProvider;

const _unitKinds = ['shop', 'apartment', 'office', 'storage'];

/// Form that creates a unit (a "shop" in the brief).
///
/// It is reused in two places: the bottom sheet on the property detail screen,
/// which already knows the property, and the global "New unit" route, which
/// asks the user to pick the property first.
class UnitForm extends ConsumerStatefulWidget {
  final String? propertyId;
  final String? orgId;
  final Future<void> Function() onCreated;

  const UnitForm({super.key, this.propertyId, this.orgId, required this.onCreated});

  @override
  ConsumerState<UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends ConsumerState<UnitForm> {
  final _code = TextEditingController();
  final _floorLabel = TextEditingController();
  final _monthlyRent = TextEditingController();
  String _kind = 'shop';
  String? _propertyId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _propertyId = widget.propertyId;
  }

  @override
  void dispose() {
    _code.dispose();
    _floorLabel.dispose();
    _monthlyRent.dispose();
    super.dispose();
  }

  Future<void> _save(List<Map<String, dynamic>> properties) async {
    setState(() => _error = null);
    final orgId = widget.orgId ?? ref.read(orgProvider).orgId;
    if (orgId == null) {
      setState(() => _error = 'No active organization.');
      return;
    }
    final propertyId = widget.propertyId ??
        _propertyId ??
        (properties.isNotEmpty ? properties.first['id'] as String? : null);
    if (propertyId == null) {
      setState(() => _error = 'Pick a property.');
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Unit code is required.');
      return;
    }
    setState(() => _busy = true);
    try {
      await createUnit(orgId, {
        'propertyId': propertyId,
        'code': _code.text.trim(),
        'kind': _kind,
        'floorLabel': _floorLabel.text.trim().isEmpty ? null : _floorLabel.text.trim(),
        'monthlyRent': _monthlyRent.text.trim().isEmpty ? '0' : _monthlyRent.text.trim(),
      });
      await widget.onCreated();
      if (mounted) Navigator.of(context).maybePop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsPicker = widget.propertyId == null;
    final properties = ref.watch(propertiesProvider);
    final rows = properties.valueOrNull ?? const <Map<String, dynamic>>[];
    final selectedId = widget.propertyId ?? _propertyId ?? (rows.isNotEmpty ? rows.first['id'] as String? : null);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New unit',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (needsPicker) ...[
                    const Text('Property', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                    const SizedBox(height: 8),
                    properties.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: FamColors.royal)),
                      error: (e, _) => ErrorState(
                          message: userMessage(e), onRetry: () => ref.invalidate(propertiesProvider)),
                      data: (list) => list.isEmpty
                          ? const EmptyState(message: 'Create a property first.')
                          : Column(
                              children: list.take(30).map((p) {
                                final selected = p['id'] == selectedId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () => setState(() => _propertyId = p['id'] as String?),
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
                                          Text('${p['name']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600, color: FamColors.navy)),
                                          Text('${p['type']} · ${p['city'] ?? '—'}',
                                              style: const TextStyle(color: FamColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FamField(label: 'Unit code', controller: _code),
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
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy ? null : () => _save(rows), child: const Text('Save unit')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
