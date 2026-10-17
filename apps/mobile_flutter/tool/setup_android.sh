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
  rm -f "${manifest}.bak"
fi

echo "Android project ready:"
grep -nE 'namespace|applicationId' android/app/build.gradle.kts 2>/dev/null \
  || grep -nE 'namespace|applicationId' android/app/build.gradle 2>/dev/null \
  || true
