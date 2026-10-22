import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/ui.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const {};
  return dashboardSummary(org.orgId!);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final dash = ref.watch(dashboardProvider);

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
            const SizedBox(height: 24),
            const FamLogo(size: 64, glow: true),
            const SizedBox(height: 20),
            const Text(
              'No workspace yet',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create an organization to start managing properties, tenants and rent.',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            FamPrimaryButton(
              label: 'Create organization',
              onPressed: () => context.go('/auth/create-organization'),
            ),
            const SizedBox(height: 10),
            FamSecondaryButton(
              label: 'Refresh',
              onPressed: () => ref.read(orgProvider.notifier).refresh(),
            ),
          ],
        ),
      );
    }

    return FamScreen(
      child: dash.when(
        loading: () => const Center(child: CircularProgressIndicator(color: FamColors.royal)),
        error: (e, _) =>
            ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(dashboardProvider)),
        data: (d) {
          final rate = (d['collection_rate'] as num?)?.toDouble() ?? 0;
          final due = (d['due_this_week'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // ---- greeting header -------------------------------------------
              Row(
                children: [
                  const FamLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(
                            fontFamily: FamFonts.body,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FamColors.textMuted,
                          ),
                        ),
                        const Text(
                          'Portfolio overview',
                          style: TextStyle(
                            fontFamily: FamFonts.body,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: FamColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FamIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/app/notifications'),
                  ),
                  const SizedBox(width: 8),
                  FamIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onPressed: () => context.push('/app/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ---- collected this month --------------------------------------
              FamHeroCard(
                label: 'Collected this month',
                value: formatMoney(d['collected_month'], decimals: 0),
                trailing: rate >= 100 ? 'On track' : '${rate.toStringAsFixed(0)}%',
                progress: rate / 100,
                caption: '${rate.toStringAsFixed(0)}% of '
                    '${formatMoney(d['expected_month'], decimals: 0)} expected',
                height: 96,
                onTap: () => context.push('/app/rent'),
              ),
              const SizedBox(height: 12),

              // ---- 2×2 metric grid -------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: FamStatTile(
                      icon: Icons.apartment_rounded,
                      value: '${d['properties_count'] ?? 0}',
                      label: 'Properties',
                      onTap: () => context.push('/app/properties'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FamStatTile(
                      icon: Icons.meeting_room_outlined,
                      value: '${d['units_total'] ?? 0}',
                      label: 'Units',
                      onTap: () => context.push('/app/properties'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FamStatTile(
                      icon: Icons.people_alt_outlined,
                      value: '${d['active_tenants'] ?? 0}',
                      label: 'Tenants',
                      onTap: () => context.push('/app/tenants'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FamStatTile(
                      icon: Icons.error_outline_rounded,
                      value: '${d['overdue_count'] ?? 0}',
                      label: 'Overdue',
                      alert: true,
                      onTap: () => context.push('/app/rent'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- quick actions ---------------------------------------------
              const FamSectionHeader(title: 'Quick actions'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.add_home_outlined,
                    label: 'Property',
                    onTap: () => context.push('/app/properties/new'),
                  ),
                  _QuickAction(
                    icon: Icons.door_front_door_outlined,
                    label: 'Unit',
                    onTap: () => context.push('/app/units/new'),
                  ),
                  _QuickAction(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Tenant',
                    onTap: () => context.push('/app/tenants/new'),
                  ),
                  _QuickAction(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock',
                    onTap: () => context.push('/app/stock'),
                  ),
                  _QuickAction(
                    icon: Icons.payments_outlined,
                    label: 'Rent',
                    onTap: () => context.push('/app/rent'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- overdue summary -------------------------------------------
              if ((d['overdue_count'] as num?)?.toInt() != 0) ...[
                FamNotice.error(
                  '${d['overdue_count']} overdue charge(s) · '
                  '${formatMoney(d['overdue_amount'])}',
                ),
                const SizedBox(height: 14),
              ],

              // ---- due this week --------------------------------------------
              if (due.isNotEmpty) ...[
                FamSectionHeader(
                  title: 'Due this week',
                  actionLabel: 'See all',
                  onAction: () => context.push('/app/rent'),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < due.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _DueRow(charge: due[i]),
                ],
                const SizedBox(height: 16),
              ],

              // ---- primary action -------------------------------------------
              FamPrimaryButton(
                label: 'Record payment',
                icon: Icons.add_card_rounded,
                onPressed: () => context.push('/app/payments/new'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FamSecondaryButton(
                      label: 'Payments',
                      icon: Icons.receipt_long_outlined,
                      height: 48,
                      dense: true,
                      onPressed: () => context.push('/app/payments'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FamSecondaryButton(
                      label: 'Reports',
                      icon: Icons.insights_outlined,
                      height: 48,
                      dense: true,
                      onPressed: () => context.push('/app/reports'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: FamColors.navy,
                  borderRadius: BorderRadius.circular(FamRadius.button),
                  boxShadow: FamShadows.control,
                ),
                child: Icon(icon, size: 22, color: FamColors.white),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FamColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  final Map<String, dynamic> charge;
  const _DueRow({required this.charge});

  @override
  Widget build(BuildContext context) {
    final name = (charge['tenant_name'] as String?)?.trim() ?? 'Tenant';
    final unit = charge['unit_code'] ?? '';
    final overdue = ((charge['due_date'] as String?)?.compareTo(
              DateTime.now().toIso8601String().substring(0, 10),
            ) ??
            0) <
        0;

    return Material(
      color: FamColors.white,
      borderRadius: BorderRadius.circular(FamRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(FamRadius.card),
        onTap: () => context.push('/app/rent'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FamRadius.card),
            boxShadow: FamShadows.card,
          ),
          child: Row(
            children: [
              FamAvatar(
                name: name,
                size: 40,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FamColors.text,
                      ),
                    ),
                    Text(
                      'Unit $unit · due ${charge['due_date'] ?? ''}',
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
              Text(
                formatMoney(charge['amount'], decimals: 0),
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: FamColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
