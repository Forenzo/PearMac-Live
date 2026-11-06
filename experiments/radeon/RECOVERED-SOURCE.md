## Recovered source from the user (November 6)

The user supplied the full modified `radeon_bios.c` (Linux 6.1-era)
from the acceleration guide. It confirms the precise mechanism:

- `radeon_read_bios_from_firmware()` calls
  `request_firmware(..., "radeon/vbios.bin", ...)`;
- it copies valid-looking VBIOS bytes into `rdev->bios`;
- `radeon_get_bios()` tries this method **after** its normal BIOS lookups fail.

The provided file is **source code, not** `vbios.bin`. We still do not
have a verified iMac5,1 VBIOS to feed it.

The full uploaded file contains much more of the historical driver than
our changes. We should NOT overwrite the entire Debian kernel driver with
an older revision, as it would discard security and correctness fixes.
`apply_firmware_fallback.py` instead reproduces only the fallback logic
against the *actual* Linux 6.1 source being built, with strict anchor
checks and reasonable error/size handling. It is not yet build-tested.

Use:
```sh
python3 experiments/radeon/apply_firmware_fallback.py /path/to/linux-source
```

Then independently review the diff before building. The modified source
alone does **not** enable acceleration. A compatible external ROM must
be made available in the new kernel's initramfs. The safe boot entry must
stay first and unchanged, and the patched test must be a separate kernel.

Do not use a GPU-Z Windows driver archive as if it were a VBIOS.
