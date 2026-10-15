#!/usr/bin/env bash
# Shared prebuild for GitHub CI and the F-Droid metadata. Both callers guarantee:
#   * cwd is the repository root,
#   * `flutter`/`dart` are on PATH,
#   * PUB_CACHE points at a workspace-local pub cache (CI only).
#
# Usage: tool/ci/android_prebuild.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

flutter config --no-analytics
(cd app && flutter pub get --enforce-lockfile)

# Codegen hooks go here when generators land (riverpod/drift/freezed):
#   (cd app && dart run build_runner build --delete-conflicting-outputs)
