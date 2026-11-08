# System-wide Radeon X1600 DRI2 GLX integration for Q4OS 6

**Status (8 November 2026): VERIFIED on installed Q4OS 6 on the real iMac5,1.** GitHub Actions build #4 succeeded, including package installation/library selection/removal in CI. The user installed the .deb on the iMac and confirmed hardware GLX without LD_LIBRARY_PATH. Persistence after reboot and performance across applications remain to be verified.

This extension of the [verified field guide](Q4OS6-iMac51-Radeon-X1600-working-guide.md) lets all **GLX** programs resolve the custom DRI2-compatible Mesa vendor library automatically. It does **not** upgrade the GPU, provide hardware WebGL2/GLES3/Vulkan, or guarantee Chromium's GPU process works.

## Why not replace distro libraries directly?

Direct copies over `/usr/lib/x86_64-linux-gnu/libGLX_mesa.so.0` would be overwritten by APT and could break desktop startup. Debian's other Mesa components (EGL/GBM) also use Gallium. Our reduced Gallium build was compiled for a narrow R300 + software GLX use-case; globally replacing Gallium could break unrelated graphics clients.

The packaging builder [scripts/package-mesa-dri2.sh](../scripts/package-mesa-dri2.sh) instead:

- Installs `libGLX_mesa.so.0` into `/opt/pearmac-radeon/lib`, visible to the dynamic loader through `/etc/ld.so.conf.d/00-pearmac-radeon.conf`.
- Installs the matching `libgallium-25.0.7.so` in **`/opt/pearmac-radeon/private`**, not in the global loader path; sets `$ORIGIN/../private` RUNPATH on the custom GLX library.
- Uses `ldconfig` during installation/removal to activate or remove the override, without deleting the existing Debian Mesa files.
- Pins dependencies to `libglx-mesa0 (= 25.0.7-2+deb13u1)` and `mesa-libgallium (= 25.0.7-2+deb13u1)`; a different installed Mesa version will **block installation**. Rebuild on any future Debian Mesa update.
- Is named `pearmac-mesa-r300-dri2` and can be removed with `sudo apt remove pearmac-mesa-r300-dri2`.

## Build and download

1. Open GitHub Actions: https://github.com/Forenzo/PearMac-Live/actions/workflows/build-mesa-dri2.yml
2. Run **Build Mesa 25 R300 legacy DRI2** on `main`.
3. The job recompiles Mesa, stages the proven per-process test archive, and builds **`PearMac-Radeon-Systemwide-DEB-EXPERIMENTAL`**.
4. CI then installs the .deb in a disposable **Debian 13** container, checks that `ldconfig` resolves the custom GLX library and its own Gallium private library, uninstalls the package, and checks that the custom cache entry disappears.
5. Only after **all** checks pass should the package artifact be used on the iMac. CI cannot validate real RV530 hardware graphics.

The original artifact `PearMac-Mesa25-R300-Legacy-DRI2-TEST` remains for fallback/per-app testing.

## Prepare the iMac

First keep the proven per-app test archive available on an external drive. Verify the **installed** Q4OS matches the build:

```bash
dpkg-query -W -f='${binary:Package} ${Version}\n' libglx-mesa0 mesa-libgallium
glxinfo -B
ls /sys/class/drm/ | head
```

Expected package versions: `25.0.7-2+deb13u1` for both. If they differ, **stop**. Do not force dependencies or downgrade Mesa just to install this patch.

For a safe recovery route, know how to enter a text console with **Ctrl+Alt+F2** (or via the appropriate key combination on the attached keyboard) and retain the bootable Q4OS live DVD. Make a backup of important data before any system-wide graphics changes.

## Install the new package

After downloading the artifact, extract it (GitHub Actions artifacts are ZIPs) to e.g. `~/Downloads/pearmac-deb`.

```bash
mkdir -p ~/Downloads/pearmac-deb
cd ~/Downloads/pearmac-deb
unzip ~/Downloads/PearMac-Radeon-Systemwide-DEB-EXPERIMENTAL.zip
ls -l *.deb
sudo apt install ./pearmac-mesa-r300-dri2_*.deb
```

