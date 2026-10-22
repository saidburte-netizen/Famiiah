import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/ui.dart';

/// First-run: the signed-in user creates their organization (becomes owner).
class CreateOrganizationScreen extends ConsumerStatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  ConsumerState<CreateOrganizationScreen> createState() => _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState extends ConsumerState<CreateOrganizationScreen> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await createOrganization(_name.text.trim());
      // The org provider cached "no membership"; refresh it before routing so
      // the dashboard comes up already populated.
      await ref.read(orgProvider.notifier).refresh();
      if (mounted) context.go('/app/home');
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FamScreen(
      child: ListView(
        children: [
          const SizedBox(height: 8),
          const FamLogo(size: 56, glow: true),
          const SizedBox(height: 18),
          const Text(
            'Create your organization',
            style: TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FamColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "You'll be the owner of this workspace.",
            style: TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: FamColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  FamNotice.error(_error!),
                  const SizedBox(height: 14),
                ],
                FamField(
                  label: 'Organization name',
                  hint: 'e.g. Burte Holdings',
                  controller: _name,
                  prefixIcon: Icons.business_outlined,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _create(),
                ),
                const SizedBox(height: 18),
                FamPrimaryButton(
                  label: 'Create organization',
                  loading: _busy,
                  onPressed: _busy ? null : _create,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FamSecondaryButton(
            label: 'I have an invitation',
            onPressed: () => context.go('/auth/login'),
          ),
        ],
      ),
    );
  }
}
