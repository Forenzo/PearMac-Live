# Radeon X1600 VBIOS experiment (separate branch)

**Status: research and validation only. No patched kernel or known-good VBIOS is included yet.**

## Confirmed hardware and test results

- Intel iMac5,1 (late 2006), AMD/ATI RV530 Mobility Radeon X1600 `1002:71c5`, Apple subsystem `106b:0080`.
- Alpha 1 boots to XFCE with `nomodeset`, `glxinfo -B` reports `llvmpipe` software rendering.
- The original Radeon experimental boot enables modesetting, but its display stops updating near 3 seconds; no post-stall logs have yet been recovered. A frozen display is not conclusive proof of the kernel failure stage.
- BCM4321 `14e4:4328` works with b43 after installing `firmware-b43-installer`; preserve this fix separately.

## Upstream evidence

- Debian 12 EFI iMac5,1 report: https://gist.github.com/minif/cd6c8f1ca8a5f54416dde3850ab2ce09
- It describes a custom `drivers/gpu/drm/radeon/radeon_bios.c` patch, external VBIOS and initramfs hook, then successfully accelerated Radeon graphics.
- Its archived patched file and initramfs hook currently failed retrieval; the example third-party VBIOS file was also unreachable. The author expressly did not verify that shared VBIOS (they used their own dump). Thus no trustworthy patch binary/source pair is available for direct deployment yet.
- The guide's Linux kernel was 6.1.128; Alpha 1 uses Debian kernel 6.1.0-9-amd64. Kernel module/source/headers must match the eventual build.
- Do NOT simply substitute any online Radeon X1600 ROM or the Sony Windows ATI driver; model-specific display timings and image provenance matter.

## Current safety gates

1. Obtain original archived patch source and review its exact behavior and license; confirm compatibility with the kernel version we're building.
2. Obtain a legally supplied *matching* candidate VBIOS; check provenance, ROM format, `1002:71c5` PCIR ID, and checksum with `python3 experiments/radeon/verify_vbios.py candidate.rom`. A passing check does **not** establish safe panel timing or compatibility.
3. Build a separate kernel and initramfs **without overwriting the proven Alpha 1 pair**.
4. Add a new explicit *experimental* boot-menu entry only; the existing SAFE XFCE entry must remain first and default with `nomodeset`.
5. Never flash the GPU, alter Apple EFI firmware, repartition the internal disk, or disable CPU security mitigations.

## Next diagnostic

If the current image boots safe mode, collect `sudo lspci -nnk`, `cat /proc/cmdline`, and if feasible a captured experimental boot log (serial/network); don't repeatedly try a boot that freezes the display.

## ROM input

Do not commit firmware dumps into a public repository. This repository is private but still requires careful provenance and licensing. Candidate firmware is **not** automatically downloaded or trusted.
