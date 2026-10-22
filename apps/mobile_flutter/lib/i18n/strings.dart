/// Minimal message catalogue, mirroring `apps/mobile/i18n/index.ts`.
/// English is the source of truth; other locales fall back until translated.
library;

typedef Messages = Map<String, String>;

const Messages _en = {
  'app.name': 'Fam',
  'auth.signIn': 'Sign in',
  'auth.signUp': 'Create account',
  'auth.handle': '@handle',
  'auth.acceptTerms': 'I accept the terms',
  'auth.email': 'Email',
  'auth.phone': 'Phone',
  'auth.phoneOrEmail': 'Phone or email',
  'auth.password': 'Password',
  'auth.forgotPassword': 'Forgot password?',
  'auth.remember': 'Remember me',
  'auth.useBiometrics': 'Unlock with biometrics',
  'auth.verifyPhoneTitle': 'Confirm your phone',
  'auth.verifyPhoneBody': 'Enter the 6-digit code we sent to',
  'auth.otpCode': 'Code',
  'auth.verify': 'Verify',
  'auth.resendCode': 'Send a new code',
  'auth.codeSent': 'A new code is on its way.',
  'auth.confirmEmail': 'Check your email — we sent a confirmation link to finish signing up.',
  'auth.changeNumber': 'Use a different number',
  'auth.resetPasswordTitle': 'Choose a new password',
  'auth.newPassword': 'New password',
  'auth.updatePassword': 'Update password',
  'auth.passwordUpdated': 'Your password has been updated.',
  'nav.home': 'Home',
  'nav.properties': 'Properties',
  'nav.tenants': 'Tenants',
  'nav.rent': 'Rent',
  'nav.admin': 'Admin',

  // ---- shared screen chrome / actions (mirrors apps/mobile/i18n) ----
  'common.new': 'New',
  'common.save': 'Save',
  'common.cancel': 'Cancel',
  'common.confirm': 'Confirm',
  'common.manage': 'Manage',
  'common.refresh': 'Refresh',
  'common.history': 'History',
  'common.adjust': 'Adjust',
  'common.return': 'Return',
  'common.renew': 'Renew',
  'common.terminate': 'Terminate',
  'common.void': 'Void',
  'common.existing': 'Existing',
  'common.settings': 'Settings',
  'common.notifications': 'Notifications',
  'common.payments': 'Payments',
  'common.reports': 'Reports',
  'common.stock': 'Stock',
  'common.property': 'Property',
  'common.tenant': 'Tenant',
  'common.unit': 'Unit',
  'common.archive': 'Archive',
  'common.restore': 'Restore',
  'common.archiveTitle': 'Archive this record?',
  'common.archiveBody':
      'It will be hidden from your lists and totals. You can restore it later.',
  'common.restoreTitle': 'Restore this record?',
  'common.restoreBody': 'It will appear in your lists and totals again.',
  'common.archived': 'Archived',
  'common.showArchived': 'Show archived',
  'common.hideArchived': 'Hide archived',
  'common.noArchived': 'Nothing archived.',

  // ---- errors: result codes raised by RPCs / edge functions ----
  'error.forbidden': 'You do not have permission to do that.',
  'error.mfaRequired': 'Multi-factor authentication is required.',
  'error.unitNotVacant': 'That unit already has an active lease.',
  'error.invalidAmount': 'Enter a valid amount.',
  'error.insufficientStock': 'Not enough stock available.',
  'error.negativeBalance': 'Stock cannot go below zero.',
  'error.cannotDemoteLastOwner': 'You cannot demote the last owner.',
  'error.rateLimited': 'Too many requests. Please wait and try again.',
  'error.leaseNotFound': 'That lease no longer exists.',
  'error.unitNotFound': 'That unit no longer exists.',
  'error.paymentNotFound': 'That payment no longer exists.',
  'error.itemNotFound': 'That item no longer exists.',
  'error.invitationNotFound': 'That invitation could not be found.',
  'error.invitationExpired': 'That invitation has expired. Ask for a new one.',
  'error.invalidToken': 'That link is no longer valid.',
  'error.alreadyMember': 'This person is already a member.',
  'error.propertyNotFound': 'That property no longer exists.',
  'error.tenantNotFound': 'That tenant no longer exists.',
  // Archive guards: the record still has live dependants.
  'error.propertyHasUnits':
      'Remove or archive this property\'s units first — it still has units in it.',
  'error.unitHasLease': 'This unit still has an active lease. End the lease first.',
  'error.tenantHasLease':
      'This tenant still has an active lease. End the lease first.',
  'error.itemHasRental':
      'This item is still rented out. Take the rental back first.',
  'error.itemHasStock':
      'This item still has stock on hand. Adjust it down to zero first.',
  'error.unknown': 'Something went wrong. Please try again.',

  // ---- auth (Supabase AuthError codes) ----
  'error.invalidCredentials': 'Incorrect phone/email or password.',
  'error.emailNotConfirmed': 'Confirm your email before signing in.',
  'error.phoneNotConfirmed': 'Confirm your phone number before signing in.',
  'error.alreadyRegistered': 'That account already exists. Try signing in.',
  'error.weakPassword': 'Choose a stronger password.',
  'error.emailInvalid': 'That email address was rejected. Check it and try again.',
  'error.invalidPhone': 'Enter a valid phone number (09… or +251…).',
  'error.handleInvalid':
      '@handles are 3–24 letters, numbers or underscores and start with a letter.',
  'error.handleTaken': 'That @handle is taken. Try another one.',
  'error.acceptTerms': 'Accept the terms to create your account.',
  'error.signupDisabled': 'New sign-ups are turned off for this app.',
  'error.phoneProviderDisabled': 'Phone sign-up is not enabled for this app.',
  'error.smsFailed': 'We could not send the SMS. Please try again.',

  // ---- errors: transport / protocol level ----
  'error.network': 'No connection. Check your network and try again.',
  'error.conflict': 'That action conflicts with existing data.',
  'error.invalidInput': 'Check the details and try again.',
  'error.notFound': 'We could not find what you were looking for.',
  'error.conflictDuplicate': 'That already exists.',
  'error.sessionExpired': 'Your session has expired. Please sign in again.',
};

final Map<String, Messages> _catalog = {
  'en': _en,
  // Placeholder locales fall back to English until translations are supplied.
  'am': _en,
  'om': _en,
};

String _locale = 'en';

void setLocale(String locale) {
  if (_catalog.containsKey(locale)) _locale = locale;
}

String getLocale() => _locale;

Messages get messages => _catalog[_locale]!;

/// Translate a key; returns `fallback` (or the key) when missing.
String t(String key, [String? fallback]) => _catalog[_locale]![key] ?? fallback ?? key;
