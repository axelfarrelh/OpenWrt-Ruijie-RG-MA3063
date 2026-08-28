# Building

## Pinned Baseline

The verified build uses OpenWrt 25.12.5, revision `r33051-f5dae5ece4`, from tag
commit `f0a60eee2fe051741c643ea6118718aae1ef17fb`.

Build on a Linux filesystem. WSL is supported, but the OpenWrt source tree
should not live under `/mnt/c` or `/mnt/d`.

## Private Inputs

The repository intentionally excludes OEM firmware and per-device data. Extract
these from your own RG-MA3063 and place them under the ignored `router-data/`
directory:

```text
router-data/
├── bdf/
│   ├── bdwlan.b23
│   ├── other IPQ5018 bdwlan files, if present
│   └── qcn6122/
│       ├── bdwlan.b60
│       └── other QCN6122 bdwlan files, if present
└── oem-volumes/
    ├── wifi_fw.bin
    └── bt_fw.bin
```

`wifi_fw.bin` and `bt_fw.bin` are the complete static UBI volume payloads, not
files with the same names extracted from inside a filesystem.

The scripts verify the expected board-data hashes and refuse unexpected
QCN6122 conversion input.

## Configure the Tree

```sh
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt
git checkout f0a60eee2fe051741c643ea6118718aae1ef17fb
./scripts/feeds update -a
./scripts/feeds install -a
```

From this repository:

```sh
./scripts/apply-local-patches.sh /path/to/openwrt
cp src/config-fragment /path/to/openwrt/.config
make -C /path/to/openwrt defconfig
```

Review `.config` before building.

## Build

```sh
make -C /path/to/openwrt -j"$(nproc)"
```

When building as root in WSL, use a Linux-only `PATH` and
`FORCE_UNSAFE_CONFIGURE=1` as required by OpenWrt.

For the validated local tree, the helper performs incremental rebuild and
provenance checks:

```sh
./scripts/rebuild-initramfs.sh /path/to/openwrt
```

Use `--prepare-only` to apply and verify inputs without compiling.

## RAM-Only ath11k Candidate A

Candidate A is an opt-in experiment and is not part of the normal build path.
It reduces only the ath11k RXDMA buffer and monitor buffer/destination rings.
Build its initramfs image with:

```sh
./scripts/build-ath11k-candidate-a-initramfs.sh /path/to/openwrt
```

The helper cleans and rebuilds mac80211, verifies every affected ring constant,
and creates an artifact containing `ath11k-candidate-a-switchroot-initramfs` in
its name. Its early init mounts the installed `ubi_rootfs` read-only, supplies
Candidate A modules from a temporary overlay, and discards the large embedded
root before services start. The persistent UBIFS overlay is not mounted.

Boot that image only through TFTP/U-Boot RAM. Do not use it with `sysupgrade` or
write it to NAND. Running the normal application script without
`ATH11K_RING_EXPERIMENT=candidate-a` removes the experimental patch from the
OpenWrt tree.

Candidate B additionally reduces `DP_TX_COMP_RING_SIZE` from 32768 to 8192
after Candidate A failed sustained traffic. Build its separate RAM-only image
with:

```sh
./scripts/build-ath11k-candidate-b-initramfs.sh /path/to/openwrt
```

Candidate C is a combined sufficiency experiment. It uses the transferable
OEM-like ring values, sets firmware memory mode 2 on both radios in the
temporary build-tree DTS, and gives each RXDMA ring a private page-fragment
cache. Build it with:

```sh
./scripts/build-ath11k-candidate-c-initramfs.sh /path/to/openwrt
```

The helper verifies the compiled ring constants, allocator and teardown paths,
both mode-2 DTB properties, the 48 MiB WCSS reservation, fixed BDF/M3
addresses, FIT default, module hashes, and switch-root init. Cleanup restores
the normal mode-1 DTS and removes every experimental ath11k patch from the
OpenWrt tree. Candidate C is for TFTP/U-Boot RAM boot only and must not be used
with `sysupgrade`.

The combined profile passed two independent cold boots, 30-minute 5 GHz tests
in both directions, a 10-minute 2.4 GHz reverse test, and a 60-minute 5 GHz
reverse test at about 304 Mbit/s. Its guard enforces a 24 MiB hard
`MemAvailable` threshold and fatal kernel/radio detection. It intentionally has
no short-term memory-slope action because normal datapath working-set
population exceeded the former 8 MiB-per-minute limit before settling and
recovering.

The first persistent Candidate C trial used a temporary guard and passed
`sysupgrade -T`, first boot, a five-minute 305 Mbit/s reverse test, normal
reboot, and cold power-cycle. Its OEM firmware volumes remained byte-identical.
Those archived artifact hashes remain in `images/sha256sums.txt`, but their
guarded pre-clock-fix builder is intentionally not retained because the current
board DTS would otherwise produce different content under the old filenames.

The later board-clock image removes the now-unneeded Candidate C guard and
adds the validated clock properties:

```sh
./scripts/build-ath11k-candidate-c-clockfix-persistent.sh /path/to/openwrt
```

This builder verifies the compiled 24 MHz `xo-board-clk`, 32 kHz `sleep-clk`,
mode-2 radio properties, Candidate C datapath changes, image structure, and
absence of every guard file. It emits distinctly named artifacts under the
ignored `artifacts/candidate-c-persistent-clockfix/` directory. The resulting
sysupgrade image was flashed through LuCI and verified after reboot with an
active `qcom_wdt`, a fixed 1.008 GHz cpufreq policy, both APs, LAN/WAN, and no
clock, deferred-probe, OOM, ath11k-fatal, or remoteproc-crash message.

Candidate A and B builders remain only to reproduce the rejected RAM-only test
history. Do not install their artifacts persistently. Candidate C also remains
opt-in: the normal application script removes all experimental ath11k patches
unless `ATH11K_RING_EXPERIMENT=candidate-c` is selected by one of its builders.

## Output Contract

The expected target directory is:

```text
bin/targets/qualcommax/ipq50xx/
```

The generated FIT must default to `config@mp03.5-c1`. The persistent DT must
contain:

```text
ubi.mtd=rootfs ubi.block=0,3 root=/dev/ubiblock0_3
rootfstype=squashfs rootwait coherent_pool=2M
```

The factory UBI must contain IDs 0 through 4 in the order documented in the
root README.

## Source Layout

`src/new/` mirrors files copied into OpenWrt. `src/patches/` contains changes to
generic image and upgrade infrastructure. `src/device-makefile-entry.txt` is
inserted into `ipq50xx.mk`. The application script performs the remaining small
edits to existing target files and validates the result.
