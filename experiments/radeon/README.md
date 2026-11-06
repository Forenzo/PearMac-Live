# PearMac Radeon X1600 EFI acceleration — experimental branch

## Hardware proved on the actual iMac

- iMac5,1, Radeon X1600/RV530 `1002:71c5`, Apple subsystem `106b:0080`
- EFI32 boot via PearMac Alpha 1 works with `nomodeset radeon.modeset=0` (software Mesa `llvmpipe`)
- An unpatched `radeon.modeset=1` boot stopped updating the display; the kernel may or may not have continued running
- BCM4321 AirPort `14e4:4328` **connected to the user's hotspot** after installation of `firmware-b43-installer` and `b43-fwcutter`, alongside NetworkManager
- The next live image now **fails the build** if `b43/ucode11.fw` is absent. This was not present in the original Alpha 1.

## Radeon files recovered (November 6, 2026)

The user supplied:

1. Full modified historical `radeon_bios.c` (not a clean patch)
2. `radeon-x1600-vbios.bin` — 65,536 bytes, `55 aa`, `ATOM`, PCIR vendor/device `1002:71c5`; checksum of header-indicated ROM image passes; SHA-256 `3269f02c62c20cb06b95d83bdd8055951c9345755f8d8d5c95cc9e0bed42a63c`
3. `initramfs-radeon-script` — original initramfs hook

Detailed audit: `CANDIDATE-VBIOS.md` and `RECOVERED-SOURCE.md`.

The ROM is a structurally valid **candidate only**. The original Debian 12 iMac5,1 guide's author used a separately dumped ROM and *did not verify* this linked firmware. Apple LCD/panel, connector routing, and memory timings remain unverified.

**Do not flash the ROM.** It has not been committed to GitHub; copyright and redistribution permission aren't established.

## Linux driver patch

`apply_firmware_fallback.py` inserts only the new external-firmware fallback into the current Debian 6.1 `radeon_bios.c`, after the normal ROM methods have failed. It requests `radeon/vbios.bin`. Unlike overwriting the entire driver file, this preserves Debian's other bug/security fixes. Strict anchor checks prevent silent patching of an unrecognized kernel revision.

`initramfs-hook` copies a user-supplied local firmware file into `/lib/firmware/radeon/vbios.bin` **inside the custom kernel initramfs**. Installing it on Alpha 1 without a patched kernel does not fix graphics.

## Build on GitHub — first stage

Workflow: `.github/workflows/radeon-kernel.yml`

The workflow builds a full **separate Debian Bookworm Linux 6.1 kernel package** from Debian's current `linux-source-6.1` and the distro's amd64 kernel config. It first compiles the patched Radeon BIOS object in isolation, then uses `make bindeb-pkg`.

Artifact: `PearMac-Radeon-X1600-kernel-packages` includes an experimental `linux-image-*-pearmac-radeon_*_amd64.deb`, kernel config, generated patch, source-version metadata and checksums. This is **not yet a live USB image**; compilation success does not prove the ROM or display works.

Nothing modifies the pre-existing SAFE EFI32 kernel, Apple EFI firmware, or the iMac's internal partitions.

## Later: new, explicitly experimental live image

Once the kernel package passes compilation, integrate it into a *copy* of the live image root filesystem, install the user-supplied ROM only after checking the exact SHA-256, install and run the initramfs hook, then copy the new kernel and initrd to separate paths on the live USB. Add an `EXPERIMENTAL Radeon VBIOS` GRUB entry pointed at those distinct paths and keep `PearMac SAFE XFCE` as the first/default entry.

The working `b43/ucode11.fw` must be present in the squashfs before publishing. Keep NetworkManager and avoid installing/blacklisting with `broadcom-sta-dkms` because native b43 is now known to work.

## Upstream sources

- https://gist.github.com/minif/cd6c8f1ca8a5f54416dde3850ab2ce09
- https://wiki.debian.org/bcm43xx
- https://packages.debian.org/bookworm/firmware-b43-installer

**Status:** patched-kernel compilation launched. Actual hardware-accelerated graphics and the ROM's panel compatibility remain unproven.
