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
firmware_dir="$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/firmware/ath11k"
baseline_dir="$project_dir/baseline-source/files/firmware"

test -d "$openwrt_dir"
test -d "$dts_dir"
test -f "$device_mk"
test -f "$board_net"
test -d "$baseline_dir/ipq5018"
test -d "$baseline_dir/qcn6122"

cp "$project_dir/files/dts/ipq5018-ruijie-rg-ma3063.dts" "$dts_dir/"

if ! grep -q 'ruijie_rg-ma3063' "$device_mk"; then
	printf '\n' >> "$device_mk"
	cat "$project_dir/files/patches/device-makefile-entry.txt" >> "$device_mk"
fi

if ! grep -q 'ruijie,rg-ma3063' "$board_net"; then
	awk '
		/^[[:space:]]*esac$/ && !inserted {
			print "\truijie,rg-ma3063)"
			print "\t\tucidef_set_interfaces_lan_wan \"lan1 lan2 lan3\" \"wan\""
			print "\t\t;;"
			inserted = 1
		}
		{ print }
	' "$board_net" > "$board_net.tmp"
	mv "$board_net.tmp" "$board_net"
fi

mkdir -p "$firmware_dir/IPQ5018/hw1.0" "$firmware_dir/QCN6122/hw1.0"
cp "$baseline_dir/ipq5018"/bdwlan.* "$firmware_dir/IPQ5018/hw1.0/"
cp "$baseline_dir/ipq5018/bdwlan.b23" "$firmware_dir/IPQ5018/hw1.0/board.bin"
cp "$baseline_dir/qcn6122"/bdwlan.* "$firmware_dir/QCN6122/hw1.0/"
cp "$baseline_dir/qcn6122/bdwlan.b60" "$firmware_dir/QCN6122/hw1.0/board.bin"
cp "$baseline_dir/qcn6122"/m3_fw.* "$firmware_dir/QCN6122/hw1.0/"
cp "$baseline_dir/qcn6122"/q6_fw.* "$firmware_dir/QCN6122/hw1.0/"
