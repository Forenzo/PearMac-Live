# PearMac Live — iMac5,1 Radeon X1600 Linux project

**Current recommended reference: Q4OS 6 Andromeda (Debian 13 / Trinity) live DVD, BIOS boot + Mesa 25 R300 legacy DRI2 GLX fix.**

The white Intel iMac5,1 (late 2006, 32-bit Apple EFI / 64-bit Core 2 Duo, ATI Mobility Radeon X1600 RV530) now has a **verified working Q4OS 6 live DVD**, native-display Radeon modesetting, accelerated Xorg EXA, functional Broadcom b43 Wi-Fi and **hardware OpenGL 2.1**, tested through a custom Mesa 25.0.7 userspace GLX library.

**START HERE:** [Full reproduction and troubleshooting guide](docs/Q4OS6-iMac51-Radeon-X1600-working-guide.md).

**Important limits:** The Mesa fix was verified with `LD_LIBRARY_PATH` on `glxinfo -B`, **not** installed system-wide. Chromium launched but logged ANGLE/GLES3 GPU initialization failures; browser GPU acceleration is unverified. The permanent internal-disk installation was **not yet complete or confirmed** at documentation time; preserve Lion and take backups before touching the hybrid GPT/MBR.

## Reproduce the verified Mesa acceleration

The separate, manually triggered [Build Mesa 25 R300 legacy DRI2 workflow](.github/workflows/build-mesa-dri2.yml) uses a Debian 13 container and builds Mesa 25.0.7 with `-Dlegacy-x11=dri2`. Successful [run #2](https://github.com/Forenzo/PearMac-Live/actions/runs/42478406578) produced `PearMac-Mesa25-R300-Legacy-DRI2-TEST`. Artifacts expire; rerun the workflow.

On a Q4OS 6 live system, unpack the artifact to `~/mesa-test` and run:

```bash
MESA_LIB="$HOME/mesa-test/pearmac-mesa-dri2/lib/x86_64-linux-gnu"
LD_LIBRARY_PATH="$MESA_LIB" LIBGL_DRI3_DISABLE=1 glxinfo -B
```

Observed `OpenGL renderer string: ATI RV530`, `Accelerated: yes`, `OpenGL version string: 2.1 Mesa 25.0.7`. Do **not** overwrite system Mesa files just to reproduce this test.

## Experimental system-wide GLX integration (new)

A reversible Debian package build has been added to the same Mesa GitHub Actions workflow: `PearMac-Radeon-Systemwide-DEB-EXPERIMENTAL`. It places a legacy DRI2-capable Mesa GLX vendor library in a separate `/opt` directory, with its matching Gallium library private; it does **not** overwrite Debian's system Mesa files. Installation changes GLX library resolution globally, so proceed only after the new CI build passes and keep a text-console/live-DVD recovery option.

**[System-wide Debian package: installation, testing and rollback](docs/Radeon-GLX-systemwide-deb.md)**

**Verified 8 November 2026:** build #4 passed CI installation and rollback checks, and the package was installed on the actual iMac running Q4OS. An unwrapped `env -u LD_LIBRARY_PATH glxinfo -B` reports `ATI RV530` and `Accelerated: yes`. After-reboot behavior, Chromium GPU acceleration, and the macOS Lion boot path are not yet verified.

## PearMac classic experience on Q4OS 6

The previous PearMac feature plan is being restored **on top of the installed, hardware-accelerated Q4OS system**: original Apple Remote/PearRemote, RetroArch and gamepad support, classic iPod music management/PearPod, FireWire 400 storage and DV, Apple hardware utilities and Front Row-style media UI.

- [Feature restoration guide and status](docs/Q4OS6-classic-PearMac-features.md)
- [Debian 13 userspace prerequisites and hardware-audit script](scripts/install-legacy-features.sh)

On a checked-out repository, run `bash scripts/install-legacy-features.sh audit` to identify the actual devices, or `bash scripts/install-legacy-features.sh core` to install the available Debian 13 prerequisite packages. **Hardware-specific remapping/sync functions remain pending until verified; the installer never reformats media or changes the Radeon/boot configuration.**

## Earlier Debian 12 PearMac experiments (historical)

The previous Debian 12.0.0 XFCE live USB image/kernel `6.1.190-pearmac-radeon` needed `nomodeset`/safe graphics to reach the desktop. Wi-Fi was eventually fixed, but normal Radeon modesetting failed to display. Those experiments remain in the repository for historical reference and may still be useful, but they **are not the recommended or proven Radeon-accelerated solution**.

The original [Build PearMac live USB](.github/workflows/build.yml), Wi-Fi rescue and older ISO workflows have been **left unchanged** to preserve reproducibility; new development should start from the working Debian 13/Q4OS findings.

See the **full field guide** for hardware IDs, optical boot specifics, GPU diagnostics, exact Mesa flags, GitHub Actions failure/fix, Chromium caveat, and the pending Lion-preserving installation layout.
