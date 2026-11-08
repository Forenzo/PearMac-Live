# PearMac iMac5,1: working Q4OS 6 / Radeon X1600 field guide

**Test date:** 8 November 2026  
**Status:** LIVE DVD + Radeon 2D + per-process hardware OpenGL **verified on actual hardware**. Internal-disk installation was later **reported complete by the user**; post-install bootloader state, Lion preservation, and system-wide Radeon acceleration still require separate verification.  
**Test machine:** White Intel iMac5,1 (late 2006), Core 2 Duo (64-bit processor, 32-bit Apple EFI), ATI Mobility Radeon X1600 / RV530 / M56-P (PCI 1002:71c5, Apple subsystem 106b:0080), 128 MiB VRAM.

> This is the new recommended **working reference configuration** for this hardware. The older Debian 12 PearMac XFCE USB/kernel 6.1 remaster remains in Git history as an experiment, not the proven route. Do not assume a successful live DVD automatically implies an installed BIOS-mode GRUB boot.

## 1. What finally worked

- **Q4OS 6 Andromeda, 64-bit, Trinity live DVD**, based on **Debian 13 (Trixie)**.
- **Legacy BIOS-mode optical boot** on the 2006 Mac. The Q4OS ISO was prepared using the legacy-Mac BIOS/El Torito patch method from **mattgadient/isomacprog**, then burned as a DVD on a separate CachyOS PC. The optical drive in the iMac is MATSHITA DVD-R UJ-85J. Confirm actual boot mode with `test -d /sys/firmware/efi && echo EFI || echo BIOS`; our live session printed **BIOS**.
- Q4OS desktop: **native 1680×1050** display, Radeon KMS initialized; Xorg **EXA 2D acceleration**, **DRI2** and the **r300 AIGLX driver** initialized. Broadcom **b43** Wi-Fi worked. Desktop and browser were responsive; Twitch could be used, with occasional dropped video frames.
- **Hardware OpenGL 2.1 fixed via a userspace Mesa rebuild**, using `-Dlegacy-x11=dri2`. The stock Debian Mesa GLX client fell back to llvmpipe even though Xorg and standalone/surfaceless EGL could initialize RV530.

This is **not** a claim that Chromium's GPU process or modern WebGL2 work: Chromium displayed GPU initialization errors relating to GLES3 / ANGLE but opened and was usable with a fallback path.

## 2. The older PearMac experiment and why it was superseded

The earlier custom Debian 12.0.0 XFCE live-USB based PearMac builds used kernel `6.1.190-pearmac-radeon`. A safe boot with `radeon.modeset=0 radeon.pcie_gen2=0 nomodeset` reached XFCE and eventually obtained working b43 Wi-Fi. Normal accelerated Radeon startup produced a black display/no video; a custom VBIOS file was present but did not solve it. The XFCE/Plank dock duplication was a separate issue. These experiments were valid, but **do not represent the working graphics configuration**.

With Q4OS 6 on optical media, Radeon modesetting and 2D EXA initialized without that safe-mode workaround. We have **not isolated** whether the improved behavior is due to the kernel, Xorg, distro defaults, BIOS-mode DVD startup, or a combination.

## 3. Optical boot procedure / media caveats

1. Obtain the **Q4OS 6 Andromeda Trinity 64-bit live ISO** from the official Q4OS download source, and verify the downloaded ISO checksum against the publisher's reference if available.
2. On a separate computer with an optical writer, prepare the ISO for the early Intel Mac's **legacy BIOS-compatible optical boot**, using the **isomacprog** patch procedure documented at https://github.com/mattgadient/isomacprog (verify the tool's exact syntax and version). Our working optical media was patched before burning. Do not assume an unpatched ISO or a normal USB image follows the same boot path.
3. Burn the prepared image to a DVD with a tool that finalizes the medium and verifies the output. During this project an initial DVD-RW sequential write left an incomplete disc; using restricted-overwrite mode and then testing the disc on the iMac yielded a working boot. A byte-for-byte comparison of that burn did **not** fully match, so **physical boot and actual runtime tests**, not that comparison, were the proof of success.
4. Boot on the white iMac using its optical startup method and choose the 64-bit live session. The system must boot in legacy BIOS mode for this documented configuration. This is **not** proof that DVD/USB/network boots are interchangeable.

