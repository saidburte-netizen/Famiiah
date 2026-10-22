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
    results[0],
    results[1],
    results[2],
  );
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return FamPage(
      title: 'Reports',
      subtitle: 'Collections, occupancy and ageing',
      child: reports.when(
        loading: () => const FamLoading(),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(reportsProvider)),
        data: (data) => ListView(
          children: [
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FamSectionHeader(title: 'Collections (last 6 months)'),
                  const SizedBox(height: 8),
                  if (data.collections.isEmpty)
                    const EmptyState(message: 'No data.')
                  else
                    ...data.collections.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${r['bucket']}',
                                  style: const TextStyle(
                                    fontFamily: FamFonts.body,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: FamColors.text,
                                  ),
                                ),
                              ),
                              Text(
                                formatMoney(r['collected'], decimals: 0),
                                style: const TextStyle(
                                  fontFamily: FamFonts.body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FamColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                formatMoney(r['outstanding'], decimals: 0),
                                style: TextStyle(
                                  fontFamily: FamFonts.body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: (r['outstanding'] as num? ?? 0) > 0
                                      ? FamColors.danger
                                      : FamColors.textMuted,
                                ),
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
                  const FamSectionHeader(title: 'Occupancy'),
                  const SizedBox(height: 8),
                  if (data.occupancy.isEmpty)
                    const EmptyState(message: 'No data.')
                  else
                    ...data.occupancy.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: FamProgress(
                            value: ((r['occupancy_pct'] as num?)?.toDouble() ?? 0) / 100,
                            label: '${r['bucket']} · ${r['rented_units']}/${r['total_units']} units',
                            trailing: '${r['occupancy_pct']}%',
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
                  const FamSectionHeader(title: 'Overdue ageing'),
                  const SizedBox(height: 8),
                  if (data.ageing.isEmpty)
                    const EmptyState(message: 'Nothing overdue.')
                  else
                    ...data.ageing.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${r['ageing']}',
                                  style: const TextStyle(
                                    fontFamily: FamFonts.body,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: FamColors.text,
                                  ),
                                ),
                              ),
                              Text(
                                '${r['charges']} charges',
                                style: const TextStyle(
                                  fontFamily: FamFonts.body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FamColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                formatMoney(r['amount'], decimals: 0),
                                style: const TextStyle(
                                  fontFamily: FamFonts.body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: FamColors.danger,
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FamSecondaryButton(
              label: 'View payment history',
              icon: Icons.receipt_long_outlined,
              onPressed: () => context.push('/app/payments'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
