#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <openwrt-source-directory>" >&2
	exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
openwrt_dir=$1
target_base="build_dir/target-aarch64_cortex-a53_musl"
pristine="$openwrt_dir/$target_base/root.orig-qualcommax"
root="$openwrt_dir/$target_base/root-qualcommax"
firmware_path="lib/firmware/ath11k"
oem_volume_source="$project_dir/router-data/oem-volumes"

if [ ! -f "$oem_volume_source/wifi_fw.bin" ]; then
	oem_volume_source="$project_dir/router-data/stock-rootfs-mtd15/rootfs-mtd15.bin"
	oem_wifi_volume="$oem_volume_source/img-880995722_vol-wifi_fw.ubifs"
	oem_bt_volume="$oem_volume_source/img-880995722_vol-bt_fw.ubifs"
else
	oem_wifi_volume="$oem_volume_source/wifi_fw.bin"
	oem_bt_volume="$oem_volume_source/bt_fw.bin"
fi

test -d "$pristine/$firmware_path/IPQ5018/hw1.0"
test -d "$pristine/$firmware_path/QCN6122/hw1.0"
test -d "$root/$firmware_path/IPQ5018/hw1.0"
test -d "$root/$firmware_path/QCN6122/hw1.0"

# All DSP firmware must remain byte-identical to the installed OpenWrt package.
for radio in IPQ5018 QCN6122; do
	for source in "$pristine/$firmware_path/$radio/hw1.0"/Notice.txt \
		"$pristine/$firmware_path/$radio/hw1.0"/m3_fw.* \
		"$pristine/$firmware_path/$radio/hw1.0"/q6_fw.*; do
		[ -f "$source" ] || continue
		name=${source##*/}
		cmp -s "$source" "$root/$firmware_path/$radio/hw1.0/$name" || {
			echo "Firmware mismatch: $radio/hw1.0/$name" >&2
			exit 1
		}
	done
done

check_hash() {
	expected=$1
	file=$2
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || {
		echo "Hash mismatch: $file" >&2
		echo "Expected: $expected" >&2
		echo "Actual:   $actual" >&2
		exit 1
	}
}

check_hash e0eea9f4f7517c4360f03e91e83bd142c830e9d10ac5d46bfe9652db51880832 \
	"$root/$firmware_path/IPQ5018/hw1.0/board.bin"
check_hash f6f905994c74a81daaa6e5186a6463aa89dd3184819d82be2c8fc554286ea254 \
	"$root/$firmware_path/QCN6122/hw1.0/board.bin"
check_hash f6f905994c74a81daaa6e5186a6463aa89dd3184819d82be2c8fc554286ea254 \
	"$root/$firmware_path/QCN6122/hw1.0/bdwlan.b60"

hook="$root/etc/hotplug.d/firmware/11-ath11k-caldata"
test "$(grep -c 'ruijie,rg-ma3063)' "$hook")" -eq 2
grep -q 'caldata_extract "0:ART" 0x1000 0x20000' "$hook"
grep -q 'caldata_extract "0:ART" 0x26800 0x20000' "$hook"

tree_dts="$openwrt_dir/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ruijie-rg-ma3063.dts"
platform_upgrade="$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh"
wifi_defaults="$root/etc/uci-defaults/99-ma3063-disable-wifi"
cmp -s "$project_dir/src/new/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ruijie-rg-ma3063.dts" "$tree_dts"
cmp -s "$project_dir/src/new/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network" \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
cmp -s "$project_dir/src/new/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network" "$root/etc/board.d/02_network"
test -x "$root/etc/board.d/02_network"
cmp -s "$project_dir/src/new/files/etc/uci-defaults/99-ma3063-disable-wifi" "$wifi_defaults"
test -x "$wifi_defaults"
grep -q 'config_foreach disable_radio wifi-device' "$wifi_defaults"
grep -q 'uci set "wireless.$1.disabled=1"' "$wifi_defaults"
! grep -q 'board_name' "$wifi_defaults"
test ! -e "$root/etc/init.d/fix-eth-mac"
test ! -e "$root/etc/rc.d/S19fix-eth-mac"
test ! -e "$openwrt_dir/target/linux/qualcommax/patches-6.12/0913-net-dsa-qca8k-retry-switch-id-read.patch"
test ! -e "$openwrt_dir/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-log-mdc-configuration.patch"
test ! -e "$openwrt_dir/target/linux/qualcommax/patches-6.12/0913-net-dsa-qca8k-accept-rg-ma3063-switch-id.patch"
test ! -e "$openwrt_dir/target/linux/qualcommax/patches-6.12/0915-net-mdio-ipq4019-set-rg-ma3063-qsdk-mode.patch"
test ! -e "$openwrt_dir/target/linux/qualcommax/patches-6.12/0915-net-dsa-qca8k-rg-ma3063-reset-timing.patch"
test ! -e "$openwrt_dir/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-diagnose-rg-ma3063-receive.patch"
cmp -s "$project_dir/src/new/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch" \
	"$openwrt_dir/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch"
grep -q 'ISISC_ENABLE=disable MHT_ENABLE=disable' "$openwrt_dir/package/kernel/qca-ssdk/Makefile"
grep -q '^CONFIG_PACKAGE_ath11k-firmware-ipq5018-qcn6122=y$' "$openwrt_dir/.config"
grep -q '^CONFIG_PACKAGE_kmod-qca-nss-dp=y$' "$openwrt_dir/.config"
grep -q '^CONFIG_PACKAGE_kmod-qca-ssdk=y$' "$openwrt_dir/.config"
test -f "$root/lib/modules/6.12.94/qca-ssdk.ko"
test -f "$root/lib/modules/6.12.94/qca-nss-dp.ko"
test -x "$root/etc/init.d/uhttpd"
test -x "$root/etc/init.d/rpcd"
test -e "$root/www/cgi-bin/luci"
test -f "$root/usr/lib/rpcd/luci.so"
test -e "$root/usr/share/rpcd/ucode/luci"
test -f "$root/usr/lib/uhttpd_ubus.so"
! grep -q 'isisc_init' "$root/lib/modules/6.12.94/qca-ssdk.ko"
grep -q '^qca-ssdk$' "$root/etc/modules.d/30-qca-ssdk"
grep -q '^qca-nss-dp$' "$root/etc/modules.d/31-qca-nss-dp"
! grep -q 'compatible = "qcom,ess-switch-qca83xx"' "$tree_dts"
grep -q 'compatible = "qca,qca8337"' "$tree_dts"
grep -q 'reset-gpios = <&tlmm 26 GPIO_ACTIVE_LOW>;' "$tree_dts"
grep -q 'root=/dev/ubiblock0_3' "$tree_dts"
grep -q 'ubi.mtd=rootfs' "$tree_dts"
grep -q 'ubi.block=0,3' "$tree_dts"
grep -q 'rootfstype=squashfs rootwait' "$tree_dts"
! grep -q 'root=mtd:ubi_rootfs' "$tree_dts"
! grep -q 'reset_gpio' "$tree_dts"
grep -q 'switch1: ethernet-switch@17' "$tree_dts"
grep -q 'reg = <17>;' "$tree_dts"
grep -q 'port@1 { reg = <1>; label = "lan1";' "$tree_dts"
grep -q 'port@2 { reg = <2>; label = "lan2";' "$tree_dts"
grep -q 'port@3 { reg = <3>; label = "lan3";' "$tree_dts"
! grep -q 'port@4' "$tree_dts"
! grep -q 'qca8337_phy3\|qca8337_phy4' "$tree_dts"
grep -q 'val |= MDIO_MODE_DIV(64);' \
	"$openwrt_dir/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch"
! grep -q 'priv->mdc_rate = 1562500;' \
	"$openwrt_dir/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch"
! grep -q 'RG-MA3063 MDIO1\|diagnostic_reads' \
	"$openwrt_dir/target/linux/qualcommax/patches-6.12/0914-net-mdio-ipq4019-set-rg-ma3063-div64.patch"
grep -q 'DEVICE_DTS_CONFIG := config@mp03.5-c1' "$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
grep -q '^CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_ruijie_rg-ma3063=y$' "$openwrt_dir/.config"
grep -q '^[[:space:]]*ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "eth0"$' \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
grep -q 'label_mac=$(fw_printenv -c "$envcfg" -n ethaddr' \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
grep -q 'printf "%s 0x0 0x40000 0x20000\\n" "$envdev" > "$envcfg"' \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
grep -q 'ucidef_set_interface_macaddr "wan" "$label_mac"' \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
grep -q 'ucidef_set_interface_macaddr "lan" "$lan_mac"' \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
grep -q 'ucidef_set_network_device_mac "eth1" "$lan_mac"' \
	"$openwrt_dir/target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network"
grep -q '^[[:space:]]*ubootenv_add_mtd "0:APPSBLENV" "0x0" "0x40000" "0x20000"$' \
	"$openwrt_dir/package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq50xx"
ma3063_upgrade=$(grep -A7 'ruijie,rg-ma3063)' "$platform_upgrade")
printf '%s\n' "$ma3063_upgrade" | grep -q 'CI_UBIPART="rootfs"'
printf '%s\n' "$ma3063_upgrade" | grep -q 'CI_KERNPART="kernel"'
printf '%s\n' "$ma3063_upgrade" | grep -q 'CI_KERN_VOLTYPE="static"'
printf '%s\n' "$ma3063_upgrade" | grep -q 'CI_ROOTPART="ubi_rootfs"'
printf '%s\n' "$ma3063_upgrade" | grep -q 'nand_do_upgrade "$1"'
! printf '%s\n' "$ma3063_upgrade" | grep -q 'remove_oem_ubi_volume'
grep -q 'nand_do_platform_check "$board" "$1"' "$platform_upgrade"
grep -q 'UBI_KERNEL_FIRST := 1' "$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
grep -q 'UBI_KERNEL_STATIC := 1' "$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
grep -q 'UBI_ROOTFS_NAME := ubi_rootfs' "$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
grep -q 'wifi_fw=:' "$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
grep -q 'bt_fw=:' "$openwrt_dir/target/linux/qualcommax/image/ipq50xx.mk"
cmp -s "$oem_wifi_volume" \
	"$openwrt_dir/target/linux/qualcommax/image/rg-ma3063-oem/wifi_fw.bin"
cmp -s "$oem_bt_volume" \
	"$openwrt_dir/target/linux/qualcommax/image/rg-ma3063-oem/bt_fw.bin"

echo "Image root provenance verified."
