#!/usr/bin/env python3
"""Read-only sanity check for a candidate legacy VGA option ROM.

This verifies basic structure, NOT that the ROM is safe or compatible
with Apple's iMac5,1 panel timings. Never flash it to hardware.
"""
import argparse, hashlib, pathlib, struct, sys

def main():
    p=argparse.ArgumentParser()
    p.add_argument("rom", type=pathlib.Path)
    a=p.parse_args()
    data=a.rom.read_bytes()
    print("File:",a.rom.name)
    print("Size:",len(data),"bytes")
    print("SHA256:",hashlib.sha256(data).hexdigest())
    problems=[]
    if not (4096 <= len(data) <= 524288):
        problems.append("unexpected legacy VGA ROM size")
    if data[:2] != b"\x55\xaa":
        problems.append("missing 55 AA expansion ROM signature")
    if len(data)>3 and data[2]*512 > len(data):
        problems.append("ROM header length exceeds file length")
    if len(data)<0x1a:
        problems.append("too small for PCI ROM pointer")
    else:
        ptr=struct.unpack_from("<H",data,0x18)[0]
        if ptr+0x18 > len(data) or data[ptr:ptr+4] != b"PCIR":
            problems.append("missing or invalid PCIR structure")
        else:
            vendor,device=struct.unpack_from("<HH",data,ptr+4)
            print(f"PCIR PCI ID: {vendor:04x}:{device:04x}")
            if (vendor,device)!=(0x1002,0x71c5):
                problems.append("PCI vendor/device mismatch (expected 1002:71c5)")
    if problems:
        print("REJECT:", "; ".join(problems))
        return 1
    print("BASIC FORMAT PASSED, but Apple panel compatibility remains UNVERIFIED.")
    print("DO NOT flash this ROM. Next step is source review and a recovery-safe kernel build.")
    return 0
if __name__=="__main__":sys.exit(main())
