#!/usr/bin/env bash
# Compile isolated Radeon test kernel from Debian Bookworm Linux 6.1 sources.
# Does not touch the known-working EFI32 PearMac live image or installed OS.
set -Eeuo pipefail
cd /src
export DEBIAN_FRONTEND=noninteractive
export KBUILD_BUILD_USER=pearmac
export KBUILD_BUILD_HOST=github-actions
MODE="$1"
if [[ "$MODE" != "smoke" && "$MODE" != "packages" ]]; then
  echo "Usage: bash experiments/radeon/build-kernel.sh smoke|packages" >&2
  exit 2
fi
apt-get update
apt-get install -y --no-install-recommends  ca-certificates linux-image-amd64 linux-source-6.1  build-essential bc bison flex libelf-dev libssl-dev  libncurses-dev dwarves rsync kmod cpio fakeroot  dpkg-dev python3 xz-utils zstd git file
mkdir -p /src/.kernel-build /src/out/radeon-kernel
SRC_TARBALL=/usr/src/linux-source-6.1.tar.xz
test -s "$SRC_TARBALL" || { echo "Missing Debian Linux 6.1 source" >&2; exit 1; }
tar -xf "$SRC_TARBALL" -C /src/.kernel-build
KERNEL=/src/.kernel-build/linux-source-6.1
test -f "$KERNEL/drivers/gpu/drm/radeon/radeon_bios.c"
CONFIG="$(ls -1 /boot/config-*-amd64 | tail -1)"
test -s "$CONFIG" || { echo "No Debian amd64 kernel config" >&2; exit 1; }
cp "$CONFIG" "$KERNEL/.config"
cp "$KERNEL/drivers/gpu/drm/radeon/radeon_bios.c" /src/out/radeon-kernel/radeon_bios.c.original
python3 experiments/radeon/apply_firmware_fallback.py "$KERNEL"
diff -u /src/out/radeon-kernel/radeon_bios.c.original  "$KERNEL/drivers/gpu/drm/radeon/radeon_bios.c"  > /src/out/radeon-kernel/radeon-firmware-fallback.patch || [[ "$?" -eq 1 ]]
test -s /src/out/radeon-kernel/radeon-firmware-fallback.patch
cd "$KERNEL"
scripts/config --set-str LOCALVERSION "-pearmac-radeon"  --disable LOCALVERSION_AUTO  --set-str SYSTEM_TRUSTED_KEYS ""  --set-str SYSTEM_REVOCATION_KEYS ""  --disable DEBUG_INFO_BTF
make olddefconfig
grep -q '^CONFIG_DRM_RADEON=m$' .config || {
  echo 'Debian config has not enabled the Radeon DRM module as expected' >&2; exit 1;
}
KREL="$(make -s kernelrelease)"
case "$KREL" in *pearmac-radeon*) ;; *) echo "Unexpected kernel release: $KREL" >&2; exit 1;; esac
printf '%s\n' "$KREL" > /src/out/radeon-kernel/kernel-release.txt
printf '%s\n' "Debian source $(dpkg-query -W -f='${Version}' linux-source-6.1)" > /src/out/radeon-kernel/source-package.txt
printf '%s\n' "Base config $CONFIG" >> /src/out/radeon-kernel/source-package.txt
cp .config /src/out/radeon-kernel/kernel.config
echo "Building Radeon object for $KREL"
make -j"$(nproc)" prepare modules_prepare
make -j"$(nproc)" drivers/gpu/drm/radeon/radeon_bios.o
test -s drivers/gpu/drm/radeon/radeon_bios.o
echo 'Radeon object compiled successfully.'
if [[ "$MODE" == "packages" ]]; then
  echo 'Building separate experimental kernel Debian packages; safe kernel unchanged.'
  make -j"$(nproc)" bindeb-pkg KDEB_PKGVERSION=1
  shopt -s nullglob
  pkg=(/src/.kernel-build/linux-image-*pearmac-radeon*amd64.deb)
  (( ${#pkg[@]} > 0 )) || { echo 'No experimental kernel image .deb found' >&2; exit 1; }
  cp /src/.kernel-build/linux-image-*pearmac-radeon*amd64.deb /src/out/radeon-kernel/
  for deb in /src/out/radeon-kernel/*.deb; do dpkg-deb --info "$deb" | head -25; done
fi
(
 cd /src/out/radeon-kernel
 for f in radeon-firmware-fallback.patch kernel.config kernel-release.txt *.deb; do
   if [[ -f "$f" ]]; then sha256sum "$f"; fi
 done > SHA256SUMS
)
echo "Radeon kernel $MODE completed: $KREL"