Do not reproduce the ISO by copying a screenshot or guessing isomacprog command flags; consult its repository instructions.

## 4. Successful live machine diagnostics

Hardware observed:

```text
GPU: RV530/M56-P ATI Mobility Radeon X1600
PCI vendor/device: 1002:71c5; Apple subsystem 106b:0080
VRAM: 128 MiB
Native panel: 1680x1050
OS: Q4OS 6 Andromeda / Debian 13 Trixie
Kernel: 6.12.111+deb13-amd64
Mesa package: 25.0.7-2+deb13u1
```

Useful **read-only** commands:

```bash
uname -r
lspci -nnk | grep -A4 -Ei 'VGA|display'
test -d /sys/firmware/efi && echo EFI || echo BIOS
xdpyinfo -queryExtensions | grep -Ei 'DRI2|DRI3|GLX'
grep -Ei 'RADEON.*(Acceleration enabled|Render acceleration|EXA)|AIGLX|DRI2|DRI3' /var/log/Xorg.0.log
ls -l /dev/dri/
glxinfo -B
xdriinfo
```

In our session, Xorg reported `DRI2 Setup complete`, `DRI driver: r300`, `EXA pixmaps in VRAM`, `Render acceleration enabled for R300/R400/R500`, `Acceleration enabled`, and `AIGLX: Loaded and initialized r300`. DRI3 was disabled/not advertised. The stock **client** `glxinfo -B` returned `llvmpipe` and `Accelerated: no`, and `xdriinfo` returned `swrast`. This distinction matters: working 2D Xorg acceleration does not guarantee hardware GLX for client applications.

With `GALLIUM_DRIVER=r300`, `eglinfo -B` **surfaceless/device** platforms successfully identified `ATI RV530` with OpenGL 2.1 and GLES 2.0, whereas X11 EGL initialization failed. This showed that R300 itself was available.

## 5. Root cause: modern Mesa GLX and legacy X11 DRI2

The Debian Mesa packaging `debian/rules` enabled direct GLX and the Gallium R300 driver but did not explicitly configure `legacy-x11`. The Mesa 25 default does not enable legacy X11 DRI2; the iMac's X server advertises DRI2, but no DRI3. A rebuild explicitly enabling **`-Dlegacy-x11=dri2`** solved the GLX hardware-rendering failure.

The compiled new GLX source included `src/glx/dri2_glx.c`. This is a **verified outcome on the test machine**, rather than a general claim about every X1600 or every Debian configuration.

## 6. Exact GitHub Actions build (reproducible source)

Repository: https://github.com/Forenzo/PearMac-Live  
Workflow: `.github/workflows/build-mesa-dri2.yml`  
Successful run #2 (8 Nov 2026): https://github.com/Forenzo/PearMac-Live/actions/runs/42478406578  
Result artifact: `PearMac-Mesa25-R300-Legacy-DRI2-TEST` (approximately 7 MB ZIP); GitHub artifacts expire, so rerun the workflow to reproduce them.

The workflow uses `ubuntu-24.04` GitHub-hosted x86-64 runner **inside a `debian:trixie` container**. It installs Mesa's Debian build dependencies, fetches `mesa=25.0.7-2+deb13u1` source with Debian patches, configures an isolated prefix, compiles with 4 jobs and stages binaries into an artifact (never installing into the runner's system libraries).

Key Meson arguments:

```text
--prefix=/opt/pearmac-mesa-dri2
--libdir=lib/x86_64-linux-gnu
--buildtype=release
-Dlegacy-x11=dri2
-Dglx=dri
-Dglx-direct=true
-Dglvnd=true
-Dgallium-drivers=r300,softpipe,llvmpipe
-Dvulkan-drivers=
-Dllvm=enabled
-Degl=disabled
-Dgbm=disabled
-Dgallium-va=disabled
-Dgallium-vdpau=disabled
-Dgallium-opencl=disabled
```

