# Sources and References

## OpenWrt Guidance

- [Sysupgrade from the command line](https://openwrt.org/docs/guide-user/installation/sysupgrade.cli)
- [Failsafe mode and factory reset](https://openwrt.org/docs/guide-user/troubleshooting/failsafe_and_factory_reset)
- [Vendor-specific rescue](https://openwrt.org/docs/guide-user/troubleshooting/vendor_specific_rescue)

## RG-MA3063 Research

- [Manssizz/build-ma3063](https://github.com/Manssizz/build-ma3063), baseline
  commit `6af78c2bbb57a373fe7355e4ab4550e980899987`
- [hzz0603/lede MA3063 DTS](https://github.com/hzz0603/lede/blob/8e81a17397398033e54eb02e19f88cd1b6294396/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-rg-ma3063.dts)
- [LiBwrt/ipq50xx MA3063 DTS](https://github.com/LiBwrt/ipq50xx/blob/6d5f6e81f174c8f39a49c272005b8263dd7aaaf0/target/linux/qualcommax/files/arch/arm/boot/dts/qcom/ipq5018-ma3063.dts)
- [RG-MA3063 developer-mode and SSH notes](https://github.com/enihsyou/Obsidian-Vault/blob/a904c14a626d5756315ef8a935bb486ebbbb6f58/%E7%BD%91%E7%BB%9C%E7%9B%B8%E5%85%B3/RG-MA3063%20%E5%BC%80%E5%90%AF%20SSH.md)
- [Ruijie RG-MA3063 specifications](https://www.ruijie.com/vi-vn/products/wireless/home-broadband/ma3063)

## Related IPQ5018 Work

- [Gameplayer-1-8/openwrt_mrx80_v2](https://github.com/Gameplayer-1-8/openwrt_mrx80_v2)
- [OpenWrt PR #21495: ath11k smallbuffers variant](https://github.com/openwrt/openwrt/pull/21495)
- [Yanko Yankulov's IPQ5018 ring-size experiment](https://forum.openwrt.org/t/a-simple-patch-to-get-ath11k-working-on-256mib-ram/247147)
- [ath11k RX-buffer OOM analysis](https://github.com/enspect/ath11k-ipq807x-rx-buffer-oom-fix)

## Attribution

This is an independent project. Adapted material retains its existing SPDX
headers. The source links and pinned revisions above record the research
lineage; installation and recovery decisions are based on observed RG-MA3063
hardware behavior and official OpenWrt procedures.
