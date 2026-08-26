# Known Issues

## ath11k Memory Pressure

With both radios loaded, the installed system has about 185 MiB total Linux RAM
and typically 20-25 MiB available. Unloading `ath11k_pci` and `ath11k_ahb`
recovers roughly 80 MiB, confirming that radio firmware, DMA rings, and ath11k
host allocations dominate consumption.

The current driver still uses full upstream ring sizes. Reduced-ring variants
for 256 MiB IPQ5018/QCN6122 devices report gains of roughly 35-55 MiB. This
project will test ring changes in RAM before changing the persistent baseline.

Until then:

- Avoid memory-heavy services.
- Stop and unload both radios before placing a sysupgrade image in `/tmp`.
- Do not treat zram as a fix for DMA or firmware memory.

## Watchdog and CPU Frequency

The boot log contains nonfatal warnings:

```text
qcom_wdt: failed to get input clock
cpufreq-dt: failed register driver
```

The system boots and routes traffic, but watchdog and frequency scaling need
separate DTS/clock work.

## U-Boot Environment Tools

Board setup reads `ethaddr` using a temporary known-good configuration. A
persistent `/etc/fw_env.config` is not currently installed, so direct
`fw_printenv` can fail. Do not use `fw_setenv`.

## Duplicate UBI Arguments

OEM U-Boot prepends its own root contract and the OpenWrt DT appends the proven
ubiblock contract. A second UBI attach attempt may log an error after the block
device is already created. Root mounting succeeds.

## SSDK Notifications

SSDK can log `netdev change notify with incorrect port 0`. qca8k owns the
external switch and Ethernet remains functional; the message is nonfatal.

## U-Boot Environment Write

OEM U-Boot erases and writes its APPSBLENV area during normal autoboot as part
of boot-attempt accounting. This is OEM behavior, not an OpenWrt flash write.

## LEDs

LED GPIOs have not been implemented or validated.
