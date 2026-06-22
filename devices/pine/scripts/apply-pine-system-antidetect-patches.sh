#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BIONIC_DIR="${BIONIC_DIR:-}"
FRAMEWORKS_BASE_DIR="${FRAMEWORKS_BASE_DIR:-}"

usage() {
  cat <<'EOF'
usage:
  BIONIC_DIR=/path/to/bionic FRAMEWORKS_BASE_DIR=/path/to/frameworks/base \
    bash devices/pine/scripts/apply-pine-system-antidetect-patches.sh

Set only one variable to apply one patch set.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "$BIONIC_DIR" ] && [ -z "$FRAMEWORKS_BASE_DIR" ]; then
  usage >&2
  exit 2
fi

apply_patch_set() {
  local tree_dir="$1"
  local patch_file="$2"

  if [ ! -d "$tree_dir/.git" ]; then
    echo "missing git tree: $tree_dir" >&2
    exit 2
  fi
  if [ ! -f "$patch_file" ]; then
    echo "missing patch: $patch_file" >&2
    exit 2
  fi

  echo "apply $(basename "$patch_file") -> $tree_dir"
  git -C "$tree_dir" apply --check "$patch_file"
  git -C "$tree_dir" apply "$patch_file"
}

if [ -n "$BIONIC_DIR" ]; then
  apply_patch_set "$BIONIC_DIR" \
    "$ROOT_DIR/devices/pine/patches/bionic/android-12.0.0_r32/pine-bionic-linker-antidetect.patch"
fi

if [ -n "$FRAMEWORKS_BASE_DIR" ]; then
  apply_patch_set "$FRAMEWORKS_BASE_DIR" \
    "$ROOT_DIR/devices/pine/patches/frameworks-base/android-12.0.0_r32/pine-framework-antidetect.patch"
fi
