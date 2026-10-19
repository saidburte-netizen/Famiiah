/// The app's URL scheme (`fam://…`), matching `scheme` in the Expo app's
/// `app.json` and the intent filter `tool/patch_android_manifest.py` adds to the
/// generated Android manifest.
const String appScheme = 'fam';

/// Decides whether an incoming platform URI is an *authentication callback* that
/// `supabase_flutter` should exchange for a session — as opposed to an ordinary
/// app link such as `fam://invite?token=…`, which the router resolves itself.
///
/// Mirrors gotrue's default heuristic: a link qualifies when it carries any of
/// the auth parameters, whether in the query (`?code=…`) or the fragment
/// (`#access_token=…&type=recovery`, which is how the reset email arrives).
/// Because it is explicit, `detectSessionInUri` can be enabled without the
/// invitation link ever being treated as an auth callback.
bool isAuthCallbackLink(Uri uri) {
  if (uri.scheme != appScheme) return false;
  final fragment = Uri.splitQueryString(uri.fragment);
  bool has(String key) =>
      uri.queryParameters.containsKey(key) || fragment.containsKey(key);
  return has('access_token') ||
      has('code') ||
      has('error') ||
      has('error_code') ||
      has('error_description');
}

/// Rewrites an incoming platform URI into an in-app location, or returns null
/// when the URI needs no rewriting.
///
/// Android hands a custom-scheme deep link to the app as the *full* URI, so for
/// `fam://invite?token=…` the word `invite` is the URI **host**, not a path.
/// go_router matches locations against paths, so an unrewritten link is
/// unmatched and the invite screen would never open. This maps each supported
/// link onto its route:
///
/// ```
/// fam://invite?token=abc                 ->  /invite?token=abc
/// fam://invite                           ->  /invite
/// fam://reset-password#access_token=…    ->  /auth/reset-password#access_token=…
/// ```
///
/// The reset link GoTrue emails carries the recovery tokens in the URI
/// *fragment* (`#access_token=…&type=recovery`), which the browser/app does not
/// send to a server but which `supabase_flutter` parses when the app observes
/// the incoming URI. The fragment is re-attached verbatim so it survives the
/// rewrite.
///
/// Everything else returns null. In-app locations (`/app/home`) carry no
/// scheme, and unknown `fam://…` links are deliberately left alone so the
/// router's auth guard handles them (a signed-out user lands on sign-in)
/// instead of the "no route" error screen.
String? deepLinkRedirect(Uri uri) {
  if (uri.scheme != appScheme) return null;

  switch (uri.host) {
    case 'invite':
      // `uri.query` is already percent-encoded, so re-attach it verbatim.
      final query = uri.query;
      return query.isEmpty ? '/invite' : '/invite?$query';
    case 'reset-password':
      // Keep the fragment (recovery tokens) exactly as it arrived.
      final fragment = uri.fragment;
      return fragment.isEmpty ? '/auth/reset-password' : '/auth/reset-password#$fragment';
    default:
      return null;
  }
}
