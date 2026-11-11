# PearMac Front Row — Apple Remote (first test release)

**Status:** committed to the repository; needs testing on the actual Q4OS iMac.

Confirmed hardware: Apple USB IR receiver `05ac:8240` with `hid_appleir`. It has been observed as `/dev/input/event3`, but the program discovers it by USB ID rather than hard-coding an event number.

Tested events: `KEY_VOLUMEUP` (115) = up; `KEY_VOLUMEDOWN` (114) = down; `KEY_BACK` (158) = left; `KEY_FORWARD` (159) = right; `KEY_PLAYPAUSE` (164) = select; `KEY_MENU` (139) = show/hide menu. The device advertises `KEY_ENTER`, but a physical press has not been recorded.

## Install

Run as the regular Trinity user (not sudo):

```bash
cd ~/PearMac-Live
git pull
bash scripts/install-frontrow.sh install
python3 scripts/pearmac-frontrow.py
```

Once the controller starts, press Menu on the Apple Remote. The fullscreen menu contains YouTube, Twitch, Strawberry, RetroArch, Videos and Close Menu. Use up/down/left/right and Play to select. Press Menu again to hide. Keyboard arrows/Enter/Escape and mouse also work in the menu.

The YouTube and Twitch tiles launch your **existing LibreWolf profile** (not a temporary profile), preserving account, extensions, emotes, and Lightweight YouTube. YouTube points to `https://m.youtube.com/`. Other applications are only launched if present.

The installer adds `~/.config/autostart/pearmac-frontrow.desktop` and a user application menu item, not system configuration. It installs Debian packages `python3-evdev`, `python3-tk`, `xdotool`, `playerctl`, `pulseaudio-utils`. On next login, the controller should start automatically. Stop the foreground test with Ctrl+C to avoid running two instances.

Outside the menu: Menu reopens Front Row; up/down adjust system volume, left/right send arrow keys to the focused X11 application, Play/Pause asks MPRIS through playerctl. This is initial generic behavior, **not** a fully navigable browser or polished Twitch/YouTube controller. Playback and page focus should be tested.

## Access and removal

The program grabs **only** the Apple IR event device to prevent duplicate delivery to Trinity. It neither blacklists `hid_appleir` nor changes Mesa, Radeon, GRUB, power settings or global Xorg keymaps. It must run as the desktop user and needs read access to the Apple receiver. Check with `test -r /dev/input/event3 && echo accessible` and `getfacl /dev/input/event3`. If access is denied, do not run the GUI with sudo or blindly add the user to the `input` group; investigate session ACLs instead. Diagnostic mode: `python3 scripts/pearmac-frontrow.py --no-grab` (may produce duplicate remote reactions).

Remove per-user startup and menu integration with:

```bash
bash scripts/install-frontrow.sh uninstall
```

## Pending real-hardware checks

Confirm each of six buttons with the launched controller, verify input ACL and behavior across login, check default audio server volume handling, verify LibreWolf player control and decide better DOM-aware navigation for YouTube/Twitch, add DVD/iPod launchers later.
