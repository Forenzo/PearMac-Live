#!/usr/bin/env bash
set -Eeuo pipefail
cd /src
mkdir -p .work out
W=/src/.work
ISO="$W/debian-live-12.0.0-amd64-xfce.iso"
BASE=https://cdimage.debian.org/cdimage/archive/12.0.0-live/amd64/iso-hybrid
curl -fL --retry 4 -o "$ISO" "$BASE/debian-live-12.0.0-amd64-xfce.iso"
curl -fL --retry 4 -o "$W/SHA256SUMS" "$BASE/SHA256SUMS"
(cd "$W" && grep 'debian-live-12.0.0-amd64-xfce.iso$' SHA256SUMS | sha256sum -c -)
mkdir -p "$W/live" "$W/root"
xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$W/live/filesystem.squashfs" -extract /live/vmlinuz "$W/live/vmlinuz" -extract /live/initrd.img "$W/live/initrd.img"
rm -f "$ISO"
unsquashfs -no-progress -d "$W/root" "$W/live/filesystem.squashfs"
rm -f "$W/live/filesystem.squashfs"
printf '%s\n' 'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' 'deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' 'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' > "$W/root/etc/apt/sources.list"
rm -f "$W/root/etc/apt/sources.list.d/"*.sources
cp /etc/resolv.conf "$W/root/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$W/root/usr/sbin/policy-rc.d"
chmod +x "$W/root/usr/sbin/policy-rc.d"
mount --bind /dev "$W/root/dev"
mount -t proc proc "$W/root/proc"
mount -t sysfs sysfs "$W/root/sys"
cleanup() { set +e; umount -l "$W/root/sys"; umount -l "$W/root/proc"; umount -l "$W/root/dev"; }
trap cleanup EXIT
export DEBIAN_FRONTEND=noninteractive
chroot "$W/root" apt-get update
# Native Linux hardware support: kernel handles audio, Ethernet, USB, SATA, FireWire, SMC.
# Firmware packages cover the GPU and possible AirPort/Bluetooth revisions.
chroot "$W/root" apt-get install -y --no-install-recommends \
 live-boot live-config plank xserver-xorg-video-radeon xserver-xorg-video-fbdev \
 firmware-amd-graphics firmware-brcm80211 firmware-realtek firmware-iwlwifi \
 firmware-atheros firmware-misc-nonfree \
 mesa-utils pciutils usbutils lshw ethtool iw wireless-tools \
 alsa-utils pavucontrol bluez rfkill lm-sensors \
 smartmontools hdparm evtest xinput v4l-utils
# Broadcom b43 firmware is extracted separately from vendor packages.
# Do not fail the whole ISO build if this optional downloader is unavailable.
if chroot "$W/root" apt-get install -y --no-install-recommends firmware-b43-installer; then
 echo 'b43 firmware installer succeeded'
else
 echo 'WARNING: optional b43 firmware installer unavailable; exact AirPort chipset needs checking'
 chroot "$W/root" apt-get -f install -y || true
fi
mkdir -p "$W/root/usr/local/bin"
cat > "$W/root/usr/local/bin/pearmac-hardware-report" <<'HWREPORT'
#!/bin/bash
set +e
OUT="${1:-$HOME/pearmac-hardware-report.txt}"
{
 date -u
 echo '=== SYSTEM ==='
 uname -a
 cat /proc/cmdline
 echo '=== PCI ==='
 lspci -nnk
 echo '=== USB ==='
 lsusb
 echo '=== NETWORK ==='
 ip link
 rfkill list
 echo '=== AUDIO ==='
 aplay -l
 echo '=== DISPLAY ==='
 xrandr --verbose
 glxinfo -B
 echo '=== STORAGE ==='
 lsblk -o NAME,TRAN,SIZE,MODEL,FSTYPE,MOUNTPOINTS
 echo '=== MAC SMC / THERMAL ==='
 lsmod | grep -E 'applesmc|radeon|b43|sky2|firewire|uvcvideo|snd|btusb'
 sensors
 echo '=== FIRMWARE / ERRORS ==='
 dmesg | grep -Ei 'firmware|radeon|drm|b43|bluetooth|applesmc|error' | tail -150
} > "$OUT" 2>&1
echo "Saved report: $OUT"
HWREPORT
chmod +x "$W/root/usr/local/bin/pearmac-hardware-report"
# Avoid copying a forced 'nomodeset' configuration into the operating system;
# that remains an explicit boot-menu choice.
mkdir -p "$W/root/etc/skel/.config/autostart"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=PearMac Dock' 'Exec=plank' 'OnlyShowIn=XFCE;' > "$W/root/etc/skel/.config/autostart/pearmac-dock.desktop"
chroot "$W/root" apt-get clean
rm -f "$W/root/usr/sbin/policy-rc.d"
cleanup
trap - EXIT
mksquashfs "$W/root" "$W/live/filesystem.squashfs" -comp xz -b 1M -noappend -no-progress
rm -rf "$W/root"
cat > "$W/grub.cfg" <<'GRUB'
set default=0
set timeout=20
insmod part_gpt
insmod fat
search --no-floppy --file --set=root /live/filesystem.squashfs
menuentry 'PearMac SAFE XFCE' {
 linux /live/vmlinuz boot=live components username=user hostname=pearmac nomodeset radeon.modeset=0
 initrd /live/initrd.img
}
menuentry 'PearMac Radeon experimental' {
 linux /live/vmlinuz boot=live components username=user hostname=pearmac radeon.modeset=1 radeon.pcie_gen2=0
 initrd /live/initrd.img
}
GRUB
grub-mkstandalone -O i386-efi -o "$W/BOOTIA32.EFI" --modules='part_gpt fat search search_fs_file linux normal configfile all_video efi_gop' "boot/grub/grub.cfg=$W/grub.cfg"
IMG=/src/out/PearMac-iMac51-USB.img
BYTES=$(du -cb "$W/live/"* "$W/BOOTIA32.EFI" | tail -1 | awk '{print $1}')
SIZE_MIB=$(( (BYTES + 600*1048576 + 1048575)/1048576 + 4 ))
truncate -s "$((SIZE_MIB*1048576))" "$IMG"
sgdisk --zap-all "$IMG"
sgdisk --new=1:2048:0 --typecode=1:EF00 --change-name=1:PEARMAC "$IMG"
START=$(sgdisk -i 1 "$IMG" | awk '/^First sector:/{print $3}')
SECTORS=$(sgdisk -i 1 "$IMG" | awk '/^Partition size:/{print $3}')
FAT="$IMG@@$((START*512))"
mformat -i "$FAT" -T "$SECTORS" -F -v PEARMAC ::
mmd -i "$FAT" ::/EFI ::/EFI/BOOT ::/live
mcopy -i "$FAT" "$W/BOOTIA32.EFI" ::/EFI/BOOT/BOOTIA32.EFI
for f in filesystem.squashfs vmlinuz initrd.img; do mcopy -i "$FAT" "$W/live/$f" "::/live/$f"; done
for f in /EFI/BOOT/BOOTIA32.EFI /live/filesystem.squashfs /live/vmlinuz /live/initrd.img; do mdir -i "$FAT" "::$f" >/dev/null; done
sha256sum "$IMG" > /src/out/SHA256SUMS
printf 'Unbooted prototype; Radeon acceleration not fixed.\n' > /src/out/build-info.txt
