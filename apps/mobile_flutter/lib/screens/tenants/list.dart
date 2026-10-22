import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../i18n/strings.dart';
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

/// Archived (soft-deleted) tenants, for the restore view.
final archivedTenantsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listArchivedTenants(org.orgId!);
});

class TenantsScreen extends ConsumerStatefulWidget {
  const TenantsScreen({super.key});

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  String _filter = 'all';
  bool _archived = false;

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
            subtitle: _archived ? 'Archived tenants' : 'People renting your units',
            actions: [
              FamIconButton(
                icon: _archived ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                tooltip: _archived ? t('common.hideArchived') : t('common.showArchived'),
                background: FamColors.background,
                onPressed: () => setState(() => _archived = !_archived),
              ),
              const SizedBox(width: 10),
              if (!_archived)
                FamIconButton(
                  icon: Icons.person_add_alt_1_rounded,
                  tooltip: 'Add tenant',
                  onPressed: () => context.push('/app/tenants/new'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_archived)
            Expanded(
              child: _ArchivedList(
                provider: archivedTenantsProvider,
                onRestore: (row) async {
                  await restoreTenant(row['id'] as String);
                  ref.invalidate(archivedTenantsProvider);
                  ref.invalidate(tenantsProvider(_filter));
                },
              ),
            )
          else ...[
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
        ],
      ),
    );
  }
}

/// A read-only list of archived tenants with a Restore action on each.
class _ArchivedList extends ConsumerWidget {
  final AutoDisposeFutureProvider<List<Map<String, dynamic>>> provider;
  final Future<void> Function(Map<String, dynamic> row) onRestore;

  const _ArchivedList({required this.provider, required this.onRestore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const FamLoading(),
      error: (e, _) => ErrorState(
        message: userMessage(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: rows.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.archive_outlined,
                  title: t('common.noArchived'),
                  message: 'Tenants you archive will appear here so you can restore them.',
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final name = '${r['full_name'] ?? r['business_name'] ?? r['id']}';
                  final sub = '${r['phone'] ?? ''}';
                  return FamCard(
                    child: Row(
                      children: [
                        const Icon(Icons.archive_outlined, size: 22, color: FamColors.textMuted),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: FamColors.navy,
                                ),
                              ),
                              if (sub.isNotEmpty)
                                Text(
                                  sub,
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
                        const SizedBox(width: 10),
                        FamSecondaryButton(
                          label: t('common.restore'),
                          height: 42,
                          dense: true,
                          filled: true,
                          onPressed: () async {
                            final ok = await famConfirm(
                              context,
                              title: t('common.restoreTitle'),
                              message: t('common.restoreBody'),
                              confirmLabel: t('common.restore'),
                            );
                            if (!ok) return;
                            try {
                              await onRestore(r);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(userMessage(e))));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
