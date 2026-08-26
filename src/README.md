# Source Layout

`config-fragment` is the reproducible OpenWrt configuration input.

`new/` mirrors files copied into the OpenWrt tree:

```text
new/files/...
new/target/linux/qualcommax/...
```

`patches/` contains patches to generic OpenWrt image and NAND-upgrade
infrastructure. `device-makefile-entry.txt` is inserted into the IPQ50xx device
recipe.

`scripts/apply-local-patches.sh` is authoritative for small edits to existing
OpenWrt files, including the platform upgrade handler, calibration hook,
uboot-envtools entry, SSDK configuration, and device recipe insertion.

Private OEM inputs are not stored under `src/`; see `docs/building.md`.
