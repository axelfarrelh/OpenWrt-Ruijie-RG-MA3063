# OpenWrt For Ruijie RG-MA3063

Experimental, reproducible OpenWrt build work for the Ruijie RG-MA3063.

## Status

The firmware build has completed, but no image has been tested on physical hardware. It produces:

- An initramfs FIT image for non-destructive TFTP/RAM boot testing.
- Candidate NAND/UBI images for structural inspection only.

Do not flash any generated permanent image until UART/TFTP validation has completed.

## Current Build

The current build is based on OpenWrt `openwrt-25.12` commit
`4a5c6b90d21522d2663ce2718c973f9e845f2119`. Build products are intentionally
ignored by Git and remain in the Linux build tree:

```text
/root/src/openwrt-rg-ma3063/bin/targets/qualcommax/ipq50xx/
```

| Artifact | Purpose | SHA-256 |
|---|---|---|
| `openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-initramfs-uImage.itb` | RAM-only TFTP test image | `9d3d4cbdcaaa319deb7fe8a44928d704081a373d523765f200c14cbd4b21f457` |
| `openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-sysupgrade.bin` | Permanent-install candidate, inspection only | `f139d15add8ae52d9c3bffbeac93852c0d31136f949ae75c782985ed0e793e0a` |
| `openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-factory.ubi` | UBI candidate, inspection only | `5f3d587ac133cb373f589c40430a5e53f6a8a6c9895de914ca34980bad88b94f` |

The initramfs FIT is ARM64, LZMA-compressed, and has the required default
configuration `config@mp03.5-c2`. All listed images are below the 50 MiB target
slot limit.

## Hardware Summary

- SoC: Qualcomm IPQ5000, compatible with the IPQ5018 OpenWrt target.
- RAM: 256 MB DDR3.
- Flash: 128 MB SPI NAND.
- Wi-Fi: IPQ5018 internal 2.4 GHz radio and QCN6122 external 5 GHz radio.
- Ethernet: one WAN port and three LAN ports through a QCA8337 switch.

The documented NAND layout reserves two 50 MB firmware slots. The intended OpenWrt target is `rootfs` at offset `0x00900000`; `rootfs_1` is retained as an untouched vendor slot during initial testing.

## Safety Rules

- Do not replace or modify the OEM boot chain or U-Boot.
- Do not write or erase ART (`mtd13`, offset `0x00780000`). It holds device MAC addresses and Wi-Fi calibration data.
- Do not write bootloader, TrustZone, NAND-training, product-information, or vendor-data partitions.
- Test the initramfs through UART/TFTP before considering a permanent install.
- LED support is deliberately deferred until core Ethernet and Wi-Fi operation is validated.

## Build Choices

- OpenWrt target: `qualcommax/ipq50xx`.
- Build branch: `openwrt-25.12`.
- Wi-Fi: full `wpad`, ath11k AHB and PCI drivers.
- Networking: normal IPv4 and IPv6 support, `odhcp6c`, `odhcpd`, `relayd`, and `luci-proto-relay`.
- Excluded: `mwan3` and `luci-app-mwan3`.

Before each build, review and approve the relevant selections in `make menuconfig`. The tracked configuration fragment remains the reproducible build input.

## Build Location

Build only inside this workspace or a Linux filesystem. Do not build the OpenWrt tree under a mounted Windows path such as `/mnt/d`; it is slower and can introduce file-system issues.

## Rebuild

The tracked inputs are applied to a separate OpenWrt checkout by
`scripts/apply-local-patches.sh`. Run the build from its Linux filesystem path:

```sh
cd /root/src/openwrt-rg-ma3063
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
FORCE_UNSAFE_CONFIGURE=1 make -j6 V=s
```

`FORCE_UNSAFE_CONFIGURE=1` is required only because this WSL checkout is built
as `root`. The Linux-only `PATH` prevents GNU `find -execdir` from rejecting
inherited Windows path entries during image assembly.

## Later Hardware Test

After the build passes structural checks and the router is available:

1. Enable developer mode and SSH on stock firmware.
2. Back up ART, both stock rootfs slots, the U-Boot environment, stock Wi-Fi firmware, and a serial boot log.
3. Connect a 3.3 V USB-to-TTL adapter at 115200 8N1.
4. Load the initramfs with TFTP and boot it from RAM only:

   ```text
   tftpboot 0x44000000 <initramfs-image>
   bootm 0x44000000#config@mp03.5-c2
   ```
5. Verify WAN/LAN mapping, both Wi-Fi radios, ART-derived MAC addresses, calibration, reset-button behavior, and boot logs.
6. Inspect U-Boot slot selection and stock UBI layout before any permanent flash.

## Sources And References

See [REFERENCES.md](REFERENCES.md) for pinned baseline and research sources.
