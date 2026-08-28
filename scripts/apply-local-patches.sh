#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <openwrt-source-directory>" >&2
	exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
openwrt_dir=$1
dts_dir="$openwrt_dir/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom"
device_mk="$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
board_net="$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
wifi_defaults="$openwrt_dir/files/etc/uci-defaults/99-ma3063-disable-wifi"
caldata_hook="$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/hotplug.d/firmware/11-ath11k-caldata"
uboot_env="$openwrt_dir/package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq50xx"
firmware_dir="$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/firmware/ath11k"
firmware_overlay="$openwrt_dir/files/lib/firmware/ath11k"
firmware_source="$project_dir/router-data/bdf"
qcn6122_bdf="$openwrt_dir/files/lib/firmware/ath11k/QCN6122/hw1.0/bdwlan.b60"
kernel_patch_dir="$openwrt_dir/target/linux/qualcommax/patches-6.12"
ath11k_patch_dir="$openwrt_dir/package/kernel/mac80211/patches/ath11k"
ath11k_experiment=${ATH11K_RING_EXPERIMENT:-}
ath11k_candidate_a="$project_dir/src/experimental/ath11k/949-ath11k-reduce-rx-monitor-rings-candidate-a.patch"
ath11k_candidate_a_target="$ath11k_patch_dir/949-ath11k-reduce-rx-monitor-rings-candidate-a.patch"
ath11k_candidate_b="$project_dir/src/experimental/ath11k/949-ath11k-reduce-rings-candidate-b.patch"
ath11k_candidate_b_target="$ath11k_patch_dir/949-ath11k-reduce-rings-candidate-b.patch"
ath11k_candidate_c_rings="$project_dir/src/experimental/ath11k/949-ath11k-oem-like-rings-candidate-c.patch"
ath11k_candidate_c_rings_target="$ath11k_patch_dir/949-ath11k-oem-like-rings-candidate-c.patch"
ath11k_candidate_c_cache="$project_dir/src/experimental/ath11k/950-ath11k-private-rxdma-page-frag-candidate-c.patch"
ath11k_candidate_c_cache_target="$ath11k_patch_dir/950-ath11k-private-rxdma-page-frag-candidate-c.patch"
ssdk_mk="$openwrt_dir/package/kernel/qca-ssdk/Makefile"
image_patch="$project_dir/src/patches/1000-image-oem-volume-layout.patch"
oem_volume_source="$project_dir/router-data/oem-volumes"
oem_volume_dir="$openwrt_dir/target/linux/qualcommax/image/rg-ma3063-oem"

# Accept the original research workspace layout without making it part of the
# public build contract.
[ -d "$firmware_source" ] || firmware_source="$project_dir/router-data/stock-wifi-fw"
if [ ! -f "$oem_volume_source/wifi_fw.bin" ]; then
	oem_volume_source="$project_dir/router-data/stock-rootfs-mtd15/rootfs-mtd15.bin"
	oem_wifi_volume="$oem_volume_source/img-880995722_vol-wifi_fw.ubifs"
	oem_bt_volume="$oem_volume_source/img-880995722_vol-bt_fw.ubifs"
else
	oem_wifi_volume="$oem_volume_source/wifi_fw.bin"
	oem_bt_volume="$oem_volume_source/bt_fw.bin"
fi

test -d "$openwrt_dir"
test -d "$dts_dir"
test -f "$device_mk"
test -f "$board_net"
test -f "$caldata_hook"
test -f "$uboot_env"
test -f "$firmware_source/bdwlan.b23"
test -f "$firmware_source/qcn6122/bdwlan.b60"
test -d "$kernel_patch_dir"
test -d "$ath11k_patch_dir"
test -f "$ssdk_mk"
test -f "$image_patch"
test -f "$oem_wifi_volume"
test -f "$oem_bt_volume"

