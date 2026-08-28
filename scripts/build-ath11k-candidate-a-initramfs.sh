#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <openwrt-source-directory>" >&2
	exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
openwrt_dir=$1
build_dir="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/linux-qualcommax_ipq50xx"
mac80211_dir="$build_dir/mac80211-regular/backports-6.18.26"
dp_h="$mac80211_dir/drivers/net/wireless/ath/ath11k/dp.h"
target_dir="$openwrt_dir/bin/targets/qualcommax/ipq50xx"
source_image="$target_dir/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-initramfs-uImage.itb"
candidate_image="$target_dir/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-ath11k-candidate-a-switchroot-initramfs-uImage.itb"
switchroot_init="$project_dir/src/experimental/ath11k/candidate-a-switchroot-init"
normal_init="$openwrt_dir/target/linux/generic/other-files/init"
root_init="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/root-qualcommax/init"
toolchain_dir="$openwrt_dir/staging_dir/toolchain-aarch64_cortex-a53_gcc-14.3.0_musl/bin"
normal_init_backup=$(mktemp)

test -d "$openwrt_dir"
test -f "$switchroot_init"
test -f "$normal_init"
test -d "$toolchain_dir"
cp "$normal_init" "$normal_init_backup"

cleanup() {
	cp "$normal_init_backup" "$normal_init"
	chmod 0755 "$normal_init"
	if [ -d "${root_init%/*}" ]; then
		cp "$normal_init_backup" "$root_init"
		chmod 0755 "$root_init"
	fi
	rm -f "$normal_init_backup"
	ATH11K_RING_EXPERIMENT= "$project_dir/scripts/apply-local-patches.sh" "$openwrt_dir"
	FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" package/kernel/mac80211/clean >/dev/null
}
trap cleanup EXIT INT TERM

export PATH="$toolchain_dir:$openwrt_dir/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

cp "$switchroot_init" "$normal_init"
chmod 0755 "$normal_init"

ATH11K_RING_EXPERIMENT=candidate-a \
	"$project_dir/scripts/apply-local-patches.sh" "$openwrt_dir"

jobs=${JOBS:-$(nproc)}
FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" package/kernel/mac80211/clean

ATH11K_RING_EXPERIMENT=candidate-a \
	INITRAMFS_INIT_OVERRIDE="$switchroot_init" \
	"$project_dir/scripts/rebuild-initramfs.sh" "$openwrt_dir"

test -f "$dp_h"
check_define() {
	name=$1
	value=$2
	grep -Eq "^#define[[:space:]]+$name[[:space:]]+$value$" "$dp_h" || {
		echo "Unexpected $name in $dp_h" >&2
		exit 1
	}
}

check_define DP_TX_COMP_RING_SIZE 32768
check_define DP_RXDMA_BUF_RING_SIZE 2048
check_define DP_RXDMA_REFILL_RING_SIZE 2048
check_define DP_RXDMA_MON_STATUS_RING_SIZE 1024
check_define DP_RXDMA_MONITOR_BUF_RING_SIZE 128
check_define DP_RXDMA_MONITOR_DST_RING_SIZE 128
check_define DP_RXDMA_MONITOR_DESC_RING_SIZE 4096

test -f "$mac80211_dir/drivers/net/wireless/ath/ath11k/ath11k.ko"
test -f "$mac80211_dir/drivers/net/wireless/ath/ath11k/ath11k_ahb.ko"
test -f "$mac80211_dir/drivers/net/wireless/ath/ath11k/ath11k_pci.ko"
test -f "$source_image"
cmp -s "$switchroot_init" \
	"$root_init"

cp "$source_image" "$candidate_image"

echo "Candidate A ring sizes verified."
sha256sum \
	"$mac80211_dir/drivers/net/wireless/ath/ath11k/ath11k.ko" \
	"$mac80211_dir/drivers/net/wireless/ath/ath11k/ath11k_ahb.ko" \
	"$mac80211_dir/drivers/net/wireless/ath/ath11k/ath11k_pci.ko" \
	"$candidate_image"
stat -c '%n: %s bytes' "$candidate_image"
echo "RAM-only artifact: $candidate_image"
