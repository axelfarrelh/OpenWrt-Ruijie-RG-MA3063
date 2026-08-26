# OpenWrt for Ruijie RG-MA3063

Hardware-validated OpenWrt support for the Ruijie RG-MA3063, built against
OpenWrt 25.12.5 (`r33051-f5dae5ece4`) on the `qualcommax/ipq50xx` target.

## Status

OpenWrt boots persistently from NAND through the stock Qualcomm U-Boot. The
validated installation has passed automatic reboot and cold power-cycle tests.

Working:

- NAND boot with OEM `bootipq` and FIT configuration `config@mp03.5-c1`.
- SquashFS root on `ubi_rootfs` with a UBIFS `rootfs_data` overlay.
- IPQ5018 2.4 GHz and QCN6122 5 GHz radios with device calibration.
- Direct IPQ5018 Ethernet PHY and QCA8337 DSA switch.
- All four chassis Ethernet sockets.
- NSS dataplane, LuCI, SSH, sysupgrade, and OEM-slot fallback.

Open issues:

- ath11k uses most of the available RAM when both radios are loaded. Ring-size
  reduction is being evaluated in RAM-only builds and is not part of the
  known-good baseline.
- The watchdog and CPU-frequency drivers report missing-clock warnings.
- OpenWrt does not yet install a persistent `/etc/fw_env.config`.
- LEDs are not implemented.

See [docs/known-issues.md](docs/known-issues.md) for details.

## Device

| Component | Hardware |
|---|---|
| SoC | Qualcomm IPQ5018, dual Cortex-A53 |
| RAM | 256 MiB, about 181 MiB visible to Linux |
| Flash | 128 MiB Winbond W25N01GW SPI-NAND, 4-bit ECC |
| 2.4 GHz | IPQ5018 internal radio, ath11k AHB |
| 5 GHz | QCN6122, ath11k PCI/multipd |
| Ethernet | One direct IPQ5018 PHY plus QCA8337 switch |
| Serial | 115200 8N1, 3.3 V TTL |

Physical port mapping:

| Chassis socket | OpenWrt device | Hardware path |
|---|---|---|
| LAN1 | `eth0`, logical WAN | Direct IPQ5018 PHY |
| LAN2 | `lan1` | QCA8337 port 1 |
| LAN3 | `lan2` | QCA8337 port 2 |
| LAN4 | `lan3` | QCA8337 port 3 |

More hardware detail is in [docs/hardware.md](docs/hardware.md).

## Storage Contract

OpenWrt is installed in the physical primary firmware partition at
`0x00900000`. The alternate OEM firmware at `0x03b00000` remains untouched.
OEM U-Boot may dynamically present the active physical slot as logical
`rootfs`, so logical names can swap during fallback; physical offsets are the
stable identifiers.

The OpenWrt UBI uses the OEM-compatible volume IDs:

```text
ID  name         type
0   kernel       static
1   wifi_fw      static
2   bt_fw        static
3   ubi_rootfs   dynamic
4   rootfs_data  dynamic
```

The build preserves `wifi_fw` and `bt_fw` byte-for-byte while sysupgrade
replaces only `kernel`, `ubi_rootfs`, and `rootfs_data`.

## Installation

Read [docs/installation.md](docs/installation.md) completely before writing
flash. The required flow is:

1. Back up every MTD partition and keep the backup outside Git.
2. Boot the matching initramfs image through UART/TFTP.
3. Validate Ethernet, both radios, MTD layout, and UBI volumes.
4. Verify the sysupgrade SHA-256 and run `sysupgrade -T`.
5. Run `sysupgrade -n` only after the RAM test passes.

Do not replace U-Boot, modify ART, manually write BOOTCONFIG, or use U-Boot
`flash` commands.

## Building

The repository contains public source changes but not the OEM firmware volumes,
board-data files, NAND dumps, or generated images. Extract those inputs from
your own device as described in [docs/building.md](docs/building.md).

The primary workflow is:

```sh
./scripts/apply-local-patches.sh /path/to/openwrt
cp src/config-fragment /path/to/openwrt/.config
make -C /path/to/openwrt defconfig
make -C /path/to/openwrt -j"$(nproc)"
```

The validated WSL build tree is kept on the Linux filesystem rather than under
`/mnt/c` or `/mnt/d`.

## Repository Layout

```text
docs/       hardware, build, installation, recovery, and findings
images/     verified artifact names, sizes, and checksums only
src/        config fragment, new OpenWrt files, and source patches
scripts/    reproducible application, rebuild, and provenance checks
tools/      BDF conversion and UART helpers
```

Private router data and build products are intentionally ignored by Git.

## Verified Artifacts

The known-good artifact hashes are recorded in
[images/sha256sums.txt](images/sha256sums.txt). Binaries are excluded because
they contain OEM-derived firmware material.

## References

See [REFERENCES.md](REFERENCES.md) for upstream documentation, prior device
work, and attribution.