case "$ath11k_experiment" in
	"")
		rm -f "$ath11k_candidate_a_target" "$ath11k_candidate_b_target" \
			"$ath11k_candidate_c_rings_target" "$ath11k_candidate_c_cache_target"
		;;
	candidate-a)
		rm -f "$ath11k_candidate_b_target" "$ath11k_candidate_c_rings_target" \
			"$ath11k_candidate_c_cache_target"
		test -f "$ath11k_candidate_a"
		cp "$ath11k_candidate_a" "$ath11k_candidate_a_target"
		;;
	candidate-b)
		rm -f "$ath11k_candidate_a_target" "$ath11k_candidate_c_rings_target" \
			"$ath11k_candidate_c_cache_target"
		test -f "$ath11k_candidate_b"
		cp "$ath11k_candidate_b" "$ath11k_candidate_b_target"
		;;
	candidate-c)
		rm -f "$ath11k_candidate_a_target" "$ath11k_candidate_b_target"
		test -f "$ath11k_candidate_c_rings"
		test -f "$ath11k_candidate_c_cache"
		cp "$ath11k_candidate_c_rings" "$ath11k_candidate_c_rings_target"
		cp "$ath11k_candidate_c_cache" "$ath11k_candidate_c_cache_target"
		;;
	*)
		echo "Unknown ATH11K_RING_EXPERIMENT: $ath11k_experiment" >&2
		exit 1
		;;
esac

if grep -q 'UBI_KERNEL_FIRST UBI_KERNEL_STATIC UBI_ROOTFS_NAME' "$openwrt_dir/include/image.mk" &&
	grep -q -- '--rootfs-name $(UBI_ROOTFS_NAME)' "$openwrt_dir/include/image-commands.mk" &&
	grep -q '"--rootfs-name")' "$openwrt_dir/scripts/ubinize-image.sh" &&
	grep -q 'CI_KERN_VOLTYPE=' "$openwrt_dir/package/base-files/files/lib/upgrade/nand.sh"; then
	:
elif patch --dry-run --forward --batch -s -p1 -d "$openwrt_dir" < "$image_patch" >/dev/null 2>&1; then
	patch --forward --batch -p1 -d "$openwrt_dir" < "$image_patch"
else
	echo "Image patch does not match the OpenWrt tree" >&2
	exit 1
fi

cp "$project_dir/src/new/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ruijie-rg-ma3063.dts" "$dts_dir/"
if [ "$ath11k_experiment" = candidate-c ]; then
	sed -i 's/qcom,ath11k-fw-memory-mode = <1>;/qcom,ath11k-fw-memory-mode = <2>;/g' \
		"$dts_dir/ipq5018-ruijie-rg-ma3063.dts"
	test "$(grep -c 'qcom,ath11k-fw-memory-mode = <2>;' \
		"$dts_dir/ipq5018-ruijie-rg-ma3063.dts")" -eq 2
fi
cp "$project_dir/src/new/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network" "$board_net"
chmod 0755 "$board_net"
mkdir -p "${wifi_defaults%/*}"
cp "$project_dir/src/new/files/etc/uci-defaults/99-ma3063-disable-wifi" "$wifi_defaults"
chmod 0755 "$wifi_defaults"
rm -f "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/init.d/fix-eth-mac"
rm -f "$kernel_patch_dir/0913-net-dsa-qca8k-retry-switch-id-read.patch"
rm -f "$kernel_patch_dir/0914-net-mdio-ipq4019-log-mdc-configuration.patch"
rm -f "$kernel_patch_dir/0913-net-dsa-qca8k-accept-rg-ma3063-switch-id.patch"
rm -f "$kernel_patch_dir/0915-net-mdio-ipq4019-set-rg-ma3063-qsdk-mode.patch"
rm -f "$kernel_patch_dir/0915-net-dsa-qca8k-rg-ma3063-reset-timing.patch"
rm -f "$kernel_patch_dir/0914-net-mdio-ipq4019-diagnose-rg-ma3063-receive.patch"
cp "$project_dir/src/new/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch" \
	"$kernel_patch_dir/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch"

# Upgrade only the OpenWrt volumes in rootfs. The OEM firmware volumes remain
# at IDs 1 and 2 while kernel, ubi_rootfs, and rootfs_data retain IDs 0, 3, 4.
awk '
	/^\truijie,rg-ma3063\)$/ { skip = 1; next }
	skip && /^\t\t;;$/ { skip = 0; next }
	/^\t\*\)$/ && !inserted {
		print "\truijie,rg-ma3063)"
		print "\t\tCI_UBIPART=\"rootfs\""
		print "\t\tCI_KERNPART=\"kernel\""
		print "\t\tCI_KERN_VOLTYPE=\"static\""
		print "\t\tCI_ROOTPART=\"ubi_rootfs\""
		print "\t\tnand_do_upgrade \"$1\""
		print "\t\t;;"
		inserted = 1
	}
	!skip { print }
