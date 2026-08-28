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
ath11k_dir="$mac80211_dir/drivers/net/wireless/ath/ath11k"
dp_h="$ath11k_dir/dp.h"
dp_rx="$ath11k_dir/dp_rx.c"
core_c="$ath11k_dir/core.c"
dtb="$build_dir/image-ipq5018-ruijie-rg-ma3063.dtb"
target_dir="$openwrt_dir/bin/targets/qualcommax/ipq50xx"
source_image="$target_dir/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-initramfs-uImage.itb"
candidate_image="$target_dir/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-ath11k-candidate-c-switchroot-initramfs-uImage.itb"
switchroot_init="$project_dir/src/experimental/ath11k/candidate-c-switchroot-init"
normal_init="$openwrt_dir/target/linux/generic/other-files/init"
root_init="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/root-qualcommax/init"
tree_dts="$openwrt_dir/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ruijie-rg-ma3063.dts"
candidate_a="$openwrt_dir/package/kernel/mac80211/patches/ath11k/949-ath11k-reduce-rx-monitor-rings-candidate-a.patch"
candidate_b="$openwrt_dir/package/kernel/mac80211/patches/ath11k/949-ath11k-reduce-rings-candidate-b.patch"
candidate_c_rings="$openwrt_dir/package/kernel/mac80211/patches/ath11k/949-ath11k-oem-like-rings-candidate-c.patch"
candidate_c_cache="$openwrt_dir/package/kernel/mac80211/patches/ath11k/950-ath11k-private-rxdma-page-frag-candidate-c.patch"
toolchain_dir="$openwrt_dir/staging_dir/toolchain-aarch64_cortex-a53_gcc-14.3.0_musl/bin"
normal_init_backup=$(mktemp)

test -d "$openwrt_dir"
test -f "$switchroot_init"
test -f "$normal_init"
test -d "$toolchain_dir"
cp "$normal_init" "$normal_init_backup"

cleanup() {
	rm -f "$candidate_a" "$candidate_b" "$candidate_c_rings" "$candidate_c_cache"
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

ATH11K_RING_EXPERIMENT=candidate-c \
	"$project_dir/scripts/apply-local-patches.sh" "$openwrt_dir"

test "$(grep -c 'qcom,ath11k-fw-memory-mode = <2>;' "$tree_dts")" -eq 2
! grep -q 'qcom,ath11k-fw-memory-mode = <1>;' "$tree_dts"

jobs=${JOBS:-$(nproc)}
FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" package/kernel/mac80211/clean

ATH11K_RING_EXPERIMENT=candidate-c \
	INITRAMFS_INIT_OVERRIDE="$switchroot_init" \
	"$project_dir/scripts/rebuild-initramfs.sh" "$openwrt_dir"

test -f "$dp_h"
test -f "$dp_rx"
test -f "$core_c"
test -f "$dtb"

check_define() {
	name=$1
	value=$2
	grep -Eq "^#define[[:space:]]+$name[[:space:]]+$value$" "$dp_h" || {
		echo "Unexpected $name in $dp_h" >&2
		exit 1
	}
}

check_define DP_TX_COMP_RING_SIZE 8192
check_define DP_TX_IDR_SIZE DP_TX_COMP_RING_SIZE
check_define DP_RXDMA_BUF_RING_SIZE 1024
check_define DP_RXDMA_REFILL_RING_SIZE 2048
check_define DP_RXDMA_ERR_DST_RING_SIZE 1024
check_define DP_RXDMA_MON_STATUS_RING_SIZE 512
check_define DP_RXDMA_MONITOR_BUF_RING_SIZE 128
check_define DP_RXDMA_MONITOR_DST_RING_SIZE 128
check_define DP_RXDMA_MONITOR_DESC_RING_SIZE 4096

test "$(grep -c 'struct page_frag_cache frag_cache;' "$dp_h")" -eq 1
test "$(grep -c 'ath11k_dp_rx_alloc_skb(rx_ring, DP_RX_BUFFER_SIZE +' "$dp_rx")" -eq 2
test "$(grep -c 'page_frag_cache_drain(&rx_ring->frag_cache);' "$dp_rx")" -eq 1
test "$(grep -c 'skb_reserve(skb, PTR_ALIGN' "$dp_rx")" -eq 1
test "$(grep -c 'skb_reserve(skb,$' "$dp_rx")" -ge 1
grep -q 'data = page_frag_alloc(cache, len, gfp_mask);' "$dp_rx"
grep -q 'len = SKB_HEAD_ALIGN(len);' "$dp_rx"
grep -q 'skb = build_skb(data, len);' "$dp_rx"
grep -q 'page_frag_free(data);' "$dp_rx"
! grep -A2 -F 'dev_alloc_skb(DP_RX_BUFFER_SIZE +' "$dp_rx" | grep -q DP_RX_BUFFER_ALIGN_SIZE
grep -A2 -F 'if (!ab->is_reset)' "$core_c" | grep -q 'ath11k_hif_irq_disable(ab);'

test "$(fdtget -t i "$dtb" /soc/wifi@c000000 qcom,ath11k-fw-memory-mode)" -eq 2
test "$(fdtget -t i "$dtb" /soc/wifi@b00a040 qcom,ath11k-fw-memory-mode)" -eq 2
test "$(fdtget -t x "$dtb" /reserved-memory/wcss@4b000000 reg)" = "0 4b000000 0 3000000"
test "$(fdtget -t x "$dtb" /soc/wifi@c000000 qcom,bdf-addr)" = "4c400000"
test "$(fdtget -t x "$dtb" /soc/wifi@b00a040 qcom,bdf-addr)" = "4d100000"
test "$(fdtget -t x "$dtb" /soc/wifi@b00a040 qcom,m3-dump-addr)" = "4df00000"

test -f "$ath11k_dir/ath11k.ko"
test -f "$ath11k_dir/ath11k_ahb.ko"
test -f "$ath11k_dir/ath11k_pci.ko"
test -f "$source_image"
cmp -s "$switchroot_init" "$root_init"
grep -q 'trip "MemAvailable below 24576 kB"' "$root_init"
grep -q 'trip "fatal kernel or ath11k message detected"' "$root_init"
! grep -q 'MemAvailable lost more than 8192 kB in 60 seconds' "$root_init"

test "$(fdtget -t s "$source_image" /configurations default)" = "config@mp03.5-c1"
cp "$source_image" "$candidate_image"

echo "Candidate C rings, firmware mode 2, and private RXDMA caches verified."
echo "Patch hashes:"
sha256sum \
	"$project_dir/src/experimental/ath11k/949-ath11k-oem-like-rings-candidate-c.patch" \
	"$project_dir/src/experimental/ath11k/950-ath11k-private-rxdma-page-frag-candidate-c.patch"
echo "Module and image hashes:"
sha256sum \
	"$ath11k_dir/ath11k.ko" \
	"$ath11k_dir/ath11k_ahb.ko" \
	"$ath11k_dir/ath11k_pci.ko" \
	"$candidate_image"
stat -c '%n: %s bytes' "$candidate_image"
echo "RAM-only artifact: $candidate_image"
