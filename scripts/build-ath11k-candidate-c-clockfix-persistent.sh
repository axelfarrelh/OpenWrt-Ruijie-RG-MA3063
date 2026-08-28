#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <openwrt-source-directory>" >&2
	exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
openwrt_dir=$1
target_dir="$openwrt_dir/bin/targets/qualcommax/ipq50xx"
build_dir="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/linux-qualcommax_ipq50xx"
mac80211_dir="$build_dir/mac80211-regular/backports-6.18.26"
ath11k_dir="$mac80211_dir/drivers/net/wireless/ath/ath11k"
dp_h="$ath11k_dir/dp.h"
dp_rx="$ath11k_dir/dp_rx.c"
core_c="$ath11k_dir/core.c"
dtb="$build_dir/image-ipq5018-ruijie-rg-ma3063.dtb"
root="$openwrt_dir/build_dir/target-aarch64_cortex-a53_musl/root-qualcommax"
tree_dts="$openwrt_dir/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ruijie-rg-ma3063.dts"
files_dir="$openwrt_dir/files"
marker_source="$project_dir/src/experimental/ath11k/candidate-c-clockfix-marker"
marker_target="$files_dir/etc/candidate-c-clockfix"
old_marker_target="$files_dir/etc/candidate-c-persistent"
guard_target="$files_dir/usr/sbin/candidate-c-guard"
guard_init_target="$files_dir/etc/init.d/candidate-c-guard"
guard_rc_target="$files_dir/etc/rc.d/S99candidate-c-guard"
standard_prefix="$target_dir/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063"
source_sysupgrade="$standard_prefix-squashfs-sysupgrade.bin"
source_factory="$standard_prefix-squashfs-factory.ubi"
source_manifest="$standard_prefix.manifest"
artifact_dir="$project_dir/artifacts/candidate-c-persistent-clockfix"
artifact_prefix="$artifact_dir/openwrt-qualcommax-ipq50xx-ruijie_rg-ma3063-ath11k-candidate-c-persistent-clockfix"
artifact_sysupgrade="$artifact_prefix-squashfs-sysupgrade.bin"
artifact_factory="$artifact_prefix-squashfs-factory.ubi"
artifact_kernel="$artifact_prefix-kernel.itb"
artifact_manifest="$artifact_prefix.manifest"
toolchain_dir="$openwrt_dir/staging_dir/toolchain-aarch64_cortex-a53_gcc-14.3.0_musl/bin"
backup_dir=$(mktemp -d)
extract_dir=$(mktemp -d)

test -d "$openwrt_dir"
test -d "$toolchain_dir"
test -f "$marker_source"

backup_file() {
	file=$1
	if [ -e "$file" ] || [ -L "$file" ]; then
		mkdir -p "$backup_dir${file%/*}"
		cp -a "$file" "$backup_dir$file"
	fi
}

restore_file() {
	file=$1
	rm -f "$file"
	if [ -e "$backup_dir$file" ] || [ -L "$backup_dir$file" ]; then
		mkdir -p "${file%/*}"
		cp -a "$backup_dir$file" "$file"
	fi
}

for file in "$marker_target" "$old_marker_target" "$guard_target" "$guard_init_target" \
	"$guard_rc_target" "$source_sysupgrade" "$source_factory" "$source_manifest"; do
	backup_file "$file"
done

cleanup() {
	restore_file "$marker_target"
	restore_file "$old_marker_target"
	restore_file "$guard_target"
	restore_file "$guard_init_target"
	restore_file "$guard_rc_target"
	restore_file "$source_sysupgrade"
	restore_file "$source_factory"
	restore_file "$source_manifest"
	rm -rf "$backup_dir" "$extract_dir"
	ATH11K_RING_EXPERIMENT= "$project_dir/scripts/apply-local-patches.sh" "$openwrt_dir"
	FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" package/kernel/mac80211/clean >/dev/null
	FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" target/linux/clean >/dev/null
	rm -f "$root/etc/candidate-c-clockfix" "$root/etc/candidate-c-persistent" \
		"$root/usr/sbin/candidate-c-guard" "$root/etc/init.d/candidate-c-guard" \
		"$root/etc/rc.d/S99candidate-c-guard"
}
trap cleanup EXIT INT TERM

mkdir -p "${marker_target%/*}"
cp "$marker_source" "$marker_target"
rm -f "$old_marker_target" "$guard_target" "$guard_init_target" "$guard_rc_target"
rm -f "$root/etc/candidate-c-persistent" "$root/usr/sbin/candidate-c-guard" \
	"$root/etc/init.d/candidate-c-guard" "$root/etc/rc.d/S99candidate-c-guard"

