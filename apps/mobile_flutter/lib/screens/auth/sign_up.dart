import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/invite_store.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

const _steps = ['Your details', 'Password', 'Terms'];

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 0;
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _acceptTerms = false;
  String? _error;
  bool _busy = false;

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
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await getSupabase().auth.signUp(
            email: _email.text.trim(),
            password: _password.text,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            data: {'full_name': _fullName.text.trim()},
          );
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
    return FamScreen(
      child: ListView(
        children: [
          Text('Create account', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_steps.length, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= _step ? FamColors.royal : FamColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  FamField(label: 'Full name', controller: _fullName),
                  const SizedBox(height: 12),
                  FamField(label: t('auth.email'), controller: _email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  FamField(label: t('auth.phone'), controller: _phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => setState(() => _step = 1), child: const Text('Continue')),
                ],
                if (_step == 1) ...[
                  FamField(label: t('auth.password'), controller: _password, obscureText: true),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: FamColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => setState(() => _step = 2), child: const Text('Continue')),
                ],
                if (_step == 2) ...[
                  _acceptTerms
                      ? FilledButton(
                          onPressed: () {}, child: const Text('✓ Terms accepted'))
                      : OutlinedButton(
                          onPressed: () => setState(() => _acceptTerms = true),
                          child: const Text('Accept terms'),
                        ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: FamColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text('Create account'),
                  ),
                ],
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
