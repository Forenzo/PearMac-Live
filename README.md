# PearMac Live

Private experimental Debian 12 XFCE live-USB image for the 2006 Intel iMac5,1 (64-bit Core 2 Duo, 32-bit Apple EFI, ATI Radeon X1600).

## Status
**Prototype only.** The EFI32-to-amd64 boot path, live image builder, and graphics modes have not yet been tested on the actual iMac. This is not a finished distribution.

## Build on GitHub
1. Open **Actions**.
2. Choose **Build PearMac live USB**.
3. Choose **Run workflow**.
4. Check the job log and, if successful, download the **PearMac-iMac51-USB-prototype** artifact.

The script downloads the exact Debian 12.0 XFCE ISO from the official Debian archive and verifies its SHA256 checksum before modifying the filesystem. It then repackages the live environment in a GPT/FAT32 USB disk image containing an EFI32 GRUB loader.

This first build has two boot choices: a conservative XFCE session (nomodeset) and an experimental Radeon modesetting session. It adds Plank but **does not yet have the complete PearOS/MacTahoe appearance or UKUI**. Those are planned once we have reliable live USB boot and diagnostics.

The source is a build recipe, not a prebuilt ISO. No Windows ATI binaries are injected; they are not Linux drivers. Building does not change the Mac's internal disk.

**USB caution:** writing the output image with a flashing tool will erase the **selected USB drive**. Verify the drive carefully before writing. Keep Lion and Windows 7 intact.

Source ISO: https://cdimage.debian.org/cdimage/archive/12.0.0-live/amd64/iso-hybrid/debian-live-12.0.0-amd64-xfce.iso
