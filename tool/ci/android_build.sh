#!/usr/bin/env bash
# Shared Android APK build for GitHub CI and the F-Droid metadata.
#
# Order of operations is identical on both build systems (reproducible-build
# requirement — do not reorder without validating sha256 parity against the
# published release APKs):
#   1. app patches (tool/patch_*.dart) — ApertureX currently ships none; the
#      hook exists so future patches apply on CI and F-Droid exactly like
#      nook's appflowy_editor / sqlite patches.
#   2. release signing, but only when keystore secrets are present (CI);
#      F-Droid builds unsigned and signs with its own key.
#   3. flutter build apk with SOURCE_DATE_EPOCH=0 (reproducible), per-ABI
#      splits, Dart obfuscation + split debug info.
#
# Usage: tool/ci/android_build.sh [flutter-target-platform ...]
#   [platform ...]   e.g. android-arm android-arm64 android-x64 — one flutter
#                    build per platform. Omit for the full set: one
#                    --split-per-abi build per platform plus one combined
#                    universal build.
#
# Callers guarantee cwd is the repository root and flutter/dart are on PATH.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

PLATFORMS=("$@")

# --- 1. app patches ---------------------------------------------------------
shopt -s nullglob
for patch in tool/patch_*.dart; do
  echo "Applying patch: $patch"
  # Patches must be dependency-free scripts (plain `dart <file>`); if a future
  # patch needs packages, move it under app/ like a normal package script.
  dart "$patch"
done
shopt -u nullglob

# --- 2. release signing (only when CI secrets are present) ------------------
if [ -n "${APERTUREX_KEYSTORE_BASE64:-}" ]; then
  echo "$APERTUREX_KEYSTORE_BASE64" | base64 -d > app/android/app/upload-keystore.jks
  {
    echo "storeFile=upload-keystore.jks"
    echo "storePassword=${APERTUREX_KEYSTORE_PASSWORD:?}"
    echo "keyAlias=${APERTUREX_KEY_ALIAS:?}"
    echo "keyPassword=${APERTUREX_KEY_PASSWORD:?}"
  } > app/android/key.properties
  echo "Release signing enabled (keystore from secrets)."
else
  echo "No keystore secrets — building unsigned (debug-signed) as on F-Droid."
fi

# --- 3. reproducible flutter build -----------------------------------------
export SOURCE_DATE_EPOCH=0
cd app

build_one() {
  flutter build apk --release \
    --obfuscate --split-debug-info=build/symbols "$@"
}

if [ "${#PLATFORMS[@]}" -gt 0 ]; then
  for platform in "${PLATFORMS[@]}"; do
    build_one --split-per-abi --target-platform="$platform"
  done
else
  build_one --split-per-abi --target-platform=android-arm
  build_one --split-per-abi --target-platform=android-arm64
  build_one --split-per-abi --target-platform=android-x64
  build_one
fi
