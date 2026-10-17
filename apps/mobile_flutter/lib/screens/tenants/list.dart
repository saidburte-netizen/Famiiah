import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

const _filters = ['all', 'active', 'overdue', 'expiring'];

final tenantsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listTenantsWithStatus(org.orgId!, filter);
});

class TenantsScreen extends ConsumerStatefulWidget {
  const TenantsScreen({super.key});

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(orgProvider);
    final tenants = ref.watch(tenantsProvider(_filter));
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
              Text('Tenants', style: text.displayLarge?.copyWith(color: FamColors.midnight)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, kMinTouch)),
                onPressed: () => context.push('/app/tenants/new'),
                child: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _filters
                .map((f) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _filter == f
                            ? FilledButton(
                                style: FilledButton.styleFrom(minimumSize: const Size(0, kMinTouch)),
                                onPressed: () => setState(() => _filter = f),
                                child: Text(f))
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, kMinTouch)),
                                onPressed: () => setState(() => _filter = f),
                                child: Text(f)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: tenants.when(
              loading: () => const FamLoading(),
              error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(tenantsProvider(_filter))),
              data: (rows) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(tenantsProvider(_filter)),
                child: rows.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), EmptyState(message: 'No tenants.')])
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final overdue = (r['overdue_days'] as num? ?? 0) > 0;
                          return InkWell(
                            onTap: () => context.push('/app/tenants/${r['id']}'),
                            borderRadius: BorderRadius.circular(FamRadius.card),
                            child: FamCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${r['full_name']}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                                      Text(
                                        overdue ? 'Overdue ${r['overdue_days']}d' : '${r['status']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: overdue ? FamColors.danger : FamColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text('${r['unit_code'] ?? '—'} · ${r['phone'] ?? 'no phone'}',
                                      style: const TextStyle(color: FamColors.textMuted)),
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
