# Recovery

## Slot Behavior

Physical slot identity is stable:

```text
0x00900000  primary slot, OpenWrt after installation
0x03b00000  alternate OEM slot, preserved
```

Logical `rootfs` and `rootfs_1` labels can swap when Qualcomm BOOTCONFIG changes
the active slot. Always use `smeminfo` to relate a logical name to its physical
offset before interpreting a boot log.

## Automatic OEM Fallback

OEM U-Boot tracks boot attempts in APPSBLENV. When its threshold is exceeded it
can update both BOOTCONFIG copies, switch active firmware slots, and reset. This
mechanism successfully recovered to the untouched OEM slot during development.

Do not manually edit `ipqboot_num`, BOOTCONFIG, BOOTCONFIG1, or APPSBLENV to
force a switch.

## TFTP Recovery

If OpenWrt fails but U-Boot remains accessible:

1. Interrupt autoboot.
2. Inspect `smeminfo` and `printenv` read-only.
3. TFTP the known-good initramfs to `0x44000000`.
4. Boot it with `bootm 0x44000000`.
5. Inspect NAND and UBI before deciding whether a sysupgrade is appropriate.

The verified persistent kernel can also be loaded over TFTP and booted against
the installed rootfs without writing NAND.

## Backup Requirements

Keep these outside Git and on more than one storage device:

- Every logical MTD partition.
- Both 50 MiB firmware slots.
- ART and product information.
- APPSBLENV and both BOOTCONFIG copies.
- A cold-boot UART log and U-Boot environment listing.

Backups can contain MAC addresses, calibration data, identifiers, OEM firmware,
and secrets. Do not publish them.
