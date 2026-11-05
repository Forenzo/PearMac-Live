#!/usr/bin/env bash
set +e
OUT="${1:-$HOME/pearmac-wifi-report.txt}"
{
 date -u
 cat /etc/os-release
 cat /proc/cmdline
 echo '== PCI =='; lspci -nnk
 echo '== USB =='; lsusb
 echo '== Network =='; nmcli device status; iw dev; rfkill list
 echo '== Modules =='; lsmod | grep -E 'b43|ssb|bcma|brcm|wl|sky2'
 echo '== Firmware =='; find /lib/firmware -maxdepth 3 \( -iname '*b43*' -o -iname '*brcm*' \) | head -100
 echo '== Messages =='; dmesg | grep -Ei 'b43|brcm|bcma|ssb|wl|firmware|wlan' | tail -150
} > "$OUT" 2>&1
echo "Saved $OUT"
