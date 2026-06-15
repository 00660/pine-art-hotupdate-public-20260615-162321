#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ART_DIR="${1:-${ANDROID_BUILD_TOP:-}/art}"
PATCH_FILE="$ROOT_DIR/devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch"

if [ -z "$ART_DIR" ] || [ ! -d "$ART_DIR" ]; then
  echo "usage: $0 <path-to-aosp-art-dir>" >&2
  echo "example: $0 \$ANDROID_BUILD_TOP/art" >&2
  exit 2
fi

if [ ! -f "$ART_DIR/runtime/class_linker.cc" ]; then
  echo "not an ART source directory: $ART_DIR" >&2
  exit 2
fi

if [ ! -f "$PATCH_FILE" ]; then
  echo "missing patch: $PATCH_FILE" >&2
  exit 1
fi

git -C "$ART_DIR" apply --check "$PATCH_FILE"
git -C "$ART_DIR" apply "$PATCH_FILE"
echo "applied pine android-12.0.0_r32 ART RegisterDexFile dump patch to $ART_DIR"
