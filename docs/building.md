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