export PATH="$toolchain_dir:$openwrt_dir/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ATH11K_RING_EXPERIMENT=candidate-c \
	"$project_dir/scripts/apply-local-patches.sh" "$openwrt_dir"

test "$(grep -c 'qcom,ath11k-fw-memory-mode = <2>;' "$tree_dts")" -eq 2
grep -A2 '^&sleep_clk {' "$tree_dts" | grep -q 'clock-frequency = <32000>;'
grep -A3 '^&xo_board_clk {' "$tree_dts" | grep -q 'clock-mult = <1>;'
grep -A3 '^&xo_board_clk {' "$tree_dts" | grep -q 'clock-div = <4>;'

jobs=${JOBS:-$(nproc)}
FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs" package/kernel/mac80211/clean
FORCE_UNSAFE_CONFIGURE=1 make -C "$openwrt_dir" -j"$jobs"

ATH11K_RING_EXPERIMENT=candidate-c \
	"$project_dir/scripts/verify-image-root.sh" "$openwrt_dir"

test -f "$dp_h"
test -f "$dp_rx"
test -f "$core_c"
test -f "$dtb"
test -f "$source_sysupgrade"
test -f "$source_factory"
test -f "$source_manifest"

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
grep -q 'data = page_frag_alloc(cache, len, gfp_mask);' "$dp_rx"
grep -q 'len = SKB_HEAD_ALIGN(len);' "$dp_rx"
grep -q 'skb = build_skb(data, len);' "$dp_rx"
grep -q 'page_frag_free(data);' "$dp_rx"
grep -A2 -F 'if (!ab->is_reset)' "$core_c" | grep -q 'ath11k_hif_irq_disable(ab);'

test "$(fdtget -t i "$dtb" /soc/wifi@c000000 qcom,ath11k-fw-memory-mode)" -eq 2
test "$(fdtget -t i "$dtb" /soc/wifi@b00a040 qcom,ath11k-fw-memory-mode)" -eq 2
test "$(fdtget -t x "$dtb" /reserved-memory/wcss@4b000000 reg)" = "0 4b000000 0 3000000"
test "$(fdtget -t i "$dtb" /clocks/sleep-clk clock-frequency)" -eq 32000
test "$(fdtget -t i "$dtb" /clocks/xo-board-clk clock-mult)" -eq 1
test "$(fdtget -t i "$dtb" /clocks/xo-board-clk clock-div)" -eq 4

cmp -s "$marker_source" "$root/etc/candidate-c-clockfix"
test ! -e "$root/etc/candidate-c-persistent"
test ! -e "$root/usr/sbin/candidate-c-guard"
test ! -e "$root/etc/init.d/candidate-c-guard"
test ! -e "$root/etc/rc.d/S99candidate-c-guard"

tar -xf "$source_sysupgrade" -C "$extract_dir"
test -f "$extract_dir/sysupgrade-ruijie_rg-ma3063/kernel"
test -f "$extract_dir/sysupgrade-ruijie_rg-ma3063/root"
test "$(fdtget -t s "$extract_dir/sysupgrade-ruijie_rg-ma3063/kernel" /configurations default)" = "config@mp03.5-c1"
unsquashfs -cat "$extract_dir/sysupgrade-ruijie_rg-ma3063/root" etc/candidate-c-clockfix |
	cmp -s - "$marker_source"
root_listing="$extract_dir/root-listing.txt"
unsquashfs -ll "$extract_dir/sysupgrade-ruijie_rg-ma3063/root" > "$root_listing"
! grep -q '/etc/candidate-c-persistent$' "$root_listing"
! grep -q '/usr/sbin/candidate-c-guard$' "$root_listing"
! grep -q '/etc/init.d/candidate-c-guard$' "$root_listing"
! grep -q '/etc/rc.d/S99candidate-c-guard' "$root_listing"

mkdir -p "$artifact_dir"
cp "$source_sysupgrade" "$artifact_sysupgrade"
cp "$source_factory" "$artifact_factory"
cp "$extract_dir/sysupgrade-ruijie_rg-ma3063/kernel" "$artifact_kernel"
cp "$source_manifest" "$artifact_manifest"

echo "Candidate C persistent clock-fix image verified without guard service."
echo "Artifact hashes:"
sha256sum "$artifact_kernel" "$artifact_factory" "$artifact_sysupgrade"
stat -c '%n: %s bytes' "$artifact_kernel" "$artifact_factory" "$artifact_sysupgrade"
