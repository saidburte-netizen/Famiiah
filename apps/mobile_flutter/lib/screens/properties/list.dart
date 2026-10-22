import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../i18n/strings.dart';
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

/// Archived (soft-deleted) properties, shown when the user toggles the view.
final archivedPropertiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listArchivedProperties(org.orgId!);
});

/// Whether the properties screen is showing the archive instead of live rows.
final showArchivedPropertiesProvider = StateProvider<bool>((_) => false);

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final archived = ref.watch(showArchivedPropertiesProvider);
    final properties = ref.watch(archived ? archivedPropertiesProvider : propertiesProvider);

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
            subtitle: archived ? 'Archived properties' : 'Your buildings and shops',
            actions: [
              FamIconButton(
                icon: archived ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                tooltip: archived ? t('common.hideArchived') : t('common.showArchived'),
                background: FamColors.background,
                onPressed: () =>
                    ref.read(showArchivedPropertiesProvider.notifier).state = !archived,
              ),
              const SizedBox(width: 10),
              if (!archived)
                FamIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Add property',
                  onPressed: () => context.push('/app/properties/new'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: archived
                ? _ArchivedList(
                    provider: archivedPropertiesProvider,
                    emptyIcon: Icons.archive_outlined,
                    emptyTitle: t('common.noArchived'),
                    emptyMessage: 'Properties you archive will appear here so you can restore them.',
                    onRestore: (row) async {
                      await restoreProperty(row['id'] as String);
                      ref.invalidate(archivedPropertiesProvider);
                      ref.invalidate(propertiesProvider);
                    },
                  )
                : properties.when(
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

/// A read-only list of archived rows with a Restore action on each.
class _ArchivedList extends ConsumerWidget {
  final AutoDisposeFutureProvider<List<Map<String, dynamic>>> provider;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function(Map<String, dynamic> row) onRestore;

  const _ArchivedList({
    required this.provider,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRestore,
  });

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
                EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage),
              ])
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final label = (r['name'] ?? r['full_name'] ?? r['id'].toString()).toString();
                  final sub =
                      (r['type'] ?? r['sku'] ?? r['phone'] ?? '').toString();
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
                                label,
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
