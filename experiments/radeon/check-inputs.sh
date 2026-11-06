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
# Pin the exact 64 KiB candidate that was inspected from the user's upload.
# Matching hash confirms identity, NOT compatibility with this iMac's LCD.
EXPECTED_SHA256=3269f02c62c20cb06b95d83bdd8055951c9345755f8d8d5c95cc9e0bed42a63c
ACTUAL_SHA256="$(sha256sum "$ROM" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "VBIOS candidate checksum differs from reviewed user-supplied file" >&2
  exit 1
fi
echo "Input format checks passed. No hardware compatibility is implied."
echo "DO NOT flash anything. Human review, kernel-version test build and SAFE boot entry required."
