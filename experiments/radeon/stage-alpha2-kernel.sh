#!/usr/bin/env bash
# Stage a separately built Radeon kernel into PearMac's unpacked live root.
# This is called BEFORE the squashfs is recreated. Never modifies host disks.
set -Eeuo pipefail
: "${W:?Set W to PearMac work directory}"
: "${IMG_ROOT:?Set IMG_ROOT to unpacked live filesystem}"
ROOT=/src
ROM="$W/radeon-x1600-vbios.bin"
ARTIFACT_DIR="$W/radeon-kernel"
EXPECTED_SHA256=3269f02c62c20cb06b95d83bdd8055951c9345755f8d8d5c95cc9e0bed42a63c
[[ -s "$ROM" ]] || { echo "ERROR: missing Radeon VBIOS: $ROM" >&2; exit 1; }
[[ "$(sha256sum "$ROM" | cut -d' ' -f1)" == "$EXPECTED_SHA256" ]] || {
 echo 'ERROR: candidate VBIOS hash mismatch' >&2; exit 1;
}
python3 "$ROOT/experiments/radeon/verify_vbios.py" "$ROM"
shopt -s nullglob
KREL="$(cat "$ARTIFACT_DIR/kernel-release.txt")"
# The artifact also contains a huge linux-image-*-dbg package. Select the
# exact runtime image by its kernel release, never an ambiguous glob.
DEBS=("$ARTIFACT_DIR"/"linux-image-${KREL}"_*.deb)
[[ "${#DEBS[@]}" == 1 ]] || {
  printf 'ERROR: expected one runtime kernel image, found %s; candidates:\\n' "${#DEBS[@]}" >&2
  printf '%s\\n' "$ARTIFACT_DIR"/linux-image-*.deb >&2
  exit 1
}
PKG="${DEBS[0]}"
[[ "$KREL" == *pearmac-radeon* && "$KREL" != *"/"* ]] || { echo "ERROR: unsafe kernel release" >&2; exit 1; }
[[ "$(dpkg-deb -f "$PKG" Package)" == "linux-image-$KREL" ]] || { echo "ERROR: unexpected runtime kernel package name" >&2; exit 1; }
[[ -s "$ARTIFACT_DIR/SHA256SUMS" ]] && (cd "$ARTIFACT_DIR" && sha256sum --check SHA256SUMS)
mkdir -p "$IMG_ROOT/lib/firmware/radeon" "$IMG_ROOT/etc/initramfs-tools/hooks" "$IMG_ROOT/tmp"
install -m 0644 "$ROM" "$IMG_ROOT/lib/firmware/radeon/vbios.bin"
install -m 0755 "$ROOT/experiments/radeon/initramfs-hook" "$IMG_ROOT/etc/initramfs-tools/hooks/pearmac-radeon-vbios"
cp "$PKG" "$IMG_ROOT/tmp/pearmac-radeon-kernel.deb"
# Original live ISO kernel and initramfs remain untouched.
chroot "$IMG_ROOT" apt-get install -y --no-install-recommends initramfs-tools linux-base
chroot "$IMG_ROOT" apt-get install -y --no-install-recommends /tmp/pearmac-radeon-kernel.deb
chroot "$IMG_ROOT" update-initramfs -u -k "$KREL"
[[ -s "$IMG_ROOT/boot/vmlinuz-$KREL" ]] || { echo "ERROR: experimental kernel missing"; exit 1; }
[[ -s "$IMG_ROOT/boot/initrd.img-$KREL" ]] || { echo "ERROR: experimental initramfs missing"; exit 1; }
[[ -d "$IMG_ROOT/lib/modules/$KREL" ]] || { echo "ERROR: matching modules missing"; exit 1; }
if command -v lsinitramfs >/dev/null; then
  lsinitramfs "$IMG_ROOT/boot/initrd.img-$KREL" | grep -Eq '(^|/)firmware/radeon/vbios.bin$' || {
    echo "ERROR: candidate VBIOS was not included in initramfs"; exit 1;
  }
fi
cp "$IMG_ROOT/boot/vmlinuz-$KREL" "$W/live/vmlinuz-radeon"
cp "$IMG_ROOT/boot/initrd.img-$KREL" "$W/live/initrd-radeon.img"
rm -f "$IMG_ROOT/tmp/pearmac-radeon-kernel.deb"
printf 'Experimental Radeon kernel: %s\nCandidate VBIOS SHA256: %s\n' "$KREL" "$EXPECTED_SHA256" > /src/out/radeon-build-info.txt
echo "Staged experimental Radeon $KREL, original SAFE kernel untouched."
