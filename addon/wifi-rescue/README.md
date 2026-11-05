# PearMac Wi-Fi Rescue — offline USB add-on

Run the **Build offline Wi-Fi rescue** workflow in this repository. Download the generated artifact and unzip it; then unzip its enclosed `PearMac-WiFi-Rescue-offline.zip` onto your PearMac USB FAT partition or a second USB stick.

Boot **PearMac Build #1**, open a terminal in the `pearmac-wifi-rescue` directory, and run:

```bash
sudo bash install.sh
sudo bash wifi-report.sh
```

The first USB image **does not enable persistent storage**. Installed changes are temporary and disappear after reboot. The add-on is for testing Wi-Fi without a new SquashFS remaster. To preserve packages across boots we must later add a Debian Live persistence volume + the `persistence` kernel boot argument or make a new image.

The native kernel drivers (`b43`, `brcmsmac`, `brcmfmac`) require chipset-matching firmware. The build extracts b43 firmware if the installer can download it; check the artifact's `firmware/` directory. **Do not load Broadcom `wl` over `b43`**: `wl` may require matching kernel headers and is not included as an active driver in the rescue kit. We need the AirPort PCI ID to choose the correct driver.

Debian references: https://wiki.debian.org/bcm43xx and https://wiki.debian.org/DebianLive/LiveUsbPersistence
