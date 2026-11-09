# PearMac Live — iMac5,1 Radeon X1600 Linux project

**Recommended configuration: Q4OS 6 Andromeda (Debian 13 / Trinity), legacy BIOS boot, with the PearMac system-wide Mesa R300 DRI2 package.**

The late-2006 white Intel iMac5,1 (Core 2 Duo, 32-bit Apple EFI, ATI Mobility Radeon X1600 / RV530 with 128 MB VRAM) **boots installed Q4OS 6 and provides Radeon-accelerated OpenGL 2.1 across GLX applications**. The solution has been verified on the actual machine **after a reboot**, without any per-app launcher or special environment variables. Native 1680×1050 Radeon modesetting, Xorg EXA acceleration and Broadcom b43 Wi-Fi were also confirmed.

**[Full Q4OS/iMac reproduction guide](docs/Q4OS6-iMac51-Radeon-X1600-working-guide.md)** · **[System-wide Radeon Mesa installer and rollback](docs/Radeon-GLX-systemwide-deb.md)**

## Radeon graphics fix: verified and integrated

Debian Mesa 25.0.7 was rebuilt with `-Dlegacy-x11=dri2` because the iMac's Radeon X.Org driver advertises DRI2, while stock Mesa's GLX client fell back to software rendering. We **first tested the rebuilt libraries on the live DVD on a per-application basis** using `LD_LIBRARY_PATH`, confirming `ATI RV530` and `Accelerated: yes`. Once that succeeded, we packaged the same GLX implementation and matching Gallium library as an isolated, reversible **system-wide Debian package**.

The [Mesa DRI2 GitHub Actions workflow](.github/workflows/build-mesa-dri2.yml) builds both the historical test archive and the permanent package. **Successful [run #4](https://github.com/Forenzo/PearMac-Live/actions/runs/42521826824)** passed package installation, loader-selection and uninstall checks. The resulting package `pearmac-mesa-r300-dri2_25.0.7-2+deb13u1.pearmac1_amd64.deb` was then successfully installed on the iMac.

The package installs the custom `libGLX_mesa.so.0` under `/opt/pearmac-radeon/lib`, its matching Gallium implementation under `/opt/pearmac-radeon/private`, and an `ld.so.conf.d` entry. Debian-owned Mesa libraries are **not overwritten**. Removal via `sudo apt remove pearmac-mesa-r300-dri2` restores the normal loader configuration. **The package is tied to the matching Mesa 25.0.7-2+deb13u1 version; rebuild before migrating to another Mesa version.**

After a normal reboot, the user ran ordinary `glxinfo -B` without wrappers or overrides:

```text
Device: ATI RV530 (0x71c5)
Accelerated: yes
OpenGL renderer string: ATI RV530
```

**Result: system-wide R300 OpenGL 2.1 acceleration verified and persistent after reboot.** The per-app method was a temporary validation step, **not the required operating procedure**. This does **not** imply support for modern OpenGL, GLES3, Vulkan or Chromium's ANGLE GPU path; Chromium GPU compositing remains unverified. macOS Lion boot compatibility after repartitioning also remains unverified.

## PearMac classic experience on Q4OS 6

The previous PearMac feature plan is being restored **on top of the installed, hardware-accelerated Q4OS system**: original Apple Remote/PearRemote, RetroArch and gamepad support, classic iPod music management/PearPod, FireWire 400 storage and DV, Apple hardware utilities and Front Row-style media UI.

- [Feature restoration guide and status](docs/Q4OS6-classic-PearMac-features.md)
- [Debian 13 userspace prerequisites and hardware-audit script](scripts/install-legacy-features.sh)

On a checked-out repository, run `bash scripts/install-legacy-features.sh audit` to identify the actual devices, or `bash scripts/install-legacy-features.sh core` to install the available Debian 13 prerequisite packages. **Hardware-specific remapping/sync functions remain pending until verified; the installer never reformats media or changes the Radeon/boot configuration.**

## Earlier Debian 12 PearMac experiments (historical)

The previous Debian 12.0.0 XFCE live USB image/kernel `6.1.190-pearmac-radeon` needed `nomodeset`/safe graphics to reach the desktop. Wi-Fi was eventually fixed, but normal Radeon modesetting failed to display. Those experiments remain in the repository for historical reference and may still be useful, but they **are not the recommended or proven Radeon-accelerated solution**.

The original [Build PearMac live USB](.github/workflows/build.yml), Wi-Fi rescue and older ISO workflows have been **left unchanged** to preserve reproducibility; new development should start from the working Debian 13/Q4OS findings.

See the **full field guide** for hardware IDs, optical boot specifics, GPU diagnostics, exact Mesa flags, Chromium limitations, and the historical Lion-preserving installation plan (Lion boot remains unverified).
