# Installation

## Warning

This procedure writes the primary firmware slot. A serial console, complete
backup, and verified alternate OEM slot are required. A 3.3 V TTL adapter must
be used; 5 V or RS-232 signaling can damage the SoC.

Never write:

```text
0:SBL1  0:MIBIB  0:BOOTCONFIG  0:BOOTCONFIG1
0:QSEE  0:DEVCFG  0:CDT        0:APPSBLENV
0:APPSBL 0:ART   0:TRAINING    productinfo data
```

## Preparation

1. Back up every MTD partition and hash the results.
2. Confirm that the physical alternate slot at `0x03b00000` contains bootable
   OEM firmware.
3. Place the initramfs and matching sysupgrade image on a local TFTP/HTTP host.
4. Connect UART at 115200 8N1 and a direct Ethernet cable.

## RAM Boot

Interrupt U-Boot and use temporary network settings appropriate for the direct
connection. Example:

```text
setenv ipaddr 192.168.10.10
setenv serverip 192.168.10.19
tftpboot 0x44000000 openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-initramfs-uImage.itb
bootm 0x44000000
```

Do not run `saveenv`.

Validate:

```sh
ubus call system board
cat /proc/mtd
ubinfo -a
ip addr show
iw phy
dmesg
```

All Ethernet ports and both radios must work before installation.

## Image Validation

Copy the matching sysupgrade image to `/tmp`. With both ath11k radios loaded,
RAM is tight; use a wired connection and unload the radios before storing a
large image if necessary:

```sh
wifi down
rmmod ath11k_pci
rmmod ath11k_ahb
```

Then verify:

```sh
sha256sum /tmp/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-sysupgrade.bin
sysupgrade -T /tmp/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-sysupgrade.bin
echo $?
```

The validation exit status must be zero.

## Write OpenWrt

Only after the matching initramfs passes:

```sh
sysupgrade -n /tmp/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-sysupgrade.bin
```

Do not interrupt power. The upgrade preserves UBI volumes 1 and 2 and replaces
volumes 0, 3, and 4.

Successful automatic boot includes:

```text
Using 'config@mp03.5-c1' configuration
block ubiblock0_3: created from ubi0:3(ubi_rootfs)
VFS: Mounted root (squashfs filesystem)
UBIFS: mounted UBI device 0, volume 4, name "rootfs_data"
```

There must be no kernel panic or `partition switch from 0 to 1`.

## First Login

OpenWrt defaults to `192.168.1.1` on the LAN bridge. Set a password:

```sh
passwd
```

Wi-Fi interfaces are disabled by default. Configure country, channels, SSIDs,
and encryption before enabling them.
