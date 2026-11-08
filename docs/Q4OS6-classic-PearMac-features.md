# PearMac classic hardware and media restoration — Q4OS 6

**Target:** Late-2006 white Intel iMac5,1 running installed Q4OS 6 / Debian 13 Trixie with the verified `pearmac-mesa-r300-dri2` system-wide OpenGL compatibility package.

The old Debian 12 PearMac image used to be the vehicle for a much broader Mac-experience feature set. After confirming Q4OS live and installed operation, preserve that **feature plan** while treating Q4OS as the new **operating-system foundation**. Old custom kernel work is not needed for these ordinary userspace add-ons.

## Intended feature parity

| Subsystem | PearMac goal | Debian 13 implementation | Current evidence |
| --- | --- | --- | --- |
| Apple Remote / IR | Original six-button controls and extended browser, media, presentation mappings | Discover the exact `/dev/input/event*` receiver via `evtest`/`/proc/bus/input/devices`. Use `inputlirc` and/or direct event mapping; integrate `playerctl`, `xdotool`. Front Row-like menu to follow. | **Planned**; real receiver not identified yet |
| RetroArch | Retro gaming including owned PS1 dumps, optional wired Xbox 360 controller or wireless receiver | `retroarch`, `joystick`, `jstest-gtk`; RetroArch cores installed only after verifying which Debian cores are available and choosing compatible render backend | **Installer committed**; cores/controllers not verified |
| iPod | iPod classic/mini/nano USB mass-storage music management, backups, safe eject; FireWire models when supported | Strawberry + `libgpod4t64`; `lsblk`, file manager, `udisksctl`. Do not overwrite iPod databases or format without backups. | **Installer committed**; actual model not tested |
| iPod Touch / older iOS | Detect and browse supported AFC services, with varying compatibility depending on iOS model/version | `usbmuxd`, `libimobiledevice-utils`, `ifuse` | **Installer committed**; model-dependent, not iTunes-equivalent sync |
| FireWire 400 | FireWire storage, Zip 250, DV capture, and compatible iPod storage | In-kernel `firewire_ohci`, `firewire_core`, `firewire_sbp2` where available. `dvgrab` and `libraw1394-tools` where packaged. | **Installer committed**; check actual card/device |
| Built-in Apple hardware | iSight, eject, Apple SMC/fan monitoring, sound/Bluetooth, brightness | `v4l-utils`, `eject`, `lm-sensors` and hardware-specific probing; avoid unsafe fan PWM overrides and invasive boot-parameter changes | **Diagnostics available**, not all devices verified |
| Front Row / PearTunes | Sofa-style launcher for music, video, DVDs and browser; Apple Remote modes | Small Trinity/X11 UI/script later, after the actual remote's event codes are known; Strawberry for music, media player and browser for video | **Not yet implemented** |

## Install the userspace prerequisites

Use the checked-in [script](../scripts/install-legacy-features.sh). On the iMac, download/clone the repository (private repository requires access) then:

```bash
cd ~/PearMac-Live
bash scripts/install-legacy-features.sh audit     # read-only inventory
bash scripts/install-legacy-features.sh core      # install Debian packages
```

You can install smaller groups individually with `gaming`, `ipod`, `remote`, `firewire` and `hardware` to reduce dependencies.

The script checks availability in enabled APT sources and reports unavailable packages instead of enabling unstable third-party repositories. It does **not** change GRUB, partitions, the Mesa fix, USB device firmware, remote mappings, data on attached iPods, udev rules, or automatic kernel-module loads.

The hardware audit is intentionally read-only; it prints the detected GPU, FireWire controller, USB devices, input devices, storage devices, camera, available kernel modules and OpenGL renderer. Use that output to identify the actual Apple Remote input receiver and FireWire devices before enabling any persistent custom daemons.

## Apple Remote details

Original intended behavior:

- **Media:** play/pause, track forward/back, volume up/down; Menu opens Front Row-like launcher.
- **Browser:** play/pause online video where media keys are exposed to MPRIS/playerctl; fallback to a configurable keyboard binding (e.g. space) only after observing actual browser behavior.
- **Presentation:** keyboard slide navigation.
- **Front Row:** remote navigation in an on-screen launcher.

Avoid grabbing an arbitrary `event*` device or assigning global key handlers: doing that might hijack the keyboard or change unrelated USB devices. The input source and the receiver's reported keys must first be verified.

Useful tests:

```bash
cat /proc/bus/input/devices
lsusb
sudo evtest
```

Choose the **Apple IR receiver** by its printed device name, press each original remote button, and record the observed event codes. `evtest` is a temporary diagnostic tool; stop it with Ctrl+C. Also check whether the kernel's `appleir` or `hid_appleir` driver exposes an input device on this machine. Only then implement and enable PearRemote's remappings and user-session service.

## RetroArch considerations

The Radeon X1600 supports OpenGL 2.1 with the PearMac DRI2 package. A core requiring OpenGL 3+, GLES3, Vulkan or other modern extensions will not become supported just because GLX acceleration works. Keep the **GL** or software backend appropriate to the emulator/core and avoid experimental global Mesa environment settings. PS1 game images must be used in compatible formats; disk/chd/m3u setup may vary by core. Xbox 360 wired and wireless USB-receiver support must be verified per-controller.

## Classic iPod and FireWire considerations

- Strawberry in Debian 13 links with `libgpod4t64` for older iPod libraries. **gtkpod is not packaged in Debian 13 Trixie**, so don't assume the older PearMac plan's gtkpod command will work.
- Standard classic iPods may appear as removable storage; don't initialize, reformat, repair, or overwrite their media database on first connection. Make a complete backup first. Test mounting and listing before enabling write/sync.
- Some older FireWire iPods and storage devices expose mass-storage via the SBP-2 stack. The actual controller and peripheral must support it; no guarantee of universal FireWire accessory compatibility.
- FireWire digital video can be captured with `dvgrab`; tests require a real camera. Zip 250 requires correct disk/media, connected drive, and kernel detection. Treat historic media as read-only initially if data matters.
- iPod Touch and modern iPhones use other protocols and cannot be assumed to offer classic iPod sync through libgpod. `ifuse`/libimobiledevice may provide limited file access only.

## Quick hardware checks

```bash
bash scripts/install-legacy-features.sh audit
sudo evtest
lsmod | grep -E 'firewire|sbp2|ohci'
ls -la /sys/bus/firewire/devices/
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
ls /dev/video* 2>/dev/null
glxinfo -B | grep -E 'Device:|Accelerated:|OpenGL renderer'
```

Never `modprobe` randomly or change graphics kernel options during this feature restoration: the Radeon workaround is stable after reboot.

## Next development steps

1. Run the **audit** on the installed iMac and record the actual IR, FireWire, SMC, camera and controller IDs.
2. Establish Apple Remote key names/codes, then implement and package PearRemote with separate Media/Browser/Presentation/Front Row modes.
3. Test RetroArch with a lightweight compatible core and physical gamepad.
4. Test an actual iPod with safe backup/mount/eject, then build PearPod Manager around observed supported protocols.
5. Test actual FireWire storage and DV devices. Add non-destructive convenience utilities after confirming detection.
6. Integrate launcher/menu and dock after functionality is verified.

This is a **restoration roadmap plus a real userspace installer**, not a claim that all peripherals have been tested on the installed iMac.
