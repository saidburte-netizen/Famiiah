import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
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
    final text = Theme.of(context).textTheme;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Properties', style: text.displayLarge?.copyWith(color: FamColors.midnight)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, kMinTouch)),
                onPressed: () => context.push('/app/properties/new'),
                child: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    ? ListView(children: const [SizedBox(height: 120), EmptyState(message: 'No properties yet.')])
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          return InkWell(
                            onTap: () => context.push('/app/properties/${r['id']}'),
                            borderRadius: BorderRadius.circular(FamRadius.card),
                            child: FamCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text('${r['name']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700, color: FamColors.navy)),
                                      ),
                                      Text('${r['occupancy_pct']}%',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, color: FamColors.royal)),
                                    ],
                                  ),
                                  Text('${r['type']} · ${r['city'] ?? '—'}',
                                      style: const TextStyle(color: FamColors.textMuted)),
                                  Text(
                                    '${r['units_rented']}/${r['units_total']} units rented · ${formatMoney(r['monthly_total'])}/mo',
                                    style: const TextStyle(color: FamColors.textMuted),
                                  ),
                                ],
                              ),
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