The first CI run failed **before compilation** because the extra `deb-src` repository specified Debian's keyring as `.gpg` when that container used `.pgp`. Changing `Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp` fixed APT; run #2 completed compilation and artifact upload.

## 7. Exact successful GPU test on Q4OS

Download the workflow artifact on Q4OS and unpack to `~/mesa-test`:

```bash
mkdir -p ~/mesa-test
cd ~/mesa-test
unzip ~/Downloads/PearMac-Mesa25-R300-Legacy-DRI2-TEST.zip
find ~/mesa-test -type f -name '*.so*'
```

This yielded `pearmac-mesa-dri2/lib/x86_64-linux-gnu/libGLX_mesa.so.0.0.0` and `libgallium-25.0.7.so`, plus additional symlink-like archive entries.

**The exact command which worked:**

```bash
MESA_LIB="$HOME/mesa-test/pearmac-mesa-dri2/lib/x86_64-linux-gnu"
LD_LIBRARY_PATH="$MESA_LIB" LIBGL_DRI3_DISABLE=1 glxinfo -B
```

**Observed output:**

```text
name of display: :0
direct rendering: Yes
Extended renderer info (GLX_MESA_query_renderer):
    Vendor: Mesa (0x1002)
    Device: ATI RV530 (0x71c5)
    Version: 25.0.7
    Accelerated: yes
    Video memory: 128MB
    Unified memory: no
    Preferred profile: compat (0x2)
    Max core profile version: 0.0
    Max compat profile version: 2.1
    Max GLES1 profile version: 1.1
    Max GLES[23] profile version: 2.0
OpenGL vendor string: Mesa
OpenGL renderer string: ATI RV530
OpenGL version string: 2.1 Mesa 25.0.7
OpenGL shading language version string: 1.20
OpenGL ES profile version string: OpenGL ES 2.0 Mesa 25.0.7
```

A convenient opt-in wrapper:

```bash
cat > ~/mesa-test/run-radeon.sh <<'EOF'
#!/bin/bash
MESA_LIB="$HOME/mesa-test/pearmac-mesa-dri2/lib/x86_64-linux-gnu"
export LD_LIBRARY_PATH="$MESA_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRI3_DISABLE=1
exec "$@"
EOF
chmod +x ~/mesa-test/run-radeon.sh
~/mesa-test/run-radeon.sh glxinfo -B
```

**Safety:** Do **not** overwrite `/usr/lib`, do not set `LD_LIBRARY_PATH` globally, and do not install these libraries system-wide until they are tested more comprehensively. These are **test** libraries built against the same Debian generation, not a signed distribution package.

## 8. Chromium caveat

Chromium installed via Q4OS's Add/Remove Programs could be launched with:

```bash
~/mesa-test/run-radeon.sh chromium --user-data-dir=/tmp/chromium-radeon-test
```

It **opened and was usable**, but logged `ANGLE Display::initialize error 12289`, `Could not create a backing OpenGL context`, `GLES3 is unsupported and ES version fallback is disabled`, and `Exiting GPU process due to errors during initialization`. Thus **Chromium GPU acceleration is NOT confirmed**; fallback is likely. `chrome://gpu` is the correct place to check actual graphics feature status. The successful standalone GLX test does not imply Chromium supports the RV530's limited OpenGL feature set.

## 9. Internal disk installation: planned, NOT verified

**Update (8 November 2026):** the user subsequently reported that Q4OS was fully installed and operating. The original partitioning details below document the planned layout; post-install GPT/hybrid-MBR details and successful macOS Lion boot remain unverified.

Disk: ST3250824AS Q, 250 GB decimal / 232.9 GiB, GPT **with hybrid MBR**. Q4OS live DVD booted **legacy BIOS**.

