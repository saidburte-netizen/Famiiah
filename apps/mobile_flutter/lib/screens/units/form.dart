import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New unit',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'A shop, apartment, office or store inside a property.',
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
            if (needsPicker) ...[
              const Text(
                'Property',
                style: TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FamColors.textLabel,
                ),
              ),
              const SizedBox(height: 10),
              properties.when(
                loading: () => const Center(child: CircularProgressIndicator(color: FamColors.royal)),
                error: (e, _) => ErrorState(
                    message: userMessage(e), onRetry: () => ref.invalidate(propertiesProvider)),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.apartment_rounded,
                        title: 'No property yet',
                        message: 'Create a property first, then add units to it.',
                      )
                    : Column(
                        children: list.take(30).map((p) {
                          final selected = p['id'] == selectedId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: selected ? FamColors.tint : FamColors.white,
                              borderRadius: BorderRadius.circular(FamRadius.button),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(FamRadius.button),
                                onTap: () => setState(() => _propertyId = p['id'] as String?),
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
                                              '${p['name']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: FamFonts.body,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: FamColors.navy,
                                              ),
                                            ),
                                            Text(
                                              '${p['type']} · ${p['city'] ?? '—'}',
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
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FamField(
                    label: 'Unit code',
                    hint: 'e.g. A-101',
                    controller: _code,
                    prefixIcon: Icons.confirmation_number_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kind',
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
                    children: _unitKinds
                        .map((k) => _kind == k
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () => setState(() => _kind = k),
                                child: Text(k),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () => setState(() => _kind = k),
                                child: Text(k),
                              ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  FamField(
                    label: 'Floor label (optional)',
                    hint: 'e.g. Ground floor',
                    controller: _floorLabel,
                    prefixIcon: Icons.layers_outlined,
                  ),
                  const SizedBox(height: 14),
                  FamField(
                    label: 'Monthly rent (ETB)',
                    controller: _monthlyRent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.payments_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FamPrimaryButton(
              label: 'Save unit',
              icon: Icons.check_rounded,
              loading: _busy,
              onPressed: _busy ? null : () => _save(rows),
            ),
            const SizedBox(height: 10),
            FamSecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
      ),
    );
  }
}
