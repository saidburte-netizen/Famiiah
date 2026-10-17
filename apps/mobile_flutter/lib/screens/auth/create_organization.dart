import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
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
          Text('Create your organization', style: Theme.of(context).textTheme.displayLarge),
          const Text("You'll be the owner of this workspace."),
          const SizedBox(height: 16),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                  const SizedBox(height: 8),
                ],
                FamField(label: 'Organization name', controller: _name),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: const Text('Create organization'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.go('/auth/login'), child: const Text('I have an invitation')),
        ],
      ),
    );
  }
}
