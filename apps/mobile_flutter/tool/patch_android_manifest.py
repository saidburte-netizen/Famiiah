#!/usr/bin/env python3
"""Add the `fam://` invite deep link to a generated AndroidManifest.xml.

`flutter create` only emits the LAUNCHER intent filter, so without this the
invite link never reaches the app and the invite screen is unreachable. The
patch is idempotent and always re-validates the XML, so a bad rewrite fails here
with a clear message instead of later inside Gradle's manifest merger.

Usage: python3 tool/patch_android_manifest.py <path/to/AndroidManifest.xml>
"""

import sys
import xml.dom.minidom

# Registered for the whole scheme (no host), exactly as `scheme` in the Expo
# app's app.json is, so every `fam://…` link opens the app. Routing then happens
# in Dart (lib/routing/deep_links.dart).
SCHEME = "fam"


INTENT_FILTER = """            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="{scheme}"/>
            </intent-filter>
""".format(scheme=SCHEME)


def patch(path):
    """Insert the VIEW intent filter once, then validate the document."""
    with open(path, encoding="utf-8") as handle:
        source = handle.read()

    already_present = 'android:scheme="{0}"'.format(SCHEME) in source
    if not already_present:
        marker = "</activity>"
        index = source.find(marker)
        if index == -1:
            raise SystemExit("{0}: no </activity> element to attach the deep link to".format(path))
        # Insert on its own line, indented as a sibling of the LAUNCHER filter.
        line_start = source.rfind("\n", 0, index) + 1
        source = source[:line_start] + INTENT_FILTER + source[line_start:]
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(source)
        print("Added the {0}:// invite deep link to {1}".format(SCHEME, path))

    # Raises xml.parsers.expat.ExpatError when the result is not valid XML.
    xml.dom.minidom.parse(path)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    patch(sys.argv[1])
