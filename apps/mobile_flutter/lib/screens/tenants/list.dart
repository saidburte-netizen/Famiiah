import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
            title: 'Tenants',
            subtitle: 'People renting your units',
            actions: [
              FamIconButton(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Add tenant',
                onPressed: () => context.push('/app/tenants/new'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FamFilterPills(
            labels: _filters.map((f) => f[0].toUpperCase() + f.substring(1)).toList(),
            selected: _filters.indexOf(_filter),
            onChanged: (i) => setState(() => _filter = _filters[i]),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: tenants.when(
              loading: () => const FamLoading(),
              error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(tenantsProvider(_filter))),
              data: (rows) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(tenantsProvider(_filter)),
                child: rows.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.people_alt_rounded,
                          title: 'No tenants here',
                          message: 'Add a tenant and assign them a vacant unit.',
                          actionLabel: 'Add tenant',
                          onAction: () => context.push('/app/tenants/new'),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final overdue = (r['overdue_days'] as num? ?? 0) > 0;
                          final name = '${r['full_name']}';
                          return FamCard(
                            onTap: () => context.push('/app/tenants/${r['id']}'),
                            child: Row(
                              children: [
                                FamAvatar(
                                  name: name,
                                  size: 44,
                                  background: overdue ? FamColors.dangerBg : FamColors.tint,
                                  foreground: overdue ? FamColors.danger : FamColors.royalMid,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
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
                                        '${r['unit_code'] ?? '—'} · ${r['phone'] ?? 'no phone'}',
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
                                overdue
                                    ? FamBadge(
                                        label: 'Overdue ${r['overdue_days']}d',
                                        foreground: FamColors.danger,
                                        background: FamColors.dangerBg,
                                      )
                                    : FamBadge(label: '${r['status']}'),
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
