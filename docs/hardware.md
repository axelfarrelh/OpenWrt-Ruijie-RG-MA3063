# Hardware

## Core Platform

```text
SoC:             Qualcomm IPQ5018
RAM:             256 MiB DDR3
SPI-NAND:        Winbond W25N01GW, 128 MiB
ECC:             4 bits per 512 bytes
2.4 GHz radio:   IPQ5018 internal ath11k radio
5 GHz radio:     QCN6122 external ath11k radio
External switch: QCA8337/AR8337
```

Linux sees about 181 MiB because secure firmware, the bootloader, SMEM, and the
48 MiB WCSS region reserve the rest of physical RAM.

## NAND Layout

| Offset | Size | Label |
|---:|---:|---|
| `0x0000000` | 512 KiB | `0:SBL1` |
| `0x0080000` | 512 KiB | `0:MIBIB` |
| `0x0100000` | 256 KiB | `0:BOOTCONFIG` |
| `0x0140000` | 256 KiB | `0:BOOTCONFIG1` |
| `0x0180000` | 1 MiB | `0:QSEE` |
| `0x0280000` | 1 MiB | `0:QSEE_1` |
| `0x0380000` | 256 KiB | `0:DEVCFG` |
| `0x03c0000` | 256 KiB | `0:DEVCFG_1` |
| `0x0400000` | 256 KiB | `0:CDT` |
| `0x0440000` | 256 KiB | `0:CDT_1` |
| `0x0480000` | 512 KiB | `0:APPSBLENV` |
| `0x0500000` | 1280 KiB | `0:APPSBL` |
| `0x0640000` | 1280 KiB | `0:APPSBL_1` |
| `0x0780000` | 1 MiB | `0:ART` |
| `0x0880000` | 512 KiB | `0:TRAINING` |
| `0x0900000` | 50 MiB | primary firmware slot |
| `0x3b00000` | 50 MiB | alternate firmware slot |
| `0x6d00000` | 1152 KiB | `ttyMTD` |
| `0x6e20000` | 512 KiB | `productinfo` |
| `0x6ea0000` | 16.25 MiB | `data` |

Do not write ART, the boot chain, BOOTCONFIG, product information, training, or
vendor data partitions.

## Ethernet

MDIO1 requires divider `/64`, approximately 1.5625 MHz from the 100 MHz source.
Faster settings produced deterministic corrupt reads. Correct identities are:

```text
QCA8337 register 0: 0x00001302
Internal PHY ID:    0x004dd036
```

GPIO26 is the active-low QCA8337 reset. GPIO36 is MDIO1 MDC and GPIO37 is
MDIO1 data.

| Chassis socket | Linux device | Path |
|---|---|---|
| LAN1 | `eth0`, logical WAN | IPQ5018 direct PHY at MDIO0 address 7 |
| LAN2 | `lan1` | QCA8337 port 1 |
| LAN3 | `lan2` | QCA8337 port 2 |
| LAN4 | `lan3` | QCA8337 port 3 |

The base Ethernet MAC is read from U-Boot `ethaddr` in `0:APPSBLENV`. LAN uses
the next address. The implementation reads the environment and never writes it.

## Wi-Fi Data

```text
IPQ5018 BDF:         OEM bdwlan.b23
IPQ5018 calibration: ART offset 0x1000, size 0x20000
QCN6122 BDF:         converted OEM bdwlan.b60
QCN6122 calibration: ART offset 0x26800, size 0x20000
```

The matched OpenWrt firmware package supplies executable Q6 and M3 firmware.
Only device board data and calibration are OEM-derived.

## Buttons and LEDs

The reset button is assigned to GPIO33. LED support remains deferred.
