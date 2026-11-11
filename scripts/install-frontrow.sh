#!/usr/bin/env bash
# Per-user Apple Remote integration for PearMac Q4OS / Trinity.
set -euo pipefail
if (( EUID == 0 )); then
  echo "Run as your normal desktop user, not root." >&2
  exit 1
fi
script_dir="$(cd "$(dirname "$0")" && pwd)"
controller="$script_dir/pearmac-frontrow.py"
auto="$HOME/.config/autostart/pearmac-frontrow.desktop"
menu="$HOME/.local/share/applications/pearmac-frontrow.desktop"

case "$1" in
  install)
    test -f "$controller" || { echo "Missing controller: $controller" >&2; exit 1; }
    sudo apt-get install python3-evdev python3-tk xdotool playerctl pulseaudio-utils
    mkdir -p "$(dirname "$auto")" "$(dirname "$menu")"
    # Freedesktop .desktop Exec supports a quoted absolute filename.
    escaped="$(printf '%s' "$controller" | sed 's/\\/\\\\/g;s/"/\\"/g')"
    cat > "$auto" <<EOF
[Desktop Entry]
Type=Application
Name=PearMac Front Row Remote
Comment=Six-button Apple Remote lounge on Trinity
Exec=/usr/bin/python3 "$escaped"
Terminal=false
X-GNOME-Autostart-enabled=true
Categories=AudioVideo;Player;
EOF
    cp "$auto" "$menu"
    echo "Configured Front Row for the next Trinity login."
    echo "Test now: python3 \"$controller\""
    echo "Menu opens the lounge; Ctrl+C stops the test."
    ;;
  uninstall)
    rm -f "$auto" "$menu"
    echo "Removed user autostart and desktop menu entries."
    echo "If still running, stop the controller with Ctrl+C or log out."
    ;;
  *)
    echo "Usage: bash $0 install|uninstall" >&2
    exit 2
    ;;
esac
