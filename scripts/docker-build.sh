#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
docker run --rm --privileged -v "$PWD:/src" -w /src debian:bookworm bash -ceu '
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl xorriso squashfs-tools grub-common grub-efi-ia32-bin mtools gdisk python3 util-linux mount
bash scripts/build.sh
'
