import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/supabase/client.dart';
import '../../state/auth_notifier.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final appVersionProvider = FutureProvider.autoDispose<String>((_) => getAppVersion());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final org = ref.watch(orgProvider);
    final version = ref.watch(appVersionProvider).valueOrNull ?? '—';
    final name = user?.userMetadata?['full_name'] as String?;

    return FamPage(
      title: 'Settings',
      subtitle: 'Account and workspace',
      child: ListView(
        children: [
          FamCard(
            child: Row(
              children: [
                FamAvatar(name: name ?? user?.email ?? 'Fam', size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Signed in',
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
                        user?.email ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: FamFonts.body,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FamColors.textMuted,
                        ),
                      ),
                      if (org.role != null) ...[
                        const SizedBox(height: 4),
                        FamBadge(label: '${org.role}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsLink(
            icon: Icons.receipt_long_outlined,
            title: 'Payments',
            subtitle: 'Every recorded payment, with receipts and voiding.',
            actionLabel: 'Payment history',
            onTap: () => context.push('/app/payments'),
          ),
          const SizedBox(height: 12),
          _SettingsLink(
            icon: Icons.insights_outlined,
            title: 'Reports',
            subtitle: 'Collections, occupancy and overdue ageing.',
            actionLabel: 'Open reports',
            onTap: () => context.push('/app/reports'),
          ),
          const SizedBox(height: 12),
          _SettingsLink(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Reminders, receipts and overdue alerts.',
            actionLabel: 'Open notifications',
            onTap: () => context.push('/app/notifications'),
          ),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FamSectionHeader(title: 'About'),
                const SizedBox(height: 10),
                FamInfoRow(label: 'App version', value: version, icon: Icons.info_outline_rounded),
                const Divider(),
                const FamInfoRow(label: 'Currency', value: 'ETB', icon: Icons.payments_outlined),
                const Divider(),
                const FamInfoRow(
                    label: 'Timezone', value: 'Africa/Addis_Ababa', icon: Icons.public_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FamSecondaryButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            borderColor: FamColors.danger,
            onPressed: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).signOut();
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessage(err))),
      );
    }
  }
}

/// A settings row: icon tile, title, description and a full-width action.
class _SettingsLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: Icon(icon, size: 22, color: FamColors.royal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FamColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: FamColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FamSecondaryButton(label: actionLabel, onPressed: onTap, height: 48, dense: true),
        ],
      ),
    );
  }
}
