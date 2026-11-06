#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
docker run --rm --privileged -e PEARMAC_ALPHA2_RADEON="${PEARMAC_ALPHA2_RADEON:-0}" -v "$PWD:/src" -w /src debian:bookworm bash -ceu '
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl xorriso squashfs-tools grub-common grub-efi-ia32-bin mtools gdisk python3 util-linux mount
bash scripts/build.sh
'

# Docker exit status is checked by set -e; also assert expected output on host.
test -s out/PearMac-iMac51-USB.img || { echo 'ERROR: Docker returned but host image missing' >&2; exit 1; }
if [[ "${PEARMAC_ALPHA2_RADEON:-0}" == 1 ]]; then
  test -s out/radeon-build-info.txt || { echo 'ERROR: Radeon integration did not run' >&2; exit 1; }
fi
ls -lh out/PearMac-iMac51-USB.img out/SHA256SUMS
