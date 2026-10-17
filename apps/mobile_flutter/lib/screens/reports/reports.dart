import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

class _Reports {
  final List<Map<String, dynamic>> collections;
  final List<Map<String, dynamic>> occupancy;
  final List<Map<String, dynamic>> ageing;
  const _Reports(this.collections, this.occupancy, this.ageing);
}

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

final reportsProvider = FutureProvider.autoDispose<_Reports>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const _Reports([], [], []);
  final to = DateTime.now();
  final from = DateTime(to.year, to.month - 5, 1);
  final results = await Future.wait([
    reportCollections(org.orgId!, _iso(from), _iso(to), groupBy: 'month'),
    reportOccupancy(org.orgId!, _iso(from), _iso(to)),
    reportOverdueAgeing(org.orgId!),
  ]);
  return _Reports(
    results[0] as List<Map<String, dynamic>>,
    results[1] as List<Map<String, dynamic>>,
    results[2] as List<Map<String, dynamic>>,
  );
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return FamPage(
      title: 'Reports',
      child: reports.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(reportsProvider)),
        data: (data) => ListView(
          children: [
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Collections (last 6 months)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                  if (data.collections.isEmpty)
                    const EmptyState(message: 'No data.')
                  else
                    ...data.collections.map((r) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r['bucket']}', style: const TextStyle(color: FamColors.textMuted)),
                            Text('${formatMoney(r['collected'])} / ${formatMoney(r['expected'])}',
                                style: const TextStyle(color: FamColors.textMuted)),
                            Text(formatMoney(r['outstanding']),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: (r['outstanding'] as num? ?? 0) > 0 ? FamColors.danger : FamColors.textMuted,
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
                  const Text('Occupancy', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                  if (data.occupancy.isEmpty)
                    const EmptyState(message: 'No data.')
                  else
                    ...data.occupancy.map((r) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r['bucket']}', style: const TextStyle(color: FamColors.textMuted)),
                            Text('${r['rented_units']}/${r['total_units']} units',
                                style: const TextStyle(color: FamColors.textMuted)),
                            Text('${r['occupancy_pct']}%',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
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
                  const Text('Overdue ageing', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                  if (data.ageing.isEmpty)
                    const EmptyState(message: 'Nothing overdue.')
                  else
                    ...data.ageing.map((r) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r['ageing']}', style: const TextStyle(color: FamColors.textMuted)),
                            Text('${r['charges']} charges', style: const TextStyle(color: FamColors.textMuted)),
                            Text(formatMoney(r['amount']),
                                style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.danger)),
                          ],
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
