import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final propertiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listPropertiesWithStats(org.orgId!);
});

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final properties = ref.watch(propertiesProvider);

    if (org.loading) return const Center(child: CircularProgressIndicator(color: FamColors.royal));
    if (org.error != null) {
      return FamScreen(
        child: ErrorState(message: userMessage(org.error), onRetry: () => ref.read(orgProvider.notifier).refresh()),
      );
    }

    return FamScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FamScreenHeader(
            title: 'Properties',
            subtitle: 'Your buildings and shops',
            actions: [
              FamIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add property',
                onPressed: () => context.push('/app/properties/new'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: properties.when(
              loading: () => const FamLoading(),
              error: (e, _) => ErrorState(
                message: userMessage(e),
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
              data: (rows) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(propertiesProvider),
                child: rows.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.apartment_rounded,
                          title: 'No properties yet',
                          message: 'Add your first building or shop to start tracking units and rent.',
                          actionLabel: 'Add property',
                          onAction: () => context.push('/app/properties/new'),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final pct = (r['occupancy_pct'] as num?)?.toDouble() ?? 0;
                          return FamCard(
                            onTap: () => context.push('/app/properties/${r['id']}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: FamColors.tint,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Icon(Icons.apartment_rounded,
                                          size: 22, color: FamColors.royal),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${r['name']}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: FamFonts.body,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: FamColors.navy,
                                            ),
                                          ),
                                          Text(
                                            '${r['type']} · ${r['city'] ?? '—'}',
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
                                    FamBadge(label: '${pct.toStringAsFixed(0)}%'),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                FamProgress(
                                  value: pct / 100,
                                  label: '${r['units_rented']}/${r['units_total']} units rented',
                                  trailing: '${formatMoney(r['monthly_total'], decimals: 0)}/mo',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
