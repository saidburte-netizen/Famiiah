import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/client.dart';
import '../../state/auth_notifier.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
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
      child: ListView(
        children: [
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Signed in as', style: TextStyle(color: FamColors.textMuted)),
                Text(name ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                Text(user?.email ?? '—', style: const TextStyle(color: FamColors.textMuted)),
                if (org.role != null)
                  Text('Role: ${org.role}', style: const TextStyle(color: FamColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const Text('Every recorded payment, with receipts and voiding.',
                    style: TextStyle(color: FamColors.textMuted)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => context.push('/app/payments'), child: const Text('Payment history')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const Text('Collections, occupancy and overdue ageing.',
                    style: TextStyle(color: FamColors.textMuted)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => context.push('/app/reports'), child: const Text('Open reports')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                const Text('Reminders, receipts and overdue alerts.',
                    style: TextStyle(color: FamColors.textMuted)),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: () => context.push('/app/notifications'), child: const Text('Open notifications')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('About', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.navy)),
                Text('App version $version', style: const TextStyle(color: FamColors.textMuted)),
                const Text('Currency ETB · Timezone Africa/Addis_Ababa',
                    style: TextStyle(color: FamColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _confirmSignOut(context, ref),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
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
    await ref.read(authProvider.notifier).signOut();
  }
}
