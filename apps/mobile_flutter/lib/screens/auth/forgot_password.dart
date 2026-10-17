import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../widgets/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Success is reported identically for known and unknown addresses, so the
      // screen never reveals whether an account exists. A *network* failure is
      // different: surface it instead of pretending the mail was sent.
      await getSupabase().auth.resetPasswordForEmail(
            _email.text.trim(),
            redirectTo: 'fam://reset-password',
          );
      if (mounted) setState(() => _sent = true);
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
          Text('Reset password', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 12),
          FamCard(
            child: _sent
                ? const Text("If an account exists for that email, we've sent a reset link. Check your inbox.")
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FamField(
                        label: t('auth.email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: const Text('Send reset link'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.go('/auth/login'), child: const Text('Back to sign in')),
        ],
      ),
    );
  }
}
