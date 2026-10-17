import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';
import '../units/form.dart';

class _PropertyData {
  final Map<String, dynamic> property;
  final List<Map<String, dynamic>> units;
  const _PropertyData(this.property, this.units);
}

final propertyProvider = FutureProvider.autoDispose.family<_PropertyData, String>((ref, id) async {
  final results = await Future.wait([
    getProperty(id),
    listUnits(id),
  ]);
  return _PropertyData(
    results[0] as Map<String, dynamic>,
    results[1] as List<Map<String, dynamic>>,
  );
});

const _filters = ['all', 'rented', 'vacant', 'overdue'];

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const PropertyDetailScreen({super.key, required this.id});

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final async = ref.watch(propertyProvider(id));
    final title = (async.valueOrNull?.property['name'] as String?) ?? 'Property';

    return FamPage(
      title: title,
      child: async.when(
        loading: () => const FamLoading(),
        error: (e, _) =>
            ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(propertyProvider(id))),
        data: (data) {
          final p = data.property;
          final rented = data.units.where((u) => u['status'] == 'rented').length;
          final vacant = data.units.where((u) => u['status'] == 'vacant').length;
          final overdue = data.units.where((u) => u['overdue'] == true).length;
          final counts = <String, int>{
            'all': data.units.length,
            'rented': rented,
            'vacant': vacant,
            'overdue': overdue,
          };
          final visible = data.units.where((u) => switch (_filter) {
                'rented' => u['status'] == 'rented',
                'vacant' => u['status'] == 'vacant',
                'overdue' => u['overdue'] == true,
                _ => true,
              }).toList();

          return ListView(
            children: [
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                    Text('${p['type']} · ${p['city'] ?? '—'}',
                        style: const TextStyle(color: FamColors.textMuted)),
                    Text('$rented rented · $vacant vacant · ${data.units.length} units',
                        style: const TextStyle(color: FamColors.textMuted)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _showAddUnit(context, id, p['org_id'] as String),
                      child: const Text('Add unit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _filter == f
                                ? FilledButton(
                                    onPressed: () => setState(() => _filter = f),
                                    child: Text('${f[0].toUpperCase()}${f.substring(1)} (${counts[f]})'),
                                  )
                                : OutlinedButton(
                                    onPressed: () => setState(() => _filter = f),
                                    child: Text('${f[0].toUpperCase()}${f.substring(1)} (${counts[f]})'),
                                  ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (data.units.isEmpty)
                const EmptyState(message: 'No units yet.')
              else if (visible.isEmpty)
                const EmptyState(message: 'No units match this filter.')
              else
                ...visible.map((u) {
                  final isVacant = u['status'] == 'vacant';
                  final isOverdue = u['overdue'] == true;
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
                                    color: isVacant ? FamColors.royal : FamColors.textMuted,
                                  )),
                            ],
                          ),
                          Text(
                            '${u['kind'] ?? '—'} · ${u['monthly_rent'] != null ? formatMoney(u['monthly_rent']) : 'no rent'}'
                            '${u['tenant_name'] != null ? ' · ${u['tenant_name']}' : ''}',
                            style: const TextStyle(color: FamColors.textMuted),
                          ),
                          if (isOverdue)
                            const Text('Rent overdue',
                                style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.danger)),
                          if (isVacant) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => context.push('/app/tenants/new?unitId=${u['id']}'),
                                    child: const Text('New tenant'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => context.push(
                                      '/app/units/${u['id']}/assign'
                                      '?propertyId=$id'
                                      '&code=${Uri.encodeComponent('${u['code']}')}'
                                      '&rent=${u['monthly_rent'] ?? ''}',
                                    ),
                                    child: const Text('Existing'),
                                  ),
                                ),
                              ],
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

  Future<void> _showAddUnit(BuildContext context, String propertyId, String orgId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => UnitForm(
        propertyId: propertyId,
        orgId: orgId,
        onCreated: () async => ref.invalidate(propertyProvider(propertyId)),
      ),
    );
  }
}
