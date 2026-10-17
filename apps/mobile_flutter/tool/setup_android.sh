#!/usr/bin/env bash
#
# Prepares the Android platform project for the Flutter client.
#
# The generated Gradle project is intentionally not committed (it contains a
# binary gradle-wrapper.jar), so this script creates it on demand with
# `flutter create` and then points it at the Play Store application id.
#
#   APPLICATION_ID  Play package name           (default: com.fami.myapp)
#   APP_NAME        Launcher label             (default: Fam)
#
# It is idempotent: an existing android/ directory is left untouched.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_ID="${APPLICATION_ID:-com.fami.myapp}"
APP_NAME="${APP_NAME:-Fam}"
FLUTTER_NAME="$(awk -F': ' '/^name:/{print $2; exit}' pubspec.yaml)"
DERIVED="${APP_ID%.*}.${FLUTTER_NAME}"

if [ ! -d android ]; then
  echo "Generating android/ project (flutter create)…"
  gen="$(mktemp -d)"
  flutter create --platforms=android --org "${APP_ID%.*}" --project-name "${FLUTTER_NAME}" "${gen}"
  cp -R "${gen}/android" android
  rm -rf "${gen}"
fi

# `flutter create` derives the id from --org + project name; rewrite it to the
# exact Play application id and keep MainActivity's package directory in sync.
echo "Setting applicationId to ${APP_ID}…"
while IFS= read -r file; do
  sed -i.bak "s/${DERIVED//./\\.}/${APP_ID}/g" "${file}"
  rm -f "${file}.bak"
done < <(grep -rlI "${DERIVED}" android 2>/dev/null || true)

src="android/app/src/main/kotlin/$(printf '%s' "${DERIVED}" | tr '.' '/')"
dst="android/app/src/main/kotlin/$(printf '%s' "${APP_ID}" | tr '.' '/')"
if [ -d "${src}" ] && [ "${src}" != "${dst}" ]; then
  mkdir -p "$(dirname "${dst}")"
  mv "${src}" "${dst}"
fi

manifest="android/app/src/main/AndroidManifest.xml"
if [ -f "${manifest}" ]; then
  sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"${APP_NAME}\"/" "${manifest}"
  # flutter_secure_storage keeps app data out of Google Drive backups; a restored
  # backup would carry encrypted values without their Keystore key. One single
  # substitution only — two expressions would add the attribute twice and the
  # manifest merger would reject the duplicate.
  if grep -q 'android:allowBackup' "${manifest}"; then
    sed -i.bak 's/android:allowBackup="[^"]*"/android:allowBackup="false"/' "${manifest}"
  else
    sed -i.bak 's/<application/<application android:allowBackup="false"/' "${manifest}"
  fi
  rm -f "${manifest}.bak"
  # Add the fam:// VIEW intent filter so the invite deep link reaches the app
  # (go_router rewrites the link in lib/routing/deep_links.dart). The script also
  # verifies the XML, so a malformed rewrite fails here rather than in Gradle.
  python3 tool/patch_android_manifest.py "${manifest}"
fi

# flutter_secure_storage needs API 23+; pin the floor explicitly rather than
# depending on the Flutter template's default.
if grep -q 'minSdk = flutter.minSdkVersion' android/app/build.gradle.kts 2>/dev/null; then
  sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 24/' android/app/build.gradle.kts
  rm -f android/app/build.gradle.kts.bak
elif grep -q 'minSdkVersion flutter.minSdkVersion' android/app/build.gradle 2>/dev/null; then
  sed -i.bak 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' android/app/build.gradle
  rm -f android/app/build.gradle.bak
fi

# ---- optional release signing -------------------------------------------
# `flutter create` signs release builds with the debug key, which Play rejects.
# When an upload keystore is supplied (ANDROID_KEYSTORE_* / KEYSTORE_* secrets),
# materialise it and point the release build at it.
STORE_B64="${ANDROID_KEYSTORE_BASE64:-${KEYSTORE_BASE64:-}}"
if [ -n "${STORE_B64}" ]; then
  STORE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:-${KEYSTORE_PASSWORD:-}}"
  if ! printf '%s' "${STORE_B64}" | tr -d '\r\n ' | base64 -d > android/app/upload-keystore.jks; then
    echo "Error: the keystore secret is not valid base64. Store it as" >&2
    echo "  base64 -w0 <upload-keystore.jks>  (a single line, no headers)." >&2
    exit 1
  fi
  # Fail with a readable message instead of a cryptic Gradle signing error.
  if command -v keytool >/dev/null 2>&1 \
    && ! keytool -list -keystore android/app/upload-keystore.jks -storepass "${STORE_PASSWORD}" >/dev/null 2>&1; then
    echo "Error: the keystore secret did not decode to a keystore that the store" >&2
    echo "password opens. Check KEYSTORE_BASE / KEYSTORE_PASSWORD (and that the" >&2
    echo "base64 is of the .jks/.keystore file itself)." >&2
    exit 1
  fi
  cat > android/key.properties <<EOF
storeFile=upload-keystore.jks
storePassword=${STORE_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS:-${KEY_ALIAS:-}}
keyPassword=${ANDROID_KEY_PASSWORD:-${KEY_PASSWORD:-}}
EOF
  python3 tool/patch_android_signing.py android/app/build.gradle.kts
  echo "Release signing configured from the provided keystore."
else
  echo "No keystore provided; release builds stay debug-signed (Play will reject them)."
fi

echo "Android project ready:"
grep -nE 'namespace|applicationId' android/app/build.gradle.kts 2>/dev/null \
  || grep -nE 'namespace|applicationId' android/app/build.gradle 2>/dev/null \
  || true
