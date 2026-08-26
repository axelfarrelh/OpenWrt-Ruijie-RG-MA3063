#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "Usage: $0 <openwrt-source-directory> [--prepare-only]" >&2
	exit 1
fi

prepare_only=${2:-}
[ -z "$prepare_only" ] || [ "$prepare_only" = "--prepare-only" ] || {
	echo "Unknown option: $prepare_only" >&2
	exit 1
}

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
openwrt_dir=$1
root_dir="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/root-qualcommax"
pristine_dir="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/root.orig-qualcommax"
toolchain_dir="$openwrt_dir/staging_dir/toolchain-aarch64_cortex-a53_gcc-14.3.0_musl/bin"

test -d "$openwrt_dir"
test -d "$root_dir"
test -d "$pristine_dir"
test -d "$toolchain_dir"

"$project_dir/scripts/apply-local-patches.sh" "$openwrt_dir"

jobs=${JOBS:-$(nproc)}
export PATH="$toolchain_dir:$openwrt_dir/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ "$prepare_only" != "--prepare-only" ]; then
	FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" target/linux/compile
	FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" package/compile
	FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" package/install
fi

# Recreate both radio directories from the package-managed reference root.
# Replacing instead of merging guarantees stale experimental files cannot remain.
rm -rf "$root_dir/lib/firmware/ath11k/IPQ5018/hw1.0"
rm -rf "$root_dir/lib/firmware/ath11k/QCN6122/hw1.0"
mkdir -p "$root_dir/lib/firmware/ath11k/IPQ5018" "$root_dir/lib/firmware/ath11k/QCN6122"
cp -a "$pristine_dir/lib/firmware/ath11k/IPQ5018/hw1.0" \
	"$root_dir/lib/firmware/ath11k/IPQ5018/"
cp -a "$pristine_dir/lib/firmware/ath11k/QCN6122/hw1.0" \
	"$root_dir/lib/firmware/ath11k/QCN6122/"

# Apply only the board-specific data and calibration hook after restoration.
cp "$project_dir/router-data/stock-wifi-fw"/bdwlan.* \
	"$root_dir/lib/firmware/ath11k/IPQ5018/hw1.0/"
cp "$project_dir/router-data/stock-wifi-fw/bdwlan.b23" \
	"$root_dir/lib/firmware/ath11k/IPQ5018/hw1.0/board.bin"
cp "$project_dir/router-data/stock-wifi-fw/qcn6122"/bdwlan.* \
	"$root_dir/lib/firmware/ath11k/QCN6122/hw1.0/"
cp "$openwrt_dir/files/lib/firmware/ath11k/QCN6122/hw1.0/bdwlan.b60" \
	"$root_dir/lib/firmware/ath11k/QCN6122/hw1.0/bdwlan.b60"
cp "$openwrt_dir/files/lib/firmware/ath11k/QCN6122/hw1.0/board.bin" \
	"$root_dir/lib/firmware/ath11k/QCN6122/hw1.0/board.bin"
cp "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/hotplug.d/firmware/11-ath11k-caldata" \
	"$root_dir/etc/hotplug.d/firmware/11-ath11k-caldata"
mkdir -p "$root_dir/etc/board.d"
cp "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network" \
	"$root_dir/etc/board.d/02_network"
chmod 0755 "$root_dir/etc/board.d/02_network"
mkdir -p "$root_dir/etc/uci-defaults"
cp "$openwrt_dir/files/etc/uci-defaults/99-ma3063-disable-wifi" \
	"$root_dir/etc/uci-defaults/99-ma3063-disable-wifi"
chmod 0755 "$root_dir/etc/uci-defaults/99-ma3063-disable-wifi"
rm -f "$root_dir/etc/init.d/fix-eth-mac" "$root_dir/etc/rc.d/S19fix-eth-mac"

"$project_dir/scripts/verify-image-root.sh" "$openwrt_dir"

if [ "$prepare_only" = "--prepare-only" ]; then
	exit 0
fi

FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" target/linux/install

"$project_dir/scripts/verify-image-root.sh" "$openwrt_dir"

artifact="$openwrt_dir/bin/targets/qualcommax/ipq50xx/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-initramfs-uImage.itb"
test -f "$artifact"
sha256sum "$artifact"
stat -c '%s bytes' "$artifact"
