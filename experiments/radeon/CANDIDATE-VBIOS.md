# Candidate Radeon ROM and original initramfs hook received

Received Nov 6, 2026. **Do not flash ROM to hardware.** The user supplied:

- `radeon-x1600-vbios.bin`: 65,536-byte ATI/AMD expansion ROM
  - SHA256: `3269f02c62c20cb06b95d83bdd8055951c9345755f8d8d5c95cc9e0bed42a63c`
  - Signature: `55 aa`
  - Expansion ROM length header: 125 × 512 = 64,000 bytes
  - Sum of those 64,000 bytes modulo 256 = 0
  - Sum of the complete 65,536-byte file modulo 256 = 0
  - `PCIR` pointer: `0x240`, vendor/device `1002:71c5`, code type 0 (x86)
  - BIOS header start: `0x21c`; `ATOM` at header+4
- `initramfs-radeon-script`: original hook copied the ROM into
  `/usr/lib/firmware/radeon` inside initramfs and into an extra `/radeon`
  location. It used unquoted variables and marked the firmware executable.

The ROM passes structural checks but its **provenance, Apple LCD panel and memory timings remain unverified**. The user-supplied ROM is not committed to GitHub because redistribution rights are not established; the checksum is recorded so the user can supply exactly these bytes to the experimental build.

Use the cleaner `initramfs-hook` for Debian 12. It copies firmware as read-only data to `/lib/firmware/radeon/vbios.bin` early in boot, preserving the exact `request_firmware("radeon/vbios.bin")` path. Installing the ROM alone into Alpha 1 will not fix acceleration: the kernel must have the custom fallback compiled into it and initramfs rebuilt for that **same** kernel.

The modified `radeon_bios.c` fallback still requires actual Linux 6.1 source compatibility checks, compiler testing, a separate experimental kernel and a boot menu entry that doesn't overwrite Alpha 1's safe kernel.
