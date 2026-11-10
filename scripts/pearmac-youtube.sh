#!/usr/bin/env bash
# PearMac YouTube lounge: familiar LibreWolf profile + Lightweight YouTube.
# No browser preferences, add-ons, GPU settings, or existing windows modified.
set -euo pipefail
url='https://www.youtube.com/'
mode="${1:-normal}"
case "$mode" in normal|kiosk) ;; *) echo "Usage: $0 [normal|kiosk]" >&2; exit 2 ;; esac

if command -v librewolf >/dev/null 2>&1; then
  browser=(librewolf)
elif command -v flatpak >/dev/null 2>&1 &&
     flatpak info io.gitlab.librewolf-community >/dev/null 2>&1; then
  browser=(flatpak run io.gitlab.librewolf-community)
else
  echo 'LibreWolf not found. Install LibreWolf first.' >&2
  exit 1
fi

if [[ "$mode" = kiosk ]]; then
  # Firefox kiosk has NO ordinary toolbar or F11 exit. Alt+F4 closes it.
  exec "${browser[@]}" --kiosk "$url"
else
  # The recommended mode keeps the user's signed-in browser profile and
  # extension state. Press F11 inside LibreWolf for fullscreen; F11 exits.
  exec "${browser[@]}" --new-window "$url"
fi
