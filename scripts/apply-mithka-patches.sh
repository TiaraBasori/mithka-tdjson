#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 TD_SOURCE" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TD_SOURCE="$1"
SERIES="$ROOT/patches/series"

if ! git -C "$TD_SOURCE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: TDLib checkout not found: $TD_SOURCE" >&2
  exit 1
fi
if [[ ! -f "$SERIES" ]]; then
  echo "error: Mithka patch series not found: $SERIES" >&2
  exit 1
fi

while IFS= read -r patch_name; do
  patch_name="${patch_name%$'\r'}"
  [[ -n "$patch_name" ]] || continue
  [[ "$patch_name" != \#* ]] || continue
  patch_file="$ROOT/patches/$patch_name"
  if [[ ! -f "$patch_file" ]]; then
    echo "error: patch listed in series is missing: $patch_file" >&2
    exit 1
  fi
  if git -C "$TD_SOURCE" apply --unidiff-zero --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "==> $patch_name already applied"
  elif git -C "$TD_SOURCE" apply --unidiff-zero --check "$patch_file"; then
    echo "==> Applying $patch_name directly"
    git -C "$TD_SOURCE" apply --unidiff-zero "$patch_file"
  elif git -C "$TD_SOURCE" apply --3way --check "$patch_file" >/dev/null 2>&1; then
    echo "==> Applying $patch_name with a three-way merge"
    git -C "$TD_SOURCE" apply --3way "$patch_file"
  else
    echo "==> Direct-apply diagnostics for $patch_name" >&2
    git -C "$TD_SOURCE" apply --unidiff-zero --check "$patch_file" >&2 || true
    echo "==> Three-way diagnostics for $patch_name" >&2
    git -C "$TD_SOURCE" apply --3way --check "$patch_file" >&2 || true
    echo "error: failed to apply $patch_name" >&2
    exit 1
  fi
done < "$SERIES"
