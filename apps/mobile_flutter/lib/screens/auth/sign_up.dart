import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/invite_store.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

/// Sign-up is one form — name, email, phone, password and the terms toggle all
/// on screen (splitting them across three steps hid the password behind a
/// "Continue" button and let people submit a form they could not review).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _acceptTerms = false;
  bool _busy = false;
  String? _error;

  /// Email of the account created but not yet confirmed. When the project
  /// requires email confirmation GoTrue returns no session, so there is nothing
  /// to sign in with until the link in the email is opened.
  String? _pendingEmail;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final _phoneRe = RegExp(r'^(\+251|0)(9|7)\d{8}$');

  /// Mirrors `SignUpSchema` in `@fam/shared` (Flutter has no zod).
  String? _validate() {
    if (_fullName.text.trim().length < 2) return 'Enter your full name.';
    if (!_emailRe.hasMatch(_email.text.trim())) return 'Enter a valid email.';
    if (!_phoneRe.hasMatch(_phone.text.trim())) return 'Enter a valid phone (09… or +251…).';
    if (_password.text.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(_password.text)) return 'Include an uppercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(_password.text)) return 'Include a number.';
    if (!_acceptTerms) return 'Accept the terms to continue.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final email = _email.text.trim();
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      // The phone number is profile data, not a sign-in identifier. Passing it
      // as `phone` makes GoTrue reject the whole request ("Only an email
      // address or phone number should be provided on signup") unless phone
      // sign-in is enabled for the project, so it goes in the metadata and
      // `handle_new_user()` stores it on the profile.
      final res = await getSupabase().auth.signUp(
            email: email,
            password: _password.text,
            data: {
              'full_name': _fullName.text.trim(),
              'phone': _phone.text.trim(),
            },
          );
      if (!mounted) return;
      if (res.session == null) {
        setState(() => _pendingEmail = email);
        return;
      }
      final pending = await takePendingInvite();
      if (!mounted) return;
      if (pending != null) {
        context.go('/invite?token=${Uri.encodeComponent(pending)}');
        return;
      }
      context.go('/auth/create-organization');
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingEmail = _pendingEmail;
    if (pendingEmail != null) return _confirmationScreen(pendingEmail);

    return FamScreen(
      child: ListView(
        children: [
          Text('Create account', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 16),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: FamColors.danger)),
                  const SizedBox(height: 12),
                ],
                FamField(
                  label: 'Full name',
                  controller: _fullName,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                FamField(
                  label: t('auth.email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                FamField(
                  label: t('auth.phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                FamField(label: t('auth.password'), controller: _password, obscureText: true),
                const SizedBox(height: 6),
                Text(
                  'At least 8 characters, with an uppercase letter and a number.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: FamColors.textMuted),
                ),
                const SizedBox(height: 12),
                _acceptTerms
                    ? FilledButton(
                        onPressed: _busy ? null : () => setState(() => _acceptTerms = false),
                        child: const Text('✓ Terms accepted (tap to undo)'))
                    : OutlinedButton(
                        onPressed: _busy ? null : () => setState(() => _acceptTerms = true),
                        child: const Text('Accept terms'),
                      ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t('auth.signUp')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.go('/auth/login'), child: Text(t('auth.signIn'))),
        ],
      ),
    );
  }

  /// Shown when the account exists but the email has not been confirmed yet.
  Widget _confirmationScreen(String email) {
    return FamScreen(
      child: ListView(
        children: [
          Text(t('auth.confirmEmailTitle'), style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 16),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t('auth.confirmEmailBody')),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: FamColors.midnight),
                ),
                const SizedBox(height: 12),
                Text(
                  t('auth.confirmEmailHint'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: FamColors.textMuted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/auth/login'),
                  child: Text(t('auth.signIn')),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _pendingEmail = null),
                  child: Text(t('auth.useAnotherEmail')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
