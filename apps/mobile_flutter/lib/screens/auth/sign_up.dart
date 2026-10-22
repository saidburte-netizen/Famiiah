import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../core/errors/user_message.dart';
import '../../core/handle.dart';
import '../../core/invite_store.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/ui.dart';

/// Sign-up now collects a unique @handle (optional) and a terms toggle that has
/// to be ticked before the account is created.
///
/// The handle is the account's public name and, when supplied, must be unique
/// across the whole project, so the database owns the rule:
/// `handle_available()` lets the unauthenticated sign-up form ask whether a
/// handle is free, and the unique index is what actually guarantees it. A blank
/// handle leaves `profiles.handle` NULL (the index treats NULLs as distinct).
/// Handles are stored lowercase without the leading '@', matching `Handle` in
/// packages/shared/src/schemas.ts.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _acceptedTerms = false;
  String? _error;
  String? _notice;

  /// Loose client-side shape check — GoTrue is the real gate
  /// (`email_address_invalid` maps to friendly copy in `userMessage`).
  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// DORMANT: E.164 number waiting for its SMS code. Only set when the project
  /// has phone confirmations enabled (Providers → Phone on): GoTrue then
  /// creates the account, sends a code and returns no session, so there is
  /// nothing to sign in with until the code is verified. Email sign-up takes
  /// the confirm-email branch instead.
  String? _pendingPhone;

  @override
  void dispose() {
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  /// The handle and the terms acceptance travel in the sign-up metadata, where
  /// `handle_new_user()` (migration `0018`) stores them on the profile.
  Map<String, String> _metadata(String? handle) {
    final ts = DateTime.now().toUtc().toIso8601String();
    final h = handle?.trim() ?? '';
    if (h.isEmpty) {
      return {'accept_terms_at': ts};
    }
    return {'handle': h, 'accept_terms_at': ts};
  }

  /// Mirrors `SignUpSchema` in `@fam/shared` (Flutter has no zod).
  String? _validate({String? handle, String? email}) {
    // Handle is now optional; if provided, it must be valid.
    final handleRaw = _handle.text.trim();
    if (handleRaw.isNotEmpty && handle == null) {
      return t('error.handleInvalid');
    }
    if (email == null) {
      return _email.text.trim().isEmpty
          ? 'Fill in every field.'
          : t('error.emailInvalid');
    }
    if (_password.text.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(_password.text)) return 'Include an uppercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(_password.text)) return 'Include a number.';
    if (!_acceptedTerms) return t('error.acceptTerms');
    return null;
  }

  Future<void> _submit() async {
    final handle = normalizeHandle(_handle.text);
    final email = _email.text.trim();
    final invalid = _validate(
      handle: handle,
      email: _emailRe.hasMatch(email) ? email : null,
    );
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
      // Handles are unique project-wide. Only check availability if one was provided.
      if (handle != null) {
        final available =
            await getSupabase().rpc('handle_available', params: {'p_handle': handle});
        if (!mounted) return;
        if (available != true) {
          setState(() => _error = t('error.handleTaken'));
          return;
        }
      }
      final res = await getSupabase().auth.signUp(
            email: email,
            password: _password.text,
            data: _metadata(handle),
          );
      if (!mounted) return;
      if (res.session == null) {
        // The project has confirmations on: the account exists, the email
        // carries the link. With confirmations off (the free setup) a session
        // comes back immediately and this branch never runs.
        setState(() => _notice = t('auth.confirmEmail'));
        return;
      }
      await _afterAuth();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// DORMANT: confirm the SMS code GoTrue sent during a phone sign-up.
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

  /// DORMANT: ask GoTrue for a fresh code. The Dart SDK has no `resend`
  /// endpoint, but signing up again with an unconfirmed phone number
  /// re-sends the same OTP (GoTrue's `UserRepeatedSignUp` path) instead of
  /// creating a second user.
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
      final h = normalizeHandle(_handle.text);
      final res = await getSupabase().auth.signUp(
            phone: phone,
            password: _password.text,
            data: _metadata(h),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : () => setState(() => _acceptedTerms = !_acceptedTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _acceptedTerms ? FamColors.royal : FamColors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _acceptedTerms ? FamColors.royal : FamColors.borderStrong,
                width: 1.5,
              ),
            ),
            child: _acceptedTerms
                ? const Icon(Icons.check_rounded, size: 15, color: FamColors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('auth.acceptTerms'),
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: FamColors.textLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingPhone = _pendingPhone;
    // DORMANT — the phone-OTP confirmation screen: only reachable once the
    // project enables Providers → Phone and a phone sign-up returns no session.
    if (pendingPhone != null) return _confirmationScreen(pendingPhone);

    return Scaffold(
      backgroundColor: FamColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            Row(
              children: [
                FamIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  background: FamColors.background,
                  size: 44,
                  tooltip: 'Back',
                  onPressed: () => context.go('/auth/login'),
                ),
                const Spacer(),
                const Text(
                  'Fam',
                  style: TextStyle(
                    fontFamily: FamFonts.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: FamColors.navy,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Create your account',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 28,
                height: 1.12,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set up your portfolio in a few minutes.',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: FamColors.textLabel,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: FamColors.royal,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (var i = 0; i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: FamColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your details',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FamColors.textLabel,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FamNotice.error(_error!),
              const SizedBox(height: 14),
            ],
            if (_notice != null) ...[
              FamNotice(message: _notice!),
              const SizedBox(height: 14),
            ],
            FamField(
              label: t('auth.handle'),
              hint: 'optional',
              controller: _handle,
              keyboardType: TextInputType.text,
              prefixIcon: Icons.alternate_email_rounded,
              autocorrect: false,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 4),
            const Text(
              'Optional — your public name.',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            FamField(
              label: t('auth.email'),
              hint: 'you@example.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 14),
            FamField(
              label: t('auth.password'),
              hint: 'Create a password',
              controller: _password,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 6),
            const Text(
              'At least 8 characters, with an uppercase letter and a number.',
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            _termsRow(),
            const SizedBox(height: 20),
            FamPrimaryButton(
              label: t('auth.signUp'),
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already a member?',
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FamColors.textLabel,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/auth/login'),
                  child: Text(t('auth.signIn')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// DORMANT: shown when a phone account exists but the number still needs
  /// the code GoTrue sent by SMS.
  Widget _confirmationScreen(String phone) {
    return FamScreen(
      child: ListView(
        children: [
          const SizedBox(height: 8),
          const FamLogo(size: 56, glow: true),
          const SizedBox(height: 18),
          Text(
            t('auth.verifyPhoneTitle'),
            style: const TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FamColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  FamNotice.error(_error!),
                  const SizedBox(height: 14),
                ],
                if (_notice != null) ...[
                  FamNotice(message: _notice!),
                  const SizedBox(height: 14),
                ],
                Text(
                  t('auth.verifyPhoneBody'),
                  style: const TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: FamColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phone,
                  style: const TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FamColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                FamField(
                  label: t('auth.otpCode'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.password_rounded,
                ),
                const SizedBox(height: 18),
                FamPrimaryButton(
                  label: t('auth.verify'),
                  loading: _busy,
                  onPressed: _busy ? null : _verify,
                ),
                const SizedBox(height: 10),
                FamSecondaryButton(
                  label: t('auth.resendCode'),
                  onPressed: _busy ? null : _resend,
                ),
                const SizedBox(height: 10),
                FamSecondaryButton(
                  label: t('auth.changeNumber'),
                  onPressed: _busy ? null : () => setState(() => _pendingPhone = null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
