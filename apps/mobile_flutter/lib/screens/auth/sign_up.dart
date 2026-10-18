import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../core/errors/user_message.dart';
import '../../core/handle.dart';
import '../../core/invite_store.dart';
import '../../core/phone.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

/// Sign-up is one form — @handle, phone number and password all on screen,
/// plus the terms toggle that has to be ticked. The phone number is the
/// account's sign-in identifier, so it goes to GoTrue as `phone` (in E.164)
/// while the handle and the terms acceptance travel in the metadata, where
/// `handle_new_user()` (migration `0018`) stores them on the profile.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _handle = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _acceptedTerms = false;
  String? _error;
  String? _notice;

  /// E.164 number waiting for its SMS code. Only set when the project has
  /// phone confirmations enabled: GoTrue then creates the account, sends a
  /// code and returns no session, so there is nothing to sign in with until
  /// the code is verified.
  String? _pendingPhone;

  @override
  void dispose() {
    _handle.dispose();
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  /// The handle and the terms acceptance travel in the sign-up metadata, where
  /// `handle_new_user()` (migration `0018`) stores them on the profile.
  Map<String, String> _metadata(String handle) => {
        'handle': handle,
        'accept_terms_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// Mirrors `SignUpSchema` in `@fam/shared` (Flutter has no zod).
  String? _validate({String? handle, String? phone}) {
    if (handle == null) {
      // an empty field and a malformed one deserve different words
      return _handle.text.trim().isEmpty
          ? 'Fill in every field.'
          : t('error.handleInvalid');
    }
    if (phone == null) return 'Enter a valid phone (09… or +251…).';
    if (_password.text.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(_password.text)) return 'Include an uppercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(_password.text)) return 'Include a number.';
    if (!_acceptedTerms) return t('error.acceptTerms');
    return null;
  }

  Future<void> _submit() async {
    final handle = normalizeHandle(_handle.text);
    final phone = toE164(_phone.text);
    final invalid = _validate(handle: handle, phone: phone);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _error = null;
      _notice = null;
      _busy = true;
    });
    try {
      // Handles are unique project-wide. The form asks before creating the
      // account so the user can pick another one; the unique index on
      // profiles.handle is what actually guarantees it.
      final available =
          await getSupabase().rpc('handle_available', params: {'p_handle': handle});
      if (!mounted) return;
      if (available != true) {
        setState(() => _error = t('error.handleTaken'));
        return;
      }
      final res = await getSupabase().auth.signUp(
            phone: phone!,
            password: _password.text,
            data: _metadata(handle!),
          );
      if (!mounted) return;
      if (res.session == null) {
        setState(() => _pendingPhone = phone);
        return;
      }
      await _afterAuth();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confirm the SMS code GoTrue sent during sign-up.
  Future<void> _verify() async {
    final phone = _pendingPhone;
    if (phone == null) return;
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from the SMS.');
      return;
    }
    setState(() {
      _error = null;
      _notice = null;
      _busy = true;
    });
    try {
      await getSupabase().auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);
      if (!mounted) return;
      await _afterAuth();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ask GoTrue for a fresh code. The Dart SDK has no `resend` endpoint, but
  /// signing up again with an unconfirmed phone number re-sends the same OTP
  /// (GoTrue's `UserRepeatedSignUp` path) instead of creating a second user.
  Future<void> _resend() async {
    final phone = _pendingPhone;
    if (phone == null) return;
    setState(() {
      _error = null;
      _notice = null;
      _busy = true;
    });
    try {
      // Re-sending keeps the same handle; a missing one degrades to a plain
      // sign-up attempt, which GoTrue answers with the same OTP request.
      final res = await getSupabase().auth.signUp(
            phone: phone,
            password: _password.text,
            data: _metadata(normalizeHandle(_handle.text) ?? ''),
          );
      if (!mounted) return;
      // The account is still unconfirmed, so no session comes back; only the
      // code is re-sent. A session would mean it was confirmed meanwhile.
      setState(() => _notice = res.session == null ? t('auth.codeSent') : null);
      if (res.session != null) await _afterAuth();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A session exists: accept a pending invitation if there is one, otherwise
  /// send the new account to create its first organization.
  Future<void> _afterAuth() async {
    final pending = await takePendingInvite();
    if (!mounted) return;
    if (pending != null) {
      context.go('/invite?token=${Uri.encodeComponent(pending)}');
      return;
    }
    context.go('/auth/create-organization');
  }

  /// The terms toggle. Sign-up is refused until it is ticked; the acceptance
  /// time is sent along so `profiles.accept_terms_at` records it.
  Widget _termsRow() {
    return InkWell(
      onTap: _busy ? null : () => setState(() => _acceptedTerms = !_acceptedTerms),
      borderRadius: BorderRadius.circular(FamRadius.button),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FamColors.white,
          borderRadius: BorderRadius.circular(FamRadius.button),
          border: Border.all(color: _acceptedTerms ? FamColors.royal : FamColors.border),
        ),
        child: Row(
          children: [
            Icon(
              _acceptedTerms ? Icons.check_box : Icons.check_box_outline_blank,
              color: _acceptedTerms ? FamColors.royal : FamColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t('auth.acceptTerms'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingPhone = _pendingPhone;
    if (pendingPhone != null) return _confirmationScreen(pendingPhone);

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
                  label: t('auth.handle'),
                  controller: _handle,
                  keyboardType: TextInputType.text,
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
                _termsRow(),
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

  /// Shown when the account exists but the phone number still needs the code
  /// GoTrue sent by SMS.
  Widget _confirmationScreen(String phone) {
    return FamScreen(
      child: ListView(
        children: [
          Text(t('auth.verifyPhoneTitle'), style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 16),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: FamColors.danger)),
                  const SizedBox(height: 12),
                ],
                if (_notice != null) ...[
                  Text(_notice!, style: const TextStyle(color: FamColors.royal)),
                  const SizedBox(height: 12),
                ],
                Text(t('auth.verifyPhoneBody')),
                const SizedBox(height: 4),
                Text(phone, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                FamField(
                  label: t('auth.otpCode'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t('auth.verify')),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _resend,
                  child: Text(t('auth.resendCode')),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _pendingPhone = null),
                  child: Text(t('auth.changeNumber')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
