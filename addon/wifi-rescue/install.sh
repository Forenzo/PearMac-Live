#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$(readlink -f "$0")")"
if [[ $EUID -ne 0 ]]; then exec sudo bash "$0" "$@"; fi
echo '=== PearMac Wi-Fi Rescue (Debian 12 amd64 live) ==='
[[ $(dpkg --print-architecture) == amd64 ]] || { echo 'Requires amd64'; exit 1; }
grep -q 'VERSION_ID="12"' /etc/os-release || { echo 'Requires Debian 12'; exit 1; }
[[ -d debs ]] && compgen -G 'debs/*.deb' >/dev/null || { echo 'Offline packages missing. Run the GitHub workflow and use its artifact.'; exit 1; }
lspci -nnk | grep -A 6 -Ei 'Network controller|Wireless|Broadcom' || true
echo 'This original live USB does not save installed packages across reboot.'
read -r -p 'Install native Wi-Fi packages for this session? [y/N] ' reply
[[ $reply =~ ^[Yy]$ ]] || exit 0
apt-get -o Dir::Etc::sourcelist=/dev/null -o Dir::Etc::sourceparts=- --no-download install -y ./debs/*.deb
if [[ -d firmware ]]; then cp -a firmware/. /lib/firmware/; fi
systemctl start NetworkManager.service || true
nmcli device status || true
echo 'Run: sudo bash wifi-report.sh'
