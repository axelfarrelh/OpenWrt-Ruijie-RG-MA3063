# Known Issues

## ath11k Memory Pressure

The original mode-1 build used full upstream ring sizes and typically left only
20-25 MiB available with both radios loaded. Unloading `ath11k_pci` and
`ath11k_ahb` recovered roughly 80 MiB, confirming that radio firmware, DMA
rings, and ath11k host allocations dominated consumption.

The deployed Candidate C profile leaves about 59-62 MiB available at idle and
about 48-51 MiB during sustained traffic. It remains opt-in because its three
changes establish combined sufficiency but do not identify which individual
change is necessary. The normal build path still removes all Candidate patches
and uses firmware memory mode 1.

Candidate A changes only:

```text
DP_RXDMA_BUF_RING_SIZE          4096 -> 2048
DP_RXDMA_MONITOR_BUF_RING_SIZE  4096 -> 128
DP_RXDMA_MONITOR_DST_RING_SIZE  2048 -> 128
```

The TX completion, RX refill, monitor status, and monitor descriptor ring sizes
remain unchanged. See `docs/building.md` for the opt-in RAM-only build command.

The first Candidate A initramfs run verified both radios, AP association, DHCP,
the intended firmware-visible ring sizes, and a 30-second 5 GHz TCP upload at
94.4 Mbit/s with zero retransmissions. A reverse test then exhausted memory and
ended in a kernel panic. The initramfs root accounted for about 39 MiB of shmem,
so this result rejects the initramfs as a stress-test environment but does not
isolate Candidate A from that overhead. Candidate A must next be tested by
temporarily replacing the ath11k modules in RAM on the installed SquashFS
baseline. It must not be written to NAND unless that module-only test passes.

The module-only approach is not usable on this platform. After cleanly
unloading `ath11k_pci`, `ath11k_ahb`, and `ath11k`, reloading the AHB transport
left the shared WCSS remote processor unable to restart. The parent and user PD
boots timed out with `-110`, followed by an unbalanced IRQ warning. A normal
reboot restored both radios. Do not hot-reload ath11k for further ring tests.
Any conclusive test now requires a cold-booted non-initramfs Candidate A image.

The first switch-root image exited before mounting the installed root because
BusyBox `sleep` rejected a fractional delay in PID 1. The kernel rebooted
automatically and the installed baseline remained intact. The corrected early
init uses whole-second polling; obsolete switch-root artifact hashes must not be
reused.

A manually completed switch-root run established the valid Candidate A result:

```text
MemAvailable, radios loaded:  55532 kB
MemAvailable, both APs:       42380 kB
After 30 s reverse traffic:   41592 kB
5 GHz TCP upload:             91.8 Mbit/s, 0 retransmissions
5 GHz TCP download:           93.4 Mbit/s
RXDMA/ring-full/backpressure: 0
```

The test used the installed SquashFS read-only with a tmpfs upper layer and did
not mount the persistent UBIFS overlay. Candidate A passed these short-load
checks; a longer sustained run and an independent cold boot are still required
before considering a persistent image.

Candidate A failed the sustained-load gate. During a 30-minute 5 GHz reverse
TCP test, throughput held around 92-94 Mbit/s for roughly two minutes, then
`MemAvailable` fell from about 43 MiB to less than 1 MiB. The kernel OOM-killed
hostapd and both APs went down. Slab and shmem stayed approximately flat, so the
growth was outside normal userspace and reclaimable cache accounting. Candidate
A is rejected and must not be used in a persistent image.

Candidate B additionally reduced `DP_TX_COMP_RING_SIZE` from 32768 to 8192. In
the same RAM-only switch-root environment it increased initial `MemAvailable`
to about 47 MiB with both APs active, roughly 5.5 MiB more than Candidate A.
During sustained 5 GHz reverse TCP traffic, however, available memory again
declined progressively, reaching about 10 MiB before the test was stopped. It
recovered to about 21 MiB after one minute and 39 MiB after five minutes with
traffic stopped. `Slab`, `SUnreclaim`, and `Shmem` remained nearly unchanged,
indicating delayed release of traffic-related allocations rather than a slab
leak. No OOM or firmware crash occurred because the test was stopped early.

Candidate B's reduced rings showed no datapath exhaustion: RXDMA overflow, TCL
ring-full failures, miscellaneous transmit failures, HAL REO errors, and ring
backpressure were all zero. One FCS error and 43 `Frame OOR` events are not ring
exhaustion indicators. Candidate B is nevertheless rejected because sustained
traffic accumulates memory faster than it drains and leaves insufficient safety
margin on this no-swap system. It must not be used in a persistent image.

Candidate C combines three changes rather than testing them independently:

