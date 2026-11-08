#!/usr/bin/env bash
# PearMac classic hardware and media features for Q4OS 6 / Debian 13.
# Non-destructive: installs distribution packages, probes modules and prints
# next steps. No partition writes, no GRUB changes, no system Mesa changes.
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  echo "Run as the normal desktop user (the script uses sudo for apt)." >&2
  exit 1
fi

# Q4OS may expose its own release codename; check the Debian base instead.
if [[ ! -r /etc/debian_version ]] || [[ "$(cat /etc/debian_version)" != 13* ]]; then
  echo "This installer targets Debian 13 / Q4OS 6. Detected Debian base: $(cat /etc/debian_version 2>/dev/null || echo unknown)" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: bash scripts/install-legacy-features.sh OPTION

Options:
  core       Install retro gaming, media/iPod, remote diagnostics, FireWire
             Bluetooth stack and hardware utilities using Debian packages
  gaming     Install RetroArch and controller diagnostic tools
  ipod       Install Strawberry, libgpod, iPhone/iPod Touch USB utilities
  remote     Install playerctl, xdotool, evtest and inputlirc diagnostics
  firewire   Install FireWire/DV userspace tools (no forced module loads)
  hardware   Install camera, sensors and optical-disc utilities
  bluetooth  Install BlueZ + Blueman and match existing audio server
  audit      Read-only hardware and driver report (no packages installed)

No system-wide configuration, remote key remapping, storage reformatting,
device writes, or optical-disc burning is performed.
EOF
}

install_group() {
  local group="$1"; shift
  local available=() missing=()
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done
  if (("${#missing[@]}" > 0)); then
    printf '[%s] Not in enabled APT sources: %s\n' "$group" "${missing[*]}" >&2
  fi
  if (("${#available[@]}" > 0)); then
    printf '[%s] Installing Debian packages: %s\n' "$group" "${available[*]}"
    sudo apt-get install -y --no-install-recommends "${available[@]}"
  fi
}

audit() {
  echo '=== PearMac iMac5,1 hardware inventory (read-only) ==='
  date -Is
  uname -a
  lspci -nnk | grep -A3 -Ei 'VGA|display|firewire|1394|ethernet|network|audio' || true
  echo '--- USB ---'
  lsusb || true
  echo '--- Remote / input devices ---'
  grep -Ei 'Name=|Handlers=|Phys=' /proc/bus/input/devices || true
  echo '--- FireWire devices ---'
  ls -la /sys/bus/firewire/devices/ 2>/dev/null || true
  echo '--- FireWire kernel modules ---'
  lsmod | grep -E 'firewire|sbp2|ohci' || true
  echo '--- iPod / disks ---'
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS || true
  echo '--- Video devices ---'
  ls -l /dev/video* 2>/dev/null || true
  echo '--- Bluetooth controller / kernel support ---'
  if command -v rfkill >/dev/null 2>&1; then rfkill list bluetooth || true; fi
  if command -v bluetoothctl >/dev/null 2>&1; then bluetoothctl list || true; fi
  if command -v systemctl >/dev/null 2>&1; then systemctl is-active bluetooth || true; fi
  lsmod | grep -Ei 'bluetooth|btusb|bnep|hci_' || true
  echo '--- User sound server ---'
  if command -v pactl >/dev/null 2>&1; then pactl info | grep 'Server Name' || true; fi
  echo '--- Radeon OpenGL ---'
  if command -v glxinfo >/dev/null; then
    glxinfo -B | grep -E 'Device:|Accelerated:|OpenGL renderer|OpenGL version' || true
  fi
}

gaming=(retroarch joystick jstest-gtk)
ipod=(strawberry libgpod4t64 usbmuxd libimobiledevice-utils ifuse)
remote=(playerctl xdotool evtest inputlirc)
firewire=(dvgrab libraw1394-tools)
hardware=(lm-sensors v4l-utils eject)
bluetooth=(bluez blueman rfkill bluez-obexd)

install_bluetooth() {
  install_group bluetooth "${bluetooth[@]}"
  # Never replace PulseAudio with PipeWire (or vice versa) as part of
  # a hardware utility installation. Add only the matching plugin.
  if dpkg-query -W -f='${Status}' pipewire-pulse 2>/dev/null | grep -q 'install ok installed'; then
    install_group bluetooth-audio libspa-0.2-bluetooth
    echo 'Detected PipeWire PulseAudio replacement; added PipeWire Bluetooth plugin.'
  elif dpkg-query -W -f='${Status}' pulseaudio 2>/dev/null | grep -q 'install ok installed'; then
    install_group bluetooth-audio pulseaudio-module-bluetooth
    echo 'Detected PulseAudio; added its Bluetooth audio module.'
  else
    echo 'No installed PulseAudio or PipeWire-Pulse server detected.'
    echo 'Pairing and mouse/keyboard Bluetooth can still work.'
    echo 'Bluetooth sound needs audio-server configuration in a separate step.'
  fi
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now bluetooth.service
  fi
  echo 'Open the pairing interface with: blueman-manager'
  echo 'For the tray icon: blueman-applet (may already autostart).'
  echo 'To inspect radio state: rfkill list bluetooth'
}

case "${1:-}" in
  audit) audit ;;
  core|gaming|ipod|remote|firewire|hardware|bluetooth)
    sudo apt-get update
    case "$1" in
      core)
        install_group gaming "${gaming[@]}"
        install_group ipod "${ipod[@]}"
        install_group remote "${remote[@]}"
        install_group firewire "${firewire[@]}"
        install_group hardware "${hardware[@]}"
        install_bluetooth
        ;;
      gaming) install_group gaming "${gaming[@]}" ;;
      ipod) install_group ipod "${ipod[@]}" ;;
      remote) install_group remote "${remote[@]}" ;;
      firewire) install_group firewire "${firewire[@]}" ;;
      hardware) install_group hardware "${hardware[@]}" ;;
      bluetooth) install_bluetooth ;;
    esac
    echo
    echo 'Packages installed where available. Run the read-only audit:'
    echo '  bash scripts/install-legacy-features.sh audit'
    echo 'Do not configure Apple Remote event handlers until the device is identified.'
    echo 'Do not format/reinitialize an iPod until its data is backed up.'
    ;;
  *) usage; exit 2 ;;
esac
