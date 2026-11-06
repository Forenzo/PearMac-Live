#!/usr/bin/env bash
# Fail closed: prepare only a reviewed source patch and matching candidate VBIOS.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH="${1:-}"
ROM="${2:-}"
if [[ -z "$PATCH" || -z "$ROM" ]]; then
  echo "Usage: bash experiments/radeon/check-inputs.sh REVIEWED_KERNEL_PATCH.patch CANDIDATE_VBIOS.rom" >&2
  echo "This does not apply a patch or build a boot image." >&2
  exit 2
fi
test -f "$PATCH" && test -s "$PATCH" || { echo "Patch missing/empty"; exit 1; }
test -f "$ROM" && test -s "$ROM" || { echo "VBIOS missing/empty"; exit 1; }
grep -q 'drivers/gpu/drm/radeon/radeon_bios.c' "$PATCH" || {
  echo "Patch does not mention radeon_bios.c. Manual review required." >&2; exit 1;
}
python3 "$ROOT/experiments/radeon/verify_vbios.py" "$ROM"
echo "Input format checks passed. No hardware compatibility is implied."
echo "DO NOT flash anything. Human review, kernel-version test build and SAFE boot entry required."
