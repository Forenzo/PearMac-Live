# PearMac YouTube Lounge (Q4OS 6 / Trinity)

**Status:** basic launcher committed; Apple IR receiver/button mapping and a custom Front Row-like home screen are **not yet implemented or tested** on the iMac.

## Aim

Use the **existing LibreWolf profile**, retaining YouTube login, subscriptions, comments, recommendations, uBlock Origin, your `layers.acceleration.force-enabled` setting, and the **Lightweight YouTube** extension. Provide big, readable, living-room browsing without removing YouTube's discovery features.

## Install the launcher

From an existing clone of PearMac-Live:

```bash
cd ~/PearMac-Live
git pull
bash scripts/pearmac-youtube.sh
```

Or download [the script](../scripts/pearmac-youtube.sh) as a file from the repository and run it with Bash.

**First run:** install Lightweight YouTube in LibreWolf's usual profile and confirm YouTube's mobile layout appears. Do not use Private Browsing or a separate temporary profile if you want to retain your login and extension.

By default the launcher opens a **normal** browser window. Press **F11** to enter fullscreen; press **F11** again to leave. This is recommended while we work out the remote's actual input events. You can adjust zoom inside LibreWolf using **Ctrl++ / Ctrl+- / Ctrl+0**. The launcher does not force a potentially dangerous global graphics setting.

Optional appliance mode:

```bash
bash scripts/pearmac-youtube.sh kiosk
```

Kiosk mode removes the usual browser toolbar and is intended for fixed displays. **F11 does not exit kiosk mode**; use **Alt+F4** to close its window. Do not switch to kiosk mode until there's a known keyboard/remote exit method.

## Trinity menu launcher

A per-user desktop launcher (create in `~/.local/share/applications/pearmac-youtube.desktop`) may point to the script. The `Exec` field must use the actual installed path; `~` is not expanded in that field. Example if repo was cloned in your home directory at `/home/mitsu/PearMac-Live`:

```ini
[Desktop Entry]
Type=Application
Name=PearMac YouTube Lounge
Comment=Open the lightweight YouTube interface in LibreWolf
Exec=/usr/bin/bash /home/mitsu/PearMac-Live/scripts/pearmac-youtube.sh
Terminal=false
Categories=AudioVideo;Video;
Icon=web-browser
```

Change `/home/mitsu` if your username differs.

## Apple Remote: identify before assigning buttons

Modern Linux has the **`hid_appleir`** driver for the original Apple IR receiver. Do not assume the iMac's receiver works or has a particular `/dev/input/eventX` number until tested.

```bash
lsusb | grep -Ei 'apple|ir|05ac'
grep -A6 -B2 -i 'ir receiver' /proc/bus/input/devices
lsmod | grep -E 'hid_appleir|appleir'
sudo apt install evtest xdotool playerctl
sudo evtest
```

In the `evtest` selection menu, select **only the named Apple IR receiver**, press Up, Down, Left, Right, Play/Pause, and Menu, and record each `KEY_*` event. Exit with Ctrl+C.

We can then build a **per-session remote-controlled navigation layer** around those confirmed events, with Menu launching/exiting the lounge, Play/Pause selecting/controlling media, and directional buttons navigating focus targets. On YouTube, DOM element/tab ordering can change, so a good implementation needs a stable focus-navigation strategy and a visible on-screen focus indicator—not just blindly sending Tab keys or mapping arrows to mouse movement.

Avoid installing unverified root-level input remappers, blacklisting `hid_appleir`, changing boot options or hard-coding `/dev/input/event*` numbers during discovery.

## Later Front Row-style screen

Plan a standalone large-button Trinity launcher with YouTube, music (Strawberry), DVDs, RetroArch, iPod tools and an Exit button. That custom UI is **not yet implemented**, and the Apple Remote input events determine the best integration.

## Sources

- Firefox kiosk mode and limitations: https://firefox-source-docs.mozilla.org/browser/components/enterprisepolicies/docs/index.html
- Firefox CLI parameters: https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html
- Linux Apple IR driver: https://github.com/torvalds/linux/blob/master/drivers/hid/hid-appleir.c
