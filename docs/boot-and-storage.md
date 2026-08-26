# Boot and Storage

## FIT Selection

OEM `bootipq` selects `config@mp03.5-c1`. A FIT containing only
`config@mp02.1` can be booted manually but fails automatic boot with
`Config not available`. The OpenWrt FIT therefore uses `config@mp03.5-c1` as
its single configuration and default.

## Root Device

Attaching UBI alone does not create the block device required for SquashFS.
The proven command line includes:

```text
ubi.block=0,3 root=/dev/ubiblock0_3
```

This creates `ubiblock0_3` from volume ID 3, `ubi_rootfs`.

OEM U-Boot prepends its own `root=mtd:ubi_rootfs` contract. Linux receives both
sets of root arguments; the later OpenWrt `/dev/ubiblock0_3` argument wins. UBI
may log a harmless second-attach error because `ubi.mtd=rootfs` also appears
twice.

## UBI Layout

The 50 MiB rootfs partition has 400 physical eraseblocks. Twenty are reserved
for bad-block handling. The installed volumes are:

```text
ID 0 kernel       static   33 LEBs
ID 1 wifi_fw      static   preserved OEM payload
ID 2 bt_fw        static   preserved OEM payload
ID 3 ubi_rootfs   dynamic  94 LEBs
ID 4 rootfs_data  dynamic  remaining space
```

The kernel volume must be static and ID 0 because OEM U-Boot reads it directly.

## Sysupgrade

The MA3063 upgrade handler sets:

```sh
CI_UBIPART="rootfs"
CI_KERNPART="kernel"
CI_KERN_VOLTYPE="static"
CI_ROOTPART="ubi_rootfs"
```

The generic NAND upgrade code removes and recreates only the OpenWrt volumes.
The OEM firmware volumes remain IDs 1 and 2.

## Slot Switching

Qualcomm BOOTCONFIG metadata controls which physical slot is presented as the
active logical `rootfs`. U-Boot updates both metadata copies during fallback.
No OpenWrt A/B manager is installed and no OpenWrt script writes BOOTCONFIG.
