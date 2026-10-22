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

    if (org.role != 'owner' && org.role != 'manager') {
      return const FamScreen(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Owners and managers only',
          message: 'You do not have access to this section.',
        ),
      );
    }

    return FamScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FamScreenHeader(
            title: 'Admin',
            subtitle: 'Team and workspace controls',
            actions: [
              if (isOwner)
                FamIconButton(
                  icon: Icons.person_add_alt_1_rounded,
                  tooltip: 'Invite teammate',
                  onPressed: () => _showInvite(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FamSecondaryButton(
                  label: 'Reports',
                  icon: Icons.insights_outlined,
                  height: 48,
                  dense: true,
                  filled: true,
                  onPressed: () => context.push('/app/reports'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FamSecondaryButton(
                  label: 'Stock',
                  icon: Icons.inventory_2_outlined,
                  height: 48,
                  dense: true,
                  filled: true,
                  onPressed: () => context.push('/app/stock'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FamSecondaryButton(
                  label: 'Properties',
                  icon: Icons.apartment_rounded,
                  height: 48,
                  dense: true,
                  filled: true,
                  onPressed: () => context.go('/app/properties'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const FamSectionHeader(title: 'Members'),
          const SizedBox(height: 8),
          Expanded(
            child: members.when(
              loading: () => const FamLoading(),
              error: (e, _) => ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(membersProvider)),
              data: (rows) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(membersProvider),
                child: rows.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.people_alt_rounded,
                          title: 'No members yet',
                          message: 'Invite a teammate to share this workspace.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final m = rows[i];
                          final uid = '${m['user_id']}';
                          final name = '${m['full_name'] ?? uid.substring(0, 8)}';
                          return FamCard(
                            onTap: isOwner ? () => _showManage(context, ref, m) : null,
                            child: Row(
                              children: [
                                FamAvatar(name: name, size: 44),
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
                                        '${m['status']}',
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
                                FamBadge(label: '${m['role']}'),
                                if (isOwner) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 20, color: FamColors.textMuted),
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

/// Shared role/status chooser: the active option is a filled navy pill.
class _ChoiceRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: FamFonts.body,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FamColors.textLabel,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((o) => o == value
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => onChanged(o),
                      child: Text(o),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => onChanged(o),
                      child: Text(o),
                    ))
              .toList(),
        ),
      ],
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Invite teammate',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'They join the moment they accept the invitation.',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FamNotice.error(_error!),
              const SizedBox(height: 14),
            ],
            FamField(
              label: 'Email',
              hint: 'teammate@example.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              autocorrect: false,
            ),
            const SizedBox(height: 14),
            FamField(
              label: 'Phone (optional)',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 18),
            _ChoiceRow(
              label: 'Role',
              options: _roles,
              value: _role,
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 20),
            FamPrimaryButton(
              label: 'Send invitation',
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 10),
            FamSecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
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
    final name = '${widget.member['full_name'] ?? 'Member'}';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FamAvatar(name: name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: FamFonts.body,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: FamColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FamNotice.error(_error!),
              const SizedBox(height: 14),
            ],
            _ChoiceRow(
              label: 'Role',
              options: _roles,
              value: _role,
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 18),
            _ChoiceRow(
              label: 'Status',
              options: _statuses,
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 20),
            FamPrimaryButton(
              label: 'Save',
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 10),
            FamSecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