```text
GPT:
  /dev/sda1   200 MiB   FAT32 EFI system partition   PRESERVE
  /dev/sda2    44.7 GiB HFS+ Macintosh HD (Lion)     PRESERVE
  ~128.8 MiB unused gap between sda2 and sda3
  /dev/sda3   187.9 GiB NTFS BOOTCAMP (Windows 7)   REPLACE INTENDED

Hybrid MBR (before installation):
  #1  sectors 1..409639        type EE
  #2  sectors 409640..94159639 type AF (Apple HFS)
  #3  sectors 94423040..488396799 type 07 (Windows), ACTIVE
```

A manual Calamares **pending** configuration screenshot showed: EFI/HFS+ preserved; 8.61 MiB **unformatted BIOS boot** partition in the gap with `bios_grub` flag, about 120 MiB gap left; new **ext4 Q4OS root** at `/` covering 187.86 GiB formerly occupied by Boot Camp; GRUB target **MBR of /dev/sda**, not the CF-card reader `/dev/sdb`. The installer correctly displayed the GPT-on-BIOS advisory requesting an 8 MB unformatted `bios_grub` partition. This **does not guarantee** hybrid-MBR consistency or bootloader success.

A 15.3 GB exFAT CF card labelled `EOS_DIGITAL` was mounted as `/media/adminq/EOS_DIGITAL`. Before installation, the user successfully backed up GPT metadata using:

```bash
sudo sgdisk --backup=/media/adminq/EOS_DIGITAL/imac-gpt-backup.bin /dev/sda
```

They subsequently reported the MBR backup ready after being instructed to run:

```bash
sudo dd if=/dev/sda of=/media/adminq/EOS_DIGITAL/imac-original-mbr.bin bs=512 count=1 status=progress
sync
```

These **partition-table backups do not back up Lion files**. Actual data backups are required separately. Be cautious: tools rewriting the GPT may convert a hybrid MBR into a protective MBR; ordinary Calamares operations alone do not prove Apple boot compatibility. **Do not claim the internal install has succeeded until both Q4OS and Lion have been booted after installation.** A conventional GRUB BIOS-boot GPT design may require revisiting hybrid-MBR synchronization or another boot-management solution.

Read-only layout checks before changes:

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPE,LABEL,MOUNTPOINTS
sudo parted -l
sudo gdisk -l /dev/sda
sudo fdisk -l /dev/sda
test -d /sys/firmware/efi && echo EFI || echo BIOS
```

`gdisk` can inspect hybrid MBR read-only with `sudo gdisk /dev/sda` then `r`, `o`, `q` (quit **without writing**).

## 10. Future PearMac development

1. Treat the **working Q4OS 6 Debian 13 Trinity DVD + Radeon EXA** as the reference instead of relying on the old Debian 12 safe-mode-only USB experiment.
2. Preserve the independently working `build-mesa-dri2.yml` GitHub Actions workflow; it already reproduced the tested libraries.
3. After the internal installation is genuinely verified, record **both** Linux and macOS boot results, GPT/MBR post-install state and installer outcome.
4. Test Chromium, other GLX applications, stability, and graphics performance; only then consider controlled packaging or integration into a new live ISO. Avoid system-wide Mesa replacement until rollback is documented.
5. For public reproductions, point users to the workflow and explicit commands, not a short-lived artifact URL.

## References

- Q4OS: https://q4os.org/
- Debian Mesa source packages: https://sources.debian.org/src/mesa/
- Mesa build system: https://docs.mesa3d.org/meson.html
- Legacy Mac optical ISO patch project: https://github.com/mattgadient/isomacprog
- PearMac build workflow: https://github.com/Forenzo/PearMac-Live/blob/main/.github/workflows/build-mesa-dri2.yml

*Evidence level: live boot, EXA, b43 and corrected GLX success directly observed in session logs. Internal installation and permanent boot remain pending.*

## 11. Post-install update and system-wide GLX packaging (8 November 2026)

The user reported Q4OS fully installed and operating on the iMac and asked for permanent graphics integration. A reversible, isolated system-wide Debian package builder has been added to [the existing Mesa workflow](../.github/workflows/build-mesa-dri2.yml), with installation and rollback instructions in [Radeon-GLX-systemwide-deb.md](Radeon-GLX-systemwide-deb.md). **The new package is not yet verified by CI or on the installed iMac.**
