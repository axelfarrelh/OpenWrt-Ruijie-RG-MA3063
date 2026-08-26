# Images

Firmware binaries are intentionally not committed. The verified images contain
OEM-derived `wifi_fw`, `bt_fw`, and board-data material that must be extracted
from the owner's device.

Build the images locally using [docs/building.md](../docs/building.md). Compare
the resulting artifacts with [sha256sums.txt](sha256sums.txt) only when using the
same OpenWrt revision, configuration, and private input files.

Expected files:

```text
openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-initramfs-uImage.itb      15635012 bytes
openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-persistent-kernel.itb     4190004 bytes
openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-factory.ubi     20840448 bytes
openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-squashfs-sysupgrade.bin  16046354 bytes
```

The standalone persistent kernel listed in the checksum file is the `kernel`
member extracted from the sysupgrade archive for RAM-only boot testing.

These checksums were produced from OpenWrt 25.12.5, revision
`r33051-f5dae5ece4`, with FIT configuration `config@mp03.5-c1` and the
five-volume OEM-compatible UBI layout.
