import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const {};
  return dashboardSummary(org.orgId!);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final dash = ref.watch(dashboardProvider);
    final text = Theme.of(context).textTheme;

    if (org.loading) {
      return const Center(child: CircularProgressIndicator(color: FamColors.royal));
    }
    if (org.error != null) {
      return FamScreen(
        child: ErrorState(
          message: userMessage(org.error),
          onRetry: () => ref.read(orgProvider.notifier).refresh(),
        ),
      );
    }
    if (org.orgId == null) {
      // A signed-in user with no membership is not a dead end: they can create
      // their own workspace (or accept a pending invitation) from here.
      return FamScreen(
        child: ListView(
          children: [
            const SizedBox(height: 60),
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('No workspace yet',
                      style: TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                  const SizedBox(height: 6),
                  const Text(
                    'Create an organization to start managing properties, tenants and rent.',
                    style: TextStyle(color: FamColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => context.go('/auth/create-organization'),
                    child: const Text('Create organization'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(orgProvider.notifier).refresh(),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return FamScreen(
      child: dash.when(
        loading: () => const Center(child: CircularProgressIndicator(color: FamColors.royal)),
        error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(dashboardProvider)),
        data: (d) {
          final tiles = [
            ('Collected', formatMoney(d['collected_month']), '/app/payments'),
            ('Expected', formatMoney(d['expected_month']), '/app/rent'),
            ('Occupancy', '${d['units_rented']}/${d['units_total']}', '/app/properties'),
            ('Overdue', '${d['overdue_count']}', '/app/rent'),
          ];
          final due = (d['due_this_week'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          return ListView(
            children: [
              Text('Dashboard', style: text.displayLarge?.copyWith(color: FamColors.midnight)),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(FamRadius.card),
                onTap: () => context.push('/app/rent'),
                child: FamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collection rate this month',
                          style: text.bodyMedium?.copyWith(color: FamColors.textMuted)),
                      Text('${d['collection_rate']}%',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, color: FamColors.navy)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tiles
                    .map((tile) => ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 140),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(FamRadius.card),
                            onTap: () => context.push(tile.$3),
                            child: FamCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tile.$1, style: const TextStyle(color: FamColors.textMuted)),
                                  Text(tile.$2,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, color: FamColors.navy)),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              FamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overdue', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${d['overdue_count']} charge(s) · ${formatMoney(d['overdue_amount'])}',
                        style: const TextStyle(color: FamColors.textMuted)),
                  ],
                ),
              ),
              if (due.isNotEmpty) ...[
                const SizedBox(height: 12),
                FamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Due this week', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () => context.push('/app/rent'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...due.map((c) => InkWell(
                            onTap: () => context.push('/app/rent'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text('${c['tenant_name']} · unit ${c['unit_code']}',
                                        style: const TextStyle(color: FamColors.textMuted)),
                                  ),
                                  Text('${c['due_date']} · ${formatMoney(c['amount'])}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, color: FamColors.navy)),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/properties/new'),
                      child: const Text('Property'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/units/new'),
                      child: const Text('Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/tenants/new'),
                      child: const Text('Tenant'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/stock'),
                      child: const Text('Stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push('/app/payments/new'),
                child: const Text('Record payment'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/payments'),
                      child: const Text('Payments'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/reports'),
                      child: const Text('Reports'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/notifications'),
                      child: const Text('Notifications'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/app/settings'),
                      child: const Text('Settings'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
