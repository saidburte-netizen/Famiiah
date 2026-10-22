import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
          Row(
            children: [
              FamIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                background: FamColors.background,
                tooltip: 'Back',
                onPressed: () => context.go('/auth/login'),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reset password',
                style: TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: FamColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FamCard(
            child: _sent
                ? const FamNotice.success(
                    "If an account exists for that email, we've sent a reset link. Check your inbox.")
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FamField(
                        label: t('auth.email'),
                        hint: 'you@example.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _busy ? null : _send(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        FamNotice.error(_error!),
                      ],
                      const SizedBox(height: 16),
                      FamPrimaryButton(
                        label: 'Send reset link',
                        loading: _busy,
                        onPressed: _busy ? null : _send,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