' "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh" \
	> "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh.tmp"
mv "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh.tmp" \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh"

mkdir -p "$oem_volume_dir"
cp "$oem_wifi_volume" "$oem_volume_dir/wifi_fw.bin"
cp "$oem_bt_volume" "$oem_volume_dir/bt_fw.bin"

# qca8k owns the external switch; retain SSDK only for the IPQ5018 dataplane.
sed -i 's/ISISC_ENABLE=enable MHT_ENABLE=disable/ISISC_ENABLE=disable MHT_ENABLE=disable/' "$ssdk_mk"

awk '
	/^define Device\/ruijie_rg-ma3063$/ { skip = 1; next }
	skip && /^TARGET_DEVICES \+= ruijie_rg-ma3063$/ { skip = 0; next }
	!skip { print }
' "$device_mk" > "$device_mk.tmp"
printf '\n' >> "$device_mk.tmp"
cat "$project_dir/src/device-makefile-entry.txt" >> "$device_mk.tmp"
mv "$device_mk.tmp" "$device_mk"

awk '
	/^ruijie,rg-ma3063\|\\$/ { next }
	/^ruijie,rg-ma3063\)$/ { skip = 1; next }
	skip && /^\t;;$/ { skip = 0; next }
	/^glinet,gl-b3000\)/ && !inserted {
		print "ruijie,rg-ma3063)"
		print "\tubootenv_add_mtd \"0:APPSBLENV\" \"0x0\" \"0x40000\" \"0x20000\""
		print "\t;;"
		inserted = 1
	}
	!skip { print }
' "$uboot_env" > "$uboot_env.tmp"
mv "$uboot_env.tmp" "$uboot_env"

if ! grep -q 'ruijie,rg-ma3063' "$caldata_hook"; then
	awk '
		/^[[:space:]]*glinet,gl-b3000\)/ {
			if (seen == 0) {
				print "\truijie,rg-ma3063)"
				print "\t\tcaldata_extract \"0:ART\" 0x1000 0x20000"
				print "\t\t;;"
			} else if (seen == 1) {
				print "\truijie,rg-ma3063)"
				print "\t\tcaldata_extract \"0:ART\" 0x26800 0x20000"
				print "\t\t;;"
			}
			seen++
		}
		{ print }
	' "$caldata_hook" > "$caldata_hook.tmp"
	mv "$caldata_hook.tmp" "$caldata_hook"
fi

mkdir -p "$firmware_dir/IPQ5018/hw1.0" "$firmware_dir/QCN6122/hw1.0"
mkdir -p "$firmware_overlay/QCN6122/hw1.0"
# Never let a prior OEM DSP experiment override the OpenWrt firmware package.
rm -f "$firmware_dir/IPQ5018/hw1.0"/m3_fw.* "$firmware_dir/IPQ5018/hw1.0"/q6_fw.*
rm -f "$firmware_dir/QCN6122/hw1.0"/m3_fw.* "$firmware_dir/QCN6122/hw1.0"/q6_fw.*
rm -f "$firmware_overlay/QCN6122/hw1.0"/m3_fw.* "$firmware_overlay/QCN6122/hw1.0"/q6_fw.*
# The matched ath11k-firmware-ipq5018-qcn6122 package supplies Q6 and M3
# firmware. Keep the router-specific BDF files only.
cp "$firmware_source"/bdwlan.* "$firmware_dir/IPQ5018/hw1.0/"
cp "$firmware_source/bdwlan.b23" "$firmware_dir/IPQ5018/hw1.0/board.bin"
cp "$firmware_source/qcn6122"/bdwlan.* "$firmware_dir/QCN6122/hw1.0/"
python3 "$project_dir/tools/convert-qcn6122-bdf-2.7.py" \
	"$firmware_source/qcn6122/bdwlan.b60" "$qcn6122_bdf"
cp "$qcn6122_bdf" "$firmware_overlay/QCN6122/hw1.0/board.bin"

# This target uses NAND sysupgrade archives; reject malformed or mismatched images.
awk '
	/^platform_check_image\(\) \{/ { print; print "\tlocal board=$(board_name)"; print ""; print "\tnand_do_platform_check \"$board\" \"$1\""; print "\treturn $?"; skip = 1; next }
	skip && /^\}/ { skip = 0; print; next }
	!skip { print }
' "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh" \
	> "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh.tmp"
mv "$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh.tmp" \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh"
