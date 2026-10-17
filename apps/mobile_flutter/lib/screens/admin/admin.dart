import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

const _roles = ['owner', 'manager', 'staff', 'viewer'];
const _statuses = ['active', 'suspended', 'pending'];

final membersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listMembers(org.orgId!);
});

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final members = ref.watch(membersProvider);
    final isOwner = org.role == 'owner';
    final text = Theme.of(context).textTheme;

    if (org.role != 'owner' && org.role != 'manager') {
      return const FamScreen(child: EmptyState(message: 'You do not have access to this section.'));
    }

    return FamScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Admin', style: text.displayLarge?.copyWith(color: FamColors.midnight)),
          const SizedBox(height: 12),
          if (isOwner)
            FilledButton(
              onPressed: () => _showInvite(context, ref),
              child: const Text('Invite teammate'),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: members.when(
              loading: () => const FamLoading(),
              error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(membersProvider)),
              data: (rows) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(membersProvider),
                child: rows.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), EmptyState(message: 'No members.')])
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final m = rows[i];
                          final uid = '${m['user_id']}';
                          return FamCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${m['full_name'] ?? uid.substring(0, 8)}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: FamColors.navy)),
                                    Text('${m['role']}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                                  ],
                                ),
                                Text('${m['status']}', style: const TextStyle(color: FamColors.textMuted)),
                                if (isOwner) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () => _showManage(context, ref, m),
                                    child: const Text('Manage'),
                                  ),
                                ],
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

  Future<void> _showInvite(BuildContext context, WidgetRef ref) async {
    final orgId = ref.read(orgProvider).orgId;
    if (orgId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => _InviteSheet(orgId: orgId),
    );
  }

  Future<void> _showManage(BuildContext context, WidgetRef ref, Map<String, dynamic> member) async {
    final orgId = ref.read(orgProvider).orgId;
    if (orgId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamColors.background,
      builder: (_) => _ManageSheet(orgId: orgId, member: member, onDone: () async => ref.invalidate(membersProvider)),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final String orgId;
  const _InviteSheet({required this.orgId});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'staff';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await inviteMember({
        'orgId': widget.orgId,
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'role': _role,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invite teammate', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FamField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  FamField(label: 'Phone (optional)', controller: _phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  const Text('Role', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roles
                        .map((r) => _role == r
                            ? FilledButton(onPressed: () => setState(() => _role = r), child: Text(r))
                            : OutlinedButton(onPressed: () => setState(() => _role = r), child: Text(r)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('Send invitation')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageSheet extends StatefulWidget {
  final String orgId;
  final Map<String, dynamic> member;
  final Future<void> Function() onDone;
  const _ManageSheet({required this.orgId, required this.member, required this.onDone});

  @override
  State<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends State<_ManageSheet> {
  late String _role = widget.member['role'] as String? ?? 'staff';
  late String _status = widget.member['status'] as String? ?? 'active';
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final uid = widget.member['user_id'] as String;
    try {
      if (_role != widget.member['role']) await adminSetMemberRole(widget.orgId, uid, _role);
      if (_status != widget.member['status']) await adminSetMemberStatus(widget.orgId, uid, _status);
      await widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Manage member',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: FamColors.midnight)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FamColors.danger)),
              const SizedBox(height: 8),
            ],
            FamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Role', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roles
                        .map((r) => _role == r
                            ? FilledButton(onPressed: () => setState(() => _role = r), child: Text(r))
                            : OutlinedButton(onPressed: () => setState(() => _role = r), child: Text(r)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statuses
                        .map((s) => _status == s
                            ? FilledButton(onPressed: () => setState(() => _status = s), child: Text(s))
                            : OutlinedButton(onPressed: () => setState(() => _status = s), child: Text(s)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
