#!/usr/bin/env bash
# Vendor the prebuilt ONNX Runtime Android runtime used by the release `ai`
# build. Cargokit loads it with `ort/load-dynamic`, so the APK must contain one
# `libonnxruntime.so` per ABI and the build itself never downloads a runtime.
#
# Source: Maven Central, onnxruntime-android 1.24.3 (MIT, see THIRD_PARTY.md).
# 1.24.x is the first line with the Android 16 / ARM CPU-detection fixes; 1.22
# crashed natively during U²-NetP inference on a Motorola Android 16 device.
# Usage: tool/ci/vendor_ort_android.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

VERSION=1.24.3
AAR_SHA256=67397e4a970e75617f765d2015ceaf911917e1d822276cfb5792744e8085cbce
URL="https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/${VERSION}/onnxruntime-android-${VERSION}.aar"
DEST=app/android/app/src/main/jniLibs
ABIS=(arm64-v8a armeabi-v7a x86_64)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl --fail --location --silent --show-error "$URL" -o "$tmp/onnxruntime.aar"
printf '%s  %s\n' "$AAR_SHA256" "$tmp/onnxruntime.aar" | sha256sum -c -

for abi in "${ABIS[@]}"; do
  mkdir -p "$DEST/$abi"
  unzip -p "$tmp/onnxruntime.aar" "jni/$abi/libonnxruntime.so" \
    > "$DEST/$abi/libonnxruntime.so"
  test -s "$DEST/$abi/libonnxruntime.so"
  echo "vendored $DEST/$abi/libonnxruntime.so"
done