```text
TX completion:       8192
RXDMA buffer:        1024
RX buffer byte size: 2048
RX error destination:1024
Monitor status:       512
Monitor buffer:       128
Monitor destination:  128
Monitor descriptor:  4096
Firmware memory mode:   2 on both radios
Allocator:              private page-frag cache per RXDMA ring
```

These are the OEM-like values that map defensibly to upstream ath11k. The OEM
`dp_rxdma_refill_ring=4096` value is not copied because upstream
`DP_RXDMA_REFILL_RING_SIZE` is a buffer-size contract in bytes, not the same
ring count. Candidate C retains the existing 48 MiB WCSS reservation and fixed
BDF/M3 addresses. It is a RAM-only sufficiency experiment: success would show
that the combined profile works, not which individual change is necessary.

Candidate C passed repeated cold-booted RAM-only switch-root testing. The test
root used the installed SquashFS read-only with a tmpfs upper layer; persistent
`rootfs_data`, NAND, UBI volumes, and the U-Boot environment were not modified.
Both radios initialized with firmware memory mode 2. The validated traffic
results were:

```text
5 GHz reverse: 30 min, 63.0 GiB, 301 Mbit/s
5 GHz forward: 30 min, 69.8 GiB, 333 Mbit/s
5 GHz reverse: 60 min, 128 GiB, 304 Mbit/s
2.4 GHz reverse: 10 min, completed without guard or driver failure
```

During the sustained 5 GHz tests, `MemAvailable` reached a bounded traffic
plateau of about 48-50 MiB and recovered to about 64 MiB after traffic. The
60-minute run showed the same plateau at the 10, 20, 30, and 45 minute
checkpoints, followed by recovery at test completion. There was no OOM, killed
process, ath11k or remoteproc crash, kernel bug, IRQ imbalance, page-allocation
failure, or guard trip. The 2.4 GHz AHB-radio test reached about 48 MiB and also
recovered to about 65 MiB.

The original guard action for losing more than 8 MiB in 60 seconds was removed
after it repeatedly mistook normal initial datapath working-set population for
unbounded growth. The guard still shuts Wi-Fi down below 24 MiB
`MemAvailable` or after a fatal kernel, ath11k, or remoteproc message.
Candidate C is now validated as a combined RAM-only mitigation profile, but the
results do not identify which of its three changes are individually necessary.
The persistent image then passed exact image-hash and `sysupgrade -T` checks,
preserved OEM `wifi_fw` and `bt_fw` byte-for-byte, and booted with the expected
five-volume UBI layout. A five-minute 5 GHz reverse test transferred 10.6 GiB
at 305 Mbit/s, reached the same bounded 49-51 MiB traffic plateau, and recovered
to about 65 MiB. Normal reboot and cold power-cycle both restored mode 2, both
APs, Gigabit Ethernet, the persistent guard, and clean kernel logs.

A later persistent build corrected the board clocks and removed the guard after
the bounded memory behavior was established. That image also passed LuCI
sysupgrade, reboot, radio, Ethernet, UBI, and kernel-log checks. Idle
`MemAvailable` remained about 59-62 MiB. Candidate C is therefore the validated
deployed profile, although it remains an opt-in build and the results still do
not identify which of its three changes are individually necessary.

With Candidate C installed:

- Avoid memory-heavy services.
- Stop and unload both radios before placing a large sysupgrade image in `/tmp`.
- Do not treat zram as a fix for DMA or firmware memory.

## Watchdog and CPU Frequency

The board DTS now supplies the OEM-confirmed 32 kHz sleep clock and completes
OpenWrt's 96 MHz-to-24 MHz fixed-factor board XO definition. Runtime validation
confirmed:

```text
ref-96mhz-clk:       96000000 Hz
xo-board-clk:        24000000 Hz
sleep-clk:              32000 Hz
apcs_alias0_core_clk: 1008000000 Hz
watchdog: qcom_wdt, active, 30-second timeout
cpufreq:  cpufreq-dt, fixed 1008000 kHz policy
```

The former fixed-factor, watchdog input-clock, deferred-probe, and cpufreq
registration failures are absent. The bootloader initially leaves the CPU near
800 MHz; cpufreq reports that unlisted initial rate and immediately changes it
to the sole supported 1.008 GHz operating point. This message is informational.

The deployed router sets the `performance` governor from `/etc/rc.local`. Since
the policy exposes only 1.008 GHz, this does not change the actual clock rate
relative to `schedutil`; it only makes the fixed-rate governor explicit.

## ath11k Crash-Dump Requests

Both radios operate normally, but firmware requests optional crash-dump memory
that is not fully described by the current reserved-memory layout:

```text
ath11k c000000.wifi: qmi fail to get qcom,m3-dump-addr, ignore m3 dump mem req
ath11k b00a040.wifi: qmi ignore invalid mem req type 10
```

Do not assign or enable these dump regions without reconciling the OEM QCN6122
M3/ETR addresses and proving that they cannot overlap live WCSS allocations.

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
