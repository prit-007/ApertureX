#!/usr/bin/env bash
# One-time release-signing setup for ApertureX (maintainers only).
#
#   1. Generates the Android release keystore (RSA-4096, 30 years).
#   2. Writes the credentials to app/android/key.properties (gitignored).
#   3. Registers them as GitHub Actions secrets on the `ci` environment, which
#      .github/workflows/ci.yml uses to sign the per-ABI release APKs.
#
# After running this, BACK UP (offline, encrypted):
#   * app/android/app/upload-keystore.jks  — the signing key itself
#   * app/android/key.properties           — its passwords
# Losing the keystore breaks updates for anyone who installed a GitHub-release
# APK. F-Droid re-signs with its own key and is unaffected.
#
# Usage: tool/ci/make_release_keystore.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

REPO=${APERTUREX_REPO:-prit-007/ApertureX}
KS=app/android/app/upload-keystore.jks
KP=app/android/key.properties
ALIAS=aperturex

if [ -f "$KS" ]; then
  echo "Keystore already exists at $KS — refusing to overwrite." >&2
  exit 1
fi
command -v keytool >/dev/null || { echo "keytool not found (install a JDK)." >&2; exit 1; }
command -v gh >/dev/null || { echo "gh CLI not found." >&2; exit 1; }
gh auth status >/dev/null || { echo "gh not authenticated — run: gh auth login" >&2; exit 1; }

randhex() {
  if command -v openssl >/dev/null; then
    openssl rand -hex 16
  else
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
  fi
}
STOREPASS=$(randhex)
KEYPASS=$(randhex)

mkdir -p "$(dirname "$KS")"
keytool -genkeypair -v \
  -keystore "$KS" -storetype PKCS12 \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10950 \
  -storepass "$STOREPASS" -keypass "$KEYPASS" \
  -dname "CN=ApertureX, O=Developer's Paradise, C=IN"

{
  echo "storeFile=upload-keystore.jks"
  echo "storePassword=$STOREPASS"
  echo "keyAlias=$ALIAS"
  echo "keyPassword=$KEYPASS"
} > "$KP"
chmod 600 "$KP"

# Create the `ci` environment (idempotent) and push the secrets into it.
gh api -X PUT "repos/$REPO/environments/ci" >/dev/null
base64 -w0 "$KS" 2>/dev/null | gh secret set APERTUREX_KEYSTORE_BASE64 --env ci --repo "$REPO" \
  || base64 "$KS" | tr -d '\n' | gh secret set APERTUREX_KEYSTORE_BASE64 --env ci --repo "$REPO"
printf '%s' "$STOREPASS" | gh secret set APERTUREX_KEYSTORE_PASSWORD --env ci --repo "$REPO"
printf '%s' "$KEYPASS"   | gh secret set APERTUREX_KEY_PASSWORD    --env ci --repo "$REPO"
printf '%s' "$ALIAS"     | gh secret set APERTUREX_KEY_ALIAS       --env ci --repo "$REPO"

cat <<EOF

Done.
  Keystore:   $KS      (BACK THIS UP — see header of this script)
  Passwords:  $KP      (gitignored; keep an offline copy)
  Secrets:    APERTUREX_KEYSTORE_* + APERTUREX_KEY_* set on the 'ci'
              environment of $REPO — CI signs releases from now on.
EOF
