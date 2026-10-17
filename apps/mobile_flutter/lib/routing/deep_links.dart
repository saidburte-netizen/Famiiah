/// The app's URL scheme (`fam://…`), matching `scheme` in the Expo app's
/// `app.json` and the intent filter `tool/patch_android_manifest.py` adds to the
/// generated Android manifest.
const String appScheme = 'fam';

/// Rewrites an incoming platform URI into an in-app location, or returns null
/// when the URI needs no rewriting.
///
/// Android hands a custom-scheme deep link to the app as the *full* URI, so for
/// `fam://invite?token=…` the word `invite` is the URI **host**, not a path.
/// go_router matches locations against paths, so an unrewritten link is
/// unmatched and the invite screen would never open. This maps the invite link
/// onto the equivalent route:
///
/// ```
/// fam://invite?token=abc  ->  /invite?token=abc
/// fam://invite            ->  /invite
/// ```
///
/// Everything else returns null. In-app locations (`/app/home`) carry no
/// scheme, and other `fam://…` links are deliberately left alone so the
/// router's auth guard handles them (a signed-out user lands on sign-in)
/// instead of the "no route" error screen.
String? deepLinkRedirect(Uri uri) {
  if (uri.scheme != appScheme || uri.host != 'invite') return null;

  // `uri.query` is already percent-encoded, so re-attach it verbatim.
  final query = uri.query;
  return query.isEmpty ? '/invite' : '/invite?$query';
}
