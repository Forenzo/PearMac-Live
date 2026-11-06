#!/usr/bin/env python3
"""Apply the user-supplied radeon firmware fallback concept to Linux 6.1 source.

Fails closed if the expected radeon_bios.c anchors are absent. No ROM is bundled.
This script modifies a COPY of a kernel source tree, never a running kernel.
"""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    sys.exit("Usage: python3 apply_firmware_fallback.py /path/to/linux/source")
path = Path(sys.argv[1]) / "drivers/gpu/drm/radeon/radeon_bios.c"
text = path.read_text()
if "radeon_read_bios_from_firmware" in text:
    sys.exit("Already patched; refusing duplicate modifications")
include = '#include <linux/firmware.h>'
if include not in text:
    anchor = '#include <linux/slab.h>'
    if text.count(anchor) != 1:
        sys.exit("Unexpected upstream include layout")
    text = text.replace(anchor, anchor + "\n" + include, 1)

func = r'''
/*
 * PearMac experimental: final fallback for Apple EFI machines with Radeon
 * option ROM inaccessible via the normal kernel discovery methods.
 * Source concept credited to the iMac5,1 Debian 12 community workaround.
 * No VBIOS image is included; must be provided separately and inspected.
 */
static bool radeon_read_bios_from_firmware(struct radeon_device *rdev)
{
        const struct firmware *fw = NULL;
        int err;

        err = request_firmware(&fw, "radeon/vbios.bin", rdev->dev);
        if (err || !fw)
                return false;
        if (fw->size < 0x1a || fw->size > 512 * 1024 ||
            fw->data[0] != 0x55 || fw->data[1] != 0xaa) {
                DRM_ERROR("External Radeon BIOS invalid header or size\n");
                release_firmware(fw);
                return false;
        }
        rdev->bios = kmemdup(fw->data, fw->size, GFP_KERNEL);
        release_firmware(fw);
        return rdev->bios != NULL;
}

'''
anchor = "static bool radeon_read_bios(struct radeon_device *rdev)"
if text.count(anchor) != 1:
    sys.exit("Unexpected Radeon BIOS routine location")
text = text.replace(anchor, func + anchor, 1)
anchor = '''if (!r)
		r = radeon_read_platform_bios(rdev);
	if (!r || rdev->bios == NULL) {'''
replacement = '''if (!r)
		r = radeon_read_platform_bios(rdev);
	if (!r)
		r = radeon_read_bios_from_firmware(rdev);
	if (!r || rdev->bios == NULL) {'''
if text.count(anchor) != 1:
    sys.exit("Unsupported kernel source version: BIOS lookup sequence differs")
text = text.replace(anchor, replacement, 1)
path.write_text(text)
print("Patched", path, "— NO firmware provided; no kernel built")
