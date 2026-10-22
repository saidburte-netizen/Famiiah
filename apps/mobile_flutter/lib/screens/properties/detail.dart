import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
      actions: [
        if (async.valueOrNull?.property['deleted_at'] == null)
          FamIconButton(
            icon: Icons.archive_outlined,
            tooltip: t('common.archive'),
            background: FamColors.background,
            size: 40,
            onPressed: () => _archive(context, ref, id),
          ),
      ],
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: FamColors.tint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.apartment_rounded,
                              size: 24, color: FamColors.royal),
                        ),
                        const SizedBox(width: 12),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: FamColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                      ],
                    ),
                    const SizedBox(height: 14),
                    FamProgress(
                      value: data.units.isEmpty ? 0 : rented / data.units.length,
                      label: '$rented rented · $vacant vacant · ${data.units.length} units',
                      trailing: overdue > 0 ? '$overdue overdue' : 'Up to date',
                    ),
                    const SizedBox(height: 14),
                    FamPrimaryButton(
                      label: 'Add unit',
                      icon: Icons.add_rounded,
                      height: 48,
                      dense: true,
                      onPressed: () => _showAddUnit(context, id, p['org_id'] as String),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FamFilterPills(
                labels: _filters
                    .map((f) => '${f[0].toUpperCase()}${f.substring(1)} (${counts[f]})')
                    .toList(),
                selected: _filters.indexOf(_filter),
                onChanged: (i) => setState(() => _filter = _filters[i]),
              ),
              const SizedBox(height: 14),
              if (data.units.isEmpty)
                EmptyState(
                  icon: Icons.door_front_door_outlined,
                  title: 'No units yet',
                  message: 'Add the units inside this property to track occupancy and rent.',
                  actionLabel: 'Add unit',
                  onAction: () => _showAddUnit(context, id, p['org_id'] as String),
                )
              else if (visible.isEmpty)
                const EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing matches',
                  message: 'No units match this filter.',
                )
              else
                ...visible.map((u) {
                  final isVacant = u['status'] == 'vacant';
                  final isOverdue = u['overdue'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FamCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isVacant ? FamColors.tint : FamColors.chipBg,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.door_front_door_outlined,
                                  size: 22,
                                  color: isVacant ? FamColors.royal : FamColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${u['code']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: FamFonts.body,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: FamColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${u['kind'] ?? '—'} · '
                                      '${u['monthly_rent'] != null ? '${formatMoney(u['monthly_rent'], decimals: 0)}/mo' : 'no rent'}'
                                      '${u['tenant_name'] != null ? ' · ${u['tenant_name']}' : ''}',
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
                              const SizedBox(width: 8),
                              isOverdue
                                  ? const FamBadge(
                                      label: 'Overdue',
                                      foreground: FamColors.danger,
                                      background: FamColors.dangerBg,
                                    )
                                  : FamBadge(label: '${u['status']}'),
                              PopupMenuButton<String>(
                                tooltip: t('common.manage'),
                                icon: const Icon(Icons.more_vert_rounded,
                                    size: 20, color: FamColors.textMuted),
                                onSelected: (v) {
                                  if (v == 'archive') {
                                    _archiveUnit(context, ref, u['id'] as String);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'archive',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.archive_outlined,
                                            size: 18, color: FamColors.danger),
                                        const SizedBox(width: 10),
                                        Text(t('common.archive')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isVacant) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FamPrimaryButton(
                                    label: 'New tenant',
                                    height: 46,
                                    dense: true,
                                    onPressed: () =>
                                        context.push('/app/tenants/new?unitId=${u['id']}'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FamSecondaryButton(
                                    label: 'Existing',
                                    height: 46,
                                    dense: true,
                                    filled: true,
                                    onPressed: () => context.push(
                                      '/app/units/${u['id']}/assign'
                                      '?propertyId=$id'
                                      '&code=${Uri.encodeComponent('${u['code']}')}'
                                      '&rent=${u['monthly_rent'] ?? ''}',
                                    ),
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

  /// Archive the whole property. The server refuses while it still has units,
  /// and the refusal is shown with its own message.
  Future<void> _archive(BuildContext context, WidgetRef ref, String id) async {
    final ok = await famConfirm(
      context,
      title: t('common.archiveTitle'),
      message: t('common.archiveBody'),
      confirmLabel: t('common.archive'),
      danger: true,
    );
    if (!ok) return;
    try {
      await archiveProperty(id);
      if (context.mounted) context.go('/app/properties');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }

  /// Archive one unit. Refused while it is still let.
  Future<void> _archiveUnit(BuildContext context, WidgetRef ref, String unitId) async {
    final ok = await famConfirm(
      context,
      title: t('common.archiveTitle'),
      message: t('common.archiveBody'),
      confirmLabel: t('common.archive'),
      danger: true,
    );
    if (!ok) return;
    try {
      await archiveUnit(unitId);
      ref.invalidate(propertyProvider(widget.id));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}
