#!/usr/bin/env python3
"""Point the generated Android project's release build at a real keystore.

`flutter create` wires `buildTypes.release` to the debug keystore, which Play
will reject. When an upload keystore is available (CI passes the
ANDROID_KEYSTORE_* secrets) `tool/setup_android.sh` drops it in
`android/app/upload-keystore.jks`, writes `android/key.properties`, and runs
this script to teach `android/app/build.gradle.kts` to sign with it.

The patch is deliberately strict: if the template no longer looks the way we
expect, we fail loudly rather than ship a debug-signed bundle.
"""
from __future__ import annotations

import pathlib
import sys

IMPORTS = "import java.io.FileInputStream\nimport java.util.Properties\n\n"

LOADER = """
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""

SIGNING_CONFIGS = """    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

"""

RELEASE_SIGNING = 'signingConfig = signingConfigs.getByName("release")'
DEBUG_SIGNING = 'signingConfig = signingConfigs.getByName("debug")'
STALE_COMMENT = """            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
"""


def fail(message: str) -> None:
    print(f"patch_android_signing: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: patch_android_signing.py <app/build.gradle.kts>")

    path = pathlib.Path(sys.argv[1])
    if not path.is_file():
        fail(f"{path} does not exist")
    text = path.read_text()

    if DEBUG_SIGNING not in text and RELEASE_SIGNING not in text:
        fail("release signingConfig block not found; the Flutter template changed")

    if LOADER not in text:
        if "\nandroid {" not in text:
            fail("no `android {` block; the Flutter template changed")
        text = text.replace("\nandroid {", "\n" + LOADER + "android {", 1)

    if "signingConfigs {" not in text:
        if "    buildTypes {" not in text:
            fail("no `buildTypes {` block; the Flutter template changed")
        text = text.replace("    buildTypes {", SIGNING_CONFIGS + "    buildTypes {", 1)

    text = text.replace(DEBUG_SIGNING, RELEASE_SIGNING)
    text = text.replace(STALE_COMMENT, "            // Signed with the upload keystore from android/key.properties.\n")

    if IMPORTS not in text.split("plugins {", 1)[0]:
        text = IMPORTS + text

    path.write_text(text)
    print(f"patch_android_signing: {path} now signs release with the upload keystore")


if __name__ == "__main__":
    main()