This changes **system-wide GLX library resolution**, so do it from a terminal and close any unnecessary applications first. It does not reconfigure Xorg or the Radeon kernel module.

Verify in a **new** terminal **without the old wrapper or `LD_LIBRARY_PATH`**:

```bash
ldconfig -p | grep libGLX_mesa.so.0
env -u LD_LIBRARY_PATH glxinfo -B
```

Expected `ldconfig` path contains `/opt/pearmac-radeon/lib`, and `glxinfo` reports `ATI RV530`, `Accelerated: yes`. If hardware rendering fails, compare with:

```bash
env -u LD_LIBRARY_PATH LIBGL_DRI3_DISABLE=1 glxinfo -B
```

If only the explicit DRI3-disabled command works, **do not force global settings blindly**; diagnose the remaining client selection differences first. You can continue per-app testing with `~/mesa-test/run-radeon.sh`.

## Roll back

If programs misbehave but you can use a terminal:

```bash
sudo apt remove pearmac-mesa-r300-dri2
sudo ldconfig
ldconfig -p | grep libGLX_mesa.so.0
```

If the GUI is unstable, use a text TTY (Ctrl+Alt+F2), sign in and run the same commands, then reboot if needed. If you cannot reach a TTY, boot the Q4OS live DVD, mount the installed root filesystem, disable the custom `00-pearmac-radeon.conf` loader entry **on that installed root** and repair/uninstall using a chroot. The distro's Mesa files remain intact.

Do not apply this AMD/R300-specific package to other computers or Mesa versions, and do not overwrite system `libgallium` files.

## Evidence and outstanding work

- **Verified** (live environment): Xorg KMS/EXA, standalone EGL r300, GLX hardware acceleration when overriding libraries per-process.
- **Verified** (prior CI): Debian Mesa 25.0.7 `-Dlegacy-x11=dri2` builds and uploads a per-app test archive.
- **Pending**: new system-wide package build + CI install/remove verification.
- **Pending**: actual Q4OS installed-machine GLX test **without** environment override and verification after reboot.
- **Not verified**: Chromium ANGLE GPU compositing, WebGL2, Video Decode, modern OpenGL.

## Confirmed installed-hardware success (8 November 2026)

- Host: Q4OS 6 on the white iMac5,1; login shown as `mitsu@MITSUKAWA`.
- Package: `pearmac-mesa-r300-dri2_25.0.7-2+deb13u1.pearmac1_amd64.deb`.
- Installed through `sudo apt install ./pearmac-mesa-r300-dri2_*.deb`; APT completed unpacking and setup successfully.
- The **unwrapped**, global-library test `env -u LD_LIBRARY_PATH glxinfo -B` produced:

```text
direct rendering: Yes
Vendor: Mesa (0x1002)
Device: ATI RV530 (0x71c5)
Version: 25.0.7
Accelerated: yes
Video memory: 128MB
OpenGL renderer string: ATI RV530
OpenGL version string: 2.1 Mesa 25.0.7
OpenGL shading language version string: 1.20
OpenGL ES profile version string: OpenGL ES 2.0 Mesa 25.0.7
```

This confirms **system-wide GLX library selection and R300 acceleration on installed Q4OS**, not just the earlier live-DVD test. Still to verify: after-reboot persistence, whether macOS Lion boots normally, Chromium GPU acceleration (ANGLE/GLES3 errors were observed earlier), and effects of future Mesa updates. Keep package rollback commands available.

Successful CI run: https://github.com/Forenzo/PearMac-Live/actions/runs/42521826824

## Post-reboot persistence verification (8 November 2026)

The user restarted the installed Q4OS system and ran the unwrapped command:

```bash
glxinfo -B | grep -E 'Device:|Accelerated:|OpenGL renderer'
```

Observed output:

```text
    Device: ATI RV530 (0x71c5)
    Accelerated: yes
OpenGL renderer string: ATI RV530
```

**Confirmed:** the system-wide `pearmac-mesa-r300-dri2` GLX override persists across reboot and selects hardware-accelerated R300 rendering automatically on the installed iMac5,1. This does not establish Chromium GPU acceleration or verify booting the remaining macOS Lion installation.
