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

The `ath11k-candidate-c-persistent` entries are archived trial artifacts. They
contain the RAM-validated Candidate C ath11k profile, firmware memory mode 2,
and the temporary persistent guard. The recorded sysupgrade artifact passed
`sysupgrade -T`, persistent traffic testing, normal reboot, and cold
power-cycle. Its pre-clock-fix builder is not retained because rebuilding after
the permanent DTS clock correction would produce different content under the
same filenames.

The later `ath11k-candidate-c-persistent-clockfix` entries identify the
guard-free deployed profile. This image adds the corrected 24 MHz board XO and
32 kHz sleep clock. It passed LuCI sysupgrade and post-reboot validation with an
active hardware watchdog, a fixed 1.008 GHz CPU policy, both radios, LAN/WAN,
healthy UBI volumes, and no fatal kernel or ath11k event.

The checksum file records the exact flashed and runtime-validated artifacts,
not the most recent local rebuild. Rebuilt factory/sysupgrade containers can
have different hashes even when their verified kernel, rootfs contents,
configuration, and sizes are unchanged; do not replace deployed hashes with an
unflashed rebuild result.

These checksums were produced from OpenWrt 25.12.5, revision
`r33051-f5dae5ece4`, with FIT configuration `config@mp03.5-c1` and the
five-volume OEM-compatible UBI layout.
