#!/usr/bin/env python3
"""Patch a generated AndroidManifest.xml for release use.

`flutter create` only emits the LAUNCHER intent filter, so without this the
invite link (and the password-reset link GoTrue emails) never reaches the app.
It also puts `android.permission.INTERNET` only in the *debug* and *profile*
manifests, never in the main one — a release build therefore has no permission
to open sockets and every API call fails with a network error while the phone's
browser reaches the same host fine. Both patches are idempotent, and the file
is always re-validated, so a bad rewrite fails here with a clear message
instead of later inside Gradle's manifest merger.

Usage: python3 tool/patch_android_manifest.py <path/to/AndroidManifest.xml>
"""

import sys
import xml.dom.minidom

# Registered for the whole scheme (no host), exactly as `scheme` in the Expo
# app's app.json is, so every `fam://…` link opens the app. Routing then happens
# in Dart (lib/routing/deep_links.dart).
SCHEME = "fam"

# Normal permission, granted at install time — required for release builds,
# because `flutter create` adds it only to the debug/profile manifests.
INTERNET_PERMISSION = '    <uses-permission android:name="android.permission.INTERNET"/>\n'


INTENT_FILTER = """            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="{scheme}"/>
            </intent-filter>
""".format(scheme=SCHEME)


def _insert_after_manifest_tag(source, fragment):
    """Insert `fragment` on its own line directly after the <manifest …> tag."""
    start = source.find("<manifest")
    if start == -1:
        raise SystemExit("no <manifest> element found")
    end = source.find(">", start)
    if end == -1:
        raise SystemExit("unterminated <manifest> tag")
    # Insert after the newline that follows the manifest opening tag.
    line_end = source.find("\n", end)
    if line_end == -1:
        line_end = len(source) - 1
    return source[: line_end + 1] + fragment + source[line_end + 1 :]


def patch(path):
    """Add the INTERNET permission and VIEW intent filter once, then validate."""
    with open(path, encoding="utf-8") as handle:
        source = handle.read()

    changed = False

    if 'android.permission.INTERNET' not in source:
        source = _insert_after_manifest_tag(source, INTERNET_PERMISSION)
        changed = True
        print("Added android.permission.INTERNET to {0}".format(path))

    if 'android:scheme="{0}"'.format(SCHEME) not in source:
        marker = "</activity>"
        index = source.find(marker)
        if index == -1:
            raise SystemExit("{0}: no </activity> element to attach the deep link to".format(path))
        # Insert on its own line, indented as a sibling of the LAUNCHER filter.
        line_start = source.rfind("\n", 0, index) + 1
        source = source[:line_start] + INTENT_FILTER + source[line_start:]
        changed = True
        print("Added the {0}:// deep-link scheme (invite + reset-password) to {1}".format(SCHEME, path))

    if changed:
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(source)

    # Raises xml.parsers.expat.ExpatError when the result is not valid XML.
    xml.dom.minidom.parse(path)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    patch(sys.argv[1])
